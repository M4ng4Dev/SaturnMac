//
//  saturn_runner.m
//  SaturnMac - Standalone Native Apple Silicon / macOS Player
//
//  Compiles with:
//  clang -O3 -fobjc-arc -framework Cocoa -framework QuartzCore -framework AudioToolbox -framework GameController saturn_runner.m -o saturn_runner
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <GameController/GameController.h>
#import <pthread.h>
#import <dlfcn.h>
#include "libretro.h"

#define AUDIO_FREQ 44100
#define AUDIO_CHANNELS 2
#define AUDIO_BUF_COUNT 3
#define AUDIO_BUF_SIZE 4096
#define RING_BUFFER_SIZE (44100 * 4) // 2 seconds of stereo audio

static void *g_core_handle = NULL;
static void (*p_retro_init)(void) = NULL;
static void (*p_retro_deinit)(void) = NULL;
static bool (*p_retro_load_game)(const struct retro_game_info *) = NULL;
static void (*p_retro_run)(void) = NULL;
static void (*p_retro_get_system_av_info)(struct retro_system_av_info *) = NULL;
static void (*p_retro_set_video_refresh)(retro_video_refresh_t) = NULL;
static void (*p_retro_set_audio_sample)(retro_audio_sample_t) = NULL;
static void (*p_retro_set_audio_sample_batch)(retro_audio_sample_batch_t) = NULL;
static void (*p_retro_set_input_poll)(retro_input_poll_t) = NULL;
static void (*p_retro_set_input_state)(retro_input_state_t) = NULL;
static void (*p_retro_set_environment)(retro_environment_t) = NULL;
static void (*p_retro_set_controller_port_device)(unsigned port, unsigned device) = NULL;

static uint32_t g_fb_width = 320;
static uint32_t g_fb_height = 240;
static uint32_t *g_fb_data = NULL;
static size_t g_fb_data_size = 0;
static enum retro_pixel_format g_pixel_format = RETRO_PIXEL_FORMAT_RGB565;

// Thread-safe Audio Ring Buffer
static AudioQueueRef g_audio_queue = NULL;
static AudioQueueBufferRef g_audio_buffers[AUDIO_BUF_COUNT];
static int16_t g_audio_ring[RING_BUFFER_SIZE];
static size_t g_audio_write_pos = 0;
static size_t g_audio_read_pos = 0;
static pthread_mutex_t g_audio_mutex = PTHREAD_MUTEX_INITIALIZER;

// Input state for RetroPad (Player 1)
static uint16_t g_keyboard_buttons = 0;
static uint16_t g_gamepad_buttons = 0;

// Graphic Enhancement Options
static bool g_opt_dedither = true;
static int g_opt_resolution_scale = 4;
static double g_audio_sample_rate = 44100.0;
static char g_saturn_dir[1024] = {0};

static void core_log_cb(enum retro_log_level level, const char *fmt, ...) {
    va_list va;
    va_start(va, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, va);
    va_end(va);
    NSLog(@"[SaturnCore] %s", buf);
}

// Libretro Callbacks
static bool core_environment(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            const enum retro_pixel_format *fmt = (const enum retro_pixel_format *)data;
            g_pixel_format = *fmt;
            NSLog(@"[SaturnMac] Core set pixel format: %u", (unsigned)*fmt);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: {
            const char **dir = (const char **)data;
            if (g_saturn_dir[0] == '\0') {
                NSString *home = NSHomeDirectory();
                NSString *saturnDir = [home stringByAppendingPathComponent:@"Library/Application Support/SaturnMac"];
                [[NSFileManager defaultManager] createDirectoryAtPath:saturnDir withIntermediateDirectories:YES attributes:nil error:nil];
                strncpy(g_saturn_dir, [saturnDir UTF8String], sizeof(g_saturn_dir) - 1);
            }
            *dir = g_saturn_dir;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            struct retro_log_callback *cb = (struct retro_log_callback *)data;
            if (cb) {
                cb->log = core_log_cb;
                return true;
            }
            return false;
        }
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: {
            bool *b = (bool *)data;
            if (b) *b = true;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: {
            bool *b = (bool *)data;
            if (b) *b = true;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO: {
            return true;
        }
        case RETRO_ENVIRONMENT_SET_MESSAGE: {
            const struct retro_message *msg = (const struct retro_message *)data;
            if (msg && msg->msg) {
                NSLog(@"[SaturnCore Msg] %s", msg->msg);
            }
            return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            // Software rendering preferred for native compositor
            return false;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *var = (struct retro_variable *)data;
            if (!var || !var->key) return false;

            if (strcmp(var->key, "yabause_force_hle_bios") == 0) {
                var->value = "enabled";
                NSLog(@"[SaturnMac] Enabled yabause_force_hle_bios");
                return true;
            } else if (strcmp(var->key, "yabause_addon_cartridge") == 0) {
                var->value = "4M_ram";
                return true;
            } else if (strcmp(var->key, "yabause_numthreads") == 0) {
                var->value = "4";
                return true;
            } else if (strcmp(var->key, "yabasanshiro_resolution") == 0 || strcmp(var->key, "yabause_resolution") == 0) {
                var->value = (g_opt_resolution_scale >= 4) ? "4x" : ((g_opt_resolution_scale >= 2) ? "2x" : "1x");
                return true;
            } else if (strcmp(var->key, "beetle_saturn_mupen_dithering") == 0) {
                var->value = "disabled";
                return true;
            } else if (strcmp(var->key, "beetle_saturn_cdimagecache") == 0) {
                var->value = "enabled";
                return true;
            }
            return false;
        }
        default:
            return false;
    }
}

// Intelligent De-Dither filter
static void apply_dedither_filter(uint32_t *pixels, unsigned width, unsigned height) {
    if (!g_opt_dedither || width < 2 || height < 2) return;

    for (unsigned y = 0; y < height; ++y) {
        for (unsigned x = 0; x < width - 1; ++x) {
            uint32_t p0 = pixels[y * width + x];
            uint32_t p1 = pixels[y * width + x + 1];

            uint8_t r0 = p0 & 0xFF, g0 = (p0 >> 8) & 0xFF, b0 = (p0 >> 16) & 0xFF;
            uint8_t r1 = p1 & 0xFF, g1 = (p1 >> 8) & 0xFF, b1 = (p1 >> 16) & 0xFF;

            int diff = abs((int)r0 - (int)r1) + abs((int)g0 - (int)g1) + abs((int)b0 - (int)b1);
            if (diff > 60 && diff < 380) {
                uint8_t r_avg = (r0 + r1) / 2;
                uint8_t g_avg = (g0 + g1) / 2;
                uint8_t b_avg = (b0 + b1) / 2;
                pixels[y * width + x] = (0xFF << 24) | (b_avg << 16) | (g_avg << 8) | r_avg;
            }
        }
    }
}

static void core_video_refresh(const void *data, unsigned width, unsigned height, size_t pitch) {
    if (!data) return;

    static uint64_t s_frame_count = 0;
    s_frame_count++;
    if (s_frame_count == 1 || s_frame_count % 300 == 0) {
        NSLog(@"[SaturnMac] Video frame #%llu received (size: %ux%u, format: %u)", s_frame_count, width, height, (unsigned)g_pixel_format);
    }

    g_fb_width = width;
    g_fb_height = height;

    size_t needed = width * height * 4;
    if (g_fb_data_size < needed) {
        g_fb_data = realloc(g_fb_data, needed);
        g_fb_data_size = needed;
    }

    uint8_t *dst = (uint8_t *)g_fb_data;

    if (g_pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
        const uint32_t *src = (const uint32_t *)data;
        size_t src_stride = pitch / 4;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint32_t c = src[y * src_stride + x];
                size_t idx = (y * width + x) * 4;
                dst[idx + 0] = (c >> 16) & 0xFF; // R
                dst[idx + 1] = (c >> 8) & 0xFF;  // G
                dst[idx + 2] = c & 0xFF;         // B
                dst[idx + 3] = 255;              // A
            }
        }
    } else if (g_pixel_format == RETRO_PIXEL_FORMAT_RGB565) {
        const uint16_t *src = (const uint16_t *)data;
        size_t src_stride = pitch / 2;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint16_t c = src[y * src_stride + x];
                size_t idx = (y * width + x) * 4;
                dst[idx + 0] = ((c >> 11) & 0x1F) * 255 / 31; // R
                dst[idx + 1] = ((c >> 5) & 0x3F) * 255 / 63;  // G
                dst[idx + 2] = (c & 0x1F) * 255 / 31;         // B
                dst[idx + 3] = 255;                           // A
            }
        }
    } else { // 0RGB1555
        const uint16_t *src = (const uint16_t *)data;
        size_t src_stride = pitch / 2;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint16_t c = src[y * src_stride + x];
                size_t idx = (y * width + x) * 4;
                dst[idx + 0] = ((c >> 10) & 0x1F) * 255 / 31; // R
                dst[idx + 1] = ((c >> 5) & 0x1F) * 255 / 31;  // G
                dst[idx + 2] = (c & 0x1F) * 255 / 31;         // B
                dst[idx + 3] = 255;                           // A
            }
        }
    }
}

// Thread-safe Audio buffering
static size_t core_audio_sample_batch(const int16_t *data, size_t frames) {
    pthread_mutex_lock(&g_audio_mutex);
    size_t samples = frames * 2;
    for (size_t i = 0; i < samples; ++i) {
        g_audio_ring[g_audio_write_pos] = data[i];
        g_audio_write_pos = (g_audio_write_pos + 1) % RING_BUFFER_SIZE;
        if (g_audio_write_pos == g_audio_read_pos) {
            // Drop oldest sample if buffer overflows
            g_audio_read_pos = (g_audio_read_pos + 1) % RING_BUFFER_SIZE;
        }
    }
    pthread_mutex_unlock(&g_audio_mutex);
    return frames;
}

static void core_audio_sample(int16_t left, int16_t right) {
    int16_t frame[2] = {left, right};
    core_audio_sample_batch((const int16_t *)frame, 1);
}

static void audio_callback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    pthread_mutex_lock(&g_audio_mutex);
    size_t samples_requested = buffer->mAudioDataBytesCapacity / sizeof(int16_t);
    int16_t *out = (int16_t *)buffer->mAudioData;

    size_t available = 0;
    if (g_audio_write_pos >= g_audio_read_pos) {
        available = g_audio_write_pos - g_audio_read_pos;
    } else {
        available = RING_BUFFER_SIZE - (g_audio_read_pos - g_audio_write_pos);
    }

    size_t to_read = (samples_requested < available) ? samples_requested : available;
    for (size_t i = 0; i < to_read; ++i) {
        out[i] = g_audio_ring[g_audio_read_pos];
        g_audio_read_pos = (g_audio_read_pos + 1) % RING_BUFFER_SIZE;
    }

    // Fill underflow with silence
    if (to_read < samples_requested) {
        memset(&out[to_read], 0, (samples_requested - to_read) * sizeof(int16_t));
    }
    buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
    pthread_mutex_unlock(&g_audio_mutex);

    AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

static void init_audio(void) {
    AudioStreamBasicDescription fmt = {0};
    fmt.mSampleRate = (g_audio_sample_rate > 0) ? g_audio_sample_rate : AUDIO_FREQ;
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    fmt.mBytesPerPacket = 4;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerFrame = 4;
    fmt.mChannelsPerFrame = AUDIO_CHANNELS;
    fmt.mBitsPerChannel = 16;

    OSStatus status = AudioQueueNewOutput(&fmt, audio_callback, NULL, NULL, NULL, 0, &g_audio_queue);
    if (status != noErr) {
        NSLog(@"[SaturnMac] AudioQueueNewOutput failed: %d", (int)status);
        return;
    }

    for (int i = 0; i < AUDIO_BUF_COUNT; ++i) {
        AudioQueueAllocateBuffer(g_audio_queue, AUDIO_BUF_SIZE, &g_audio_buffers[i]);
        g_audio_buffers[i]->mAudioDataByteSize = AUDIO_BUF_SIZE;
        memset(g_audio_buffers[i]->mAudioData, 0, AUDIO_BUF_SIZE);
        AudioQueueEnqueueBuffer(g_audio_queue, g_audio_buffers[i], 0, NULL);
    }
    AudioQueueStart(g_audio_queue, NULL);
}

static void core_input_poll(void) {
    uint16_t pad_buttons = 0;
    for (GCController *controller in [GCController controllers]) {
        GCExtendedGamepad *pad = controller.extendedGamepad;
        if (pad) {
            // Directional controls: D-Pad and Left Analog Stick
            if (pad.dpad.up.isPressed || pad.leftThumbstick.up.value > 0.5f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP);
            if (pad.dpad.down.isPressed || pad.leftThumbstick.down.value > 0.5f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
            if (pad.dpad.left.isPressed || pad.leftThumbstick.left.value > 0.5f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
            if (pad.dpad.right.isPressed || pad.leftThumbstick.right.value > 0.5f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);

            // Saturn 6-button layout:
            // Bottom row: A (Saturn A), B (Saturn B), Right Shoulder (Saturn C)
            if (pad.buttonA.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_B);
            if (pad.buttonB.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_A);
            if (pad.rightShoulder.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R);

            // Top row: X (Saturn X), Y (Saturn Y), Left Shoulder (Saturn Z)
            if (pad.buttonX.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_Y);
            if (pad.buttonY.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_X);
            if (pad.leftShoulder.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L);

            // Saturn Analog Triggers (L / R)
            if (pad.leftTrigger.value > 0.3f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L2);
            if (pad.rightTrigger.value > 0.3f) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R2);

            // Start & Select/Options
            if (pad.buttonMenu.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_START);
            if (pad.buttonOptions && pad.buttonOptions.isPressed) pad_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
        }
    }
    g_gamepad_buttons = pad_buttons;
}

static int16_t core_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port != 0) return 0;

    uint16_t combined = g_keyboard_buttons | g_gamepad_buttons;
    unsigned base_device = device & 0xFF;

    // Both Standard 6-button Joypad and 3D Analog Controller digital states
    if (base_device == RETRO_DEVICE_JOYPAD || base_device == RETRO_DEVICE_ANALOG) {
        if (id == RETRO_DEVICE_ID_JOYPAD_MASK) {
            return (int16_t)combined;
        }
        if (id < 16) {
            return (combined & (1 << id)) ? 1 : 0;
        }
    }

    // Saturn 3D Pad Analog Stick support (e.g. Sonic R steering)
    if (base_device == RETRO_DEVICE_ANALOG && index == RETRO_DEVICE_INDEX_ANALOG_LEFT) {
        if (id == RETRO_DEVICE_ID_ANALOG_X) {
            if (combined & (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT)) return 0x7FFF;
            if (combined & (1 << RETRO_DEVICE_ID_JOYPAD_LEFT))  return -0x7FFF;
        } else if (id == RETRO_DEVICE_ID_ANALOG_Y) {
            if (combined & (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)) return 0x7FFF;
            if (combined & (1 << RETRO_DEVICE_ID_JOYPAD_UP))    return -0x7FFF;
        }
    }

    return 0;
}

// Display View using macOS CoreAnimation Layer
@interface SaturnView : NSView
- (void)updateFrameImage;
@end

@implementation SaturnView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [[NSColor blackColor] CGColor];
        self.layer.contentsGravity = kCAGravityResizeAspect;
        self.layer.magnificationFilter = kCAFilterTrilinear;
    }
    return self;
}

- (void)updateFrameImage {
    if (!g_fb_data || g_fb_width == 0 || g_fb_height == 0) return;

    static CGColorSpaceRef s_colorSpace = NULL;
    if (!s_colorSpace) s_colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef ctx = CGBitmapContextCreate(
        g_fb_data,
        g_fb_width,
        g_fb_height,
        8,
        g_fb_width * 4,
        s_colorSpace,
        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big
    );

    if (ctx) {
        CGImageRef image = CGBitmapContextCreateImage(ctx);
        if (image) {
            self.layer.contents = (__bridge id)image;
            CGImageRelease(image);
        }
        CGContextRelease(ctx);
    }
}

@end

// Window Controller
@interface SaturnWindowController : NSWindowController <NSWindowDelegate, NSApplicationDelegate>
@property (nonatomic, strong) SaturnView *saturnView;
@property (nonatomic, strong) NSTimer *renderTimer;
- (void)tick;
@end

@implementation SaturnWindowController

- (void)tick {
    if (!g_core_handle || !p_retro_run) return;
    p_retro_run();
    [self.saturnView updateFrameImage];
}

- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"[SaturnMac] Window closed by user, terminating app...");
    [NSApp terminate:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"[SaturnMac] Application will terminate, releasing resources...");
    if (self.renderTimer) {
        [self.renderTimer invalidate];
        self.renderTimer = nil;
    }
    if (g_audio_queue) {
        AudioQueueStop(g_audio_queue, YES);
        AudioQueueDispose(g_audio_queue, YES);
        g_audio_queue = NULL;
    }
    if (p_retro_deinit) {
        p_retro_deinit();
        p_retro_deinit = NULL;
    }
    if (g_core_handle) {
        dlclose(g_core_handle);
        g_core_handle = NULL;
    }
}

- (void)handleKeyDown:(NSEvent *)event {
    NSLog(@"[SaturnMac Input] KeyDown: code=%u", (unsigned)event.keyCode);
    switch (event.keyCode) {
        // Directional Arrows
        case 126: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP); break;
        case 125: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;
        case 123: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;
        case 124: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break;

        // Alternative D-Pad (WASD)
        case 13:  g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP); break;    // W
        case 1:   g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;  // S
        case 0:   g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;  // A
        case 2:   g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break; // D

        // Saturn Bottom Row (A, B, C)
        // J, K, L or Z, X, C
        case 38: case 6: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_B); break; // J or Z -> Saturn A
        case 40: case 7: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_A); break; // K or X -> Saturn B
        case 37: case 8: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R); break; // L or C -> Saturn C

        // Saturn Top Row (X, Y, Z)
        // U, I, O
        case 32: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_Y); break; // U -> Saturn X
        case 34: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_X); break; // I -> Saturn Y
        case 31: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L); break; // O -> Saturn Z

        // Triggers (L / R)
        case 12: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L2); break; // Q -> Saturn L
        case 14: g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R2); break; // E -> Saturn R

        // Start & Select
        // Enter (36), Space (49), NumPad Enter (76), V (9), 1 (18)
        case 36: case 49: case 76: case 9: case 18:
            g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_START);
            break;
        case 48: case 53: // Tab or Esc
            g_keyboard_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
            break;
        default: break;
    }
}

- (void)handleKeyUp:(NSEvent *)event {
    switch (event.keyCode) {
        case 126: case 13: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_UP); break;
        case 125: case 1:  g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;
        case 123: case 0:  g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;
        case 124: case 2:  g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break;

        case 38: case 6: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_B); break;
        case 40: case 7: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_A); break;
        case 37: case 8: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R); break;

        case 32: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_Y); break;
        case 34: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_X); break;
        case 31: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L); break;

        case 12: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L2); break;
        case 14: g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R2); break;

        case 36: case 49: case 76: case 9: case 18:
            g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
            break;
        case 48: case 53:
            g_keyboard_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
            break;
        default: break;
    }
}

- (void)keyDown:(NSEvent *)event {
    [self handleKeyDown:event];
}

- (void)keyUp:(NSEvent *)event {
    [self handleKeyUp:event];
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *romPath = nil;
        NSString *corePath = nil;
        NSString *gameTitle = @"SaturnMac Game";

        for (int i = 1; i < argc; ++i) {
            if (strcmp(argv[i], "--rom") == 0 && i + 1 < argc) romPath = [NSString stringWithUTF8String:argv[++i]];
            if (strcmp(argv[i], "--core") == 0 && i + 1 < argc) corePath = [NSString stringWithUTF8String:argv[++i]];
            if (strcmp(argv[i], "--title") == 0 && i + 1 < argc) gameTitle = [NSString stringWithUTF8String:argv[++i]];
            if (strcmp(argv[i], "--resolution") == 0 && i + 1 < argc) g_opt_resolution_scale = atoi(argv[++i]);
            if (strcmp(argv[i], "--no-dedither") == 0) g_opt_dedither = false;
        }

        if (!romPath) {
            NSLog(@"Usage: saturn_runner --rom <path_to_cue_or_iso> [--core <path_to_dylib>] [--title <game_title>]");
            return 1;
        }

        if (!corePath) {
            NSString *appDir = [[NSBundle mainBundle] resourcePath];
            NSArray *candidates = @[
                [appDir stringByAppendingPathComponent:@"cores/yabause_libretro.dylib"],
                [appDir stringByAppendingPathComponent:@"cores/yabasanshiro_libretro.dylib"],
                [appDir stringByAppendingPathComponent:@"cores/beetle_saturn_libretro.dylib"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SaturnMac/cores/yabause_libretro.dylib"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SaturnMac/cores/yabasanshiro_libretro.dylib"]
            ];
            for (NSString *cand in candidates) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:cand]) {
                    corePath = cand;
                    break;
                }
            }
        }

        if (!corePath || ![[NSFileManager defaultManager] fileExistsAtPath:corePath]) {
            NSLog(@"[SaturnMac] No Saturn libretro core found at: %@", corePath);
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Saturn Core Missing";
            alert.informativeText = @"Please ensure a Saturn core (yabause_libretro.dylib) is placed inside SaturnMac.";
            [alert runModal];
            return 1;
        }

        NSLog(@"[SaturnMac] Loading core: %@", corePath);
        g_core_handle = dlopen([corePath UTF8String], RTLD_NOW);
        if (!g_core_handle) {
            NSLog(@"[SaturnMac] dlopen failed: %s", dlerror());
            return 1;
        }

        p_retro_init = dlsym(g_core_handle, "retro_init");
        p_retro_deinit = dlsym(g_core_handle, "retro_deinit");
        p_retro_load_game = dlsym(g_core_handle, "retro_load_game");
        p_retro_run = dlsym(g_core_handle, "retro_run");
        p_retro_get_system_av_info = dlsym(g_core_handle, "retro_get_system_av_info");
        p_retro_set_video_refresh = dlsym(g_core_handle, "retro_set_video_refresh");
        p_retro_set_audio_sample = dlsym(g_core_handle, "retro_set_audio_sample");
        p_retro_set_audio_sample_batch = dlsym(g_core_handle, "retro_set_audio_sample_batch");
        p_retro_set_input_poll = dlsym(g_core_handle, "retro_set_input_poll");
        p_retro_set_input_state = dlsym(g_core_handle, "retro_set_input_state");
        p_retro_set_environment = dlsym(g_core_handle, "retro_set_environment");
        p_retro_set_controller_port_device = dlsym(g_core_handle, "retro_set_controller_port_device");

        NSLog(@"[SaturnMac] Setting callbacks...");
        p_retro_set_environment(core_environment);
        p_retro_set_video_refresh(core_video_refresh);
        p_retro_set_audio_sample(core_audio_sample);
        p_retro_set_audio_sample_batch(core_audio_sample_batch);
        p_retro_set_input_poll(core_input_poll);
        p_retro_set_input_state(core_input_state);

        // Auto-detect and import BIOS from OpenEmu if present
        NSString *home = NSHomeDirectory();
        NSString *openEmuBios = [home stringByAppendingPathComponent:@"Library/Application Support/OpenEmu/BIOS"];
        NSString *saturnDir = [home stringByAppendingPathComponent:@"Library/Application Support/SaturnMac"];
        [[NSFileManager defaultManager] createDirectoryAtPath:saturnDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray *biosNames = @[@"sega_101.bin", @"mpr-17933.bin", @"saturn_bios.bin", @"Sega Saturn (USA).bin", @"Sega Saturn (Japan).bin", @"Sega Saturn (Europe).bin"];
        for (NSString *name in biosNames) {
            NSString *src = [openEmuBios stringByAppendingPathComponent:name];
            NSString *dst = [saturnDir stringByAppendingPathComponent:name];
            if ([[NSFileManager defaultManager] fileExistsAtPath:src] && ![[NSFileManager defaultManager] fileExistsAtPath:dst]) {
                [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil];
                NSLog(@"[SaturnMac] Found and copied BIOS from OpenEmu: %@", name);
            }
        }

        NSLog(@"[SaturnMac] Calling retro_init()...");
        p_retro_init();

        if (p_retro_set_controller_port_device) {
            p_retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
            p_retro_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);
        }

        NSLog(@"[SaturnMac] Loading game with retro_load_game(): %@", romPath);
        struct retro_game_info ginfo = {0};
        ginfo.path = [romPath UTF8String];
        if (!p_retro_load_game(&ginfo)) {
            NSLog(@"[SaturnMac] Failed to load ROM: %@", romPath);
            return 1;
        }
        NSLog(@"[SaturnMac] Game loaded successfully!");

        if (p_retro_set_controller_port_device) {
            p_retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
            p_retro_set_controller_port_device(1, RETRO_DEVICE_JOYPAD);
            NSLog(@"[SaturnMac] Initialized Controller Port 0 & 1 -> RETRO_DEVICE_JOYPAD (Standard Pad connected)");
        }

        if (p_retro_get_system_av_info) {
            struct retro_system_av_info av_info = {0};
            p_retro_get_system_av_info(&av_info);
            if (av_info.timing.sample_rate > 0) {
                g_audio_sample_rate = av_info.timing.sample_rate;
                NSLog(@"[SaturnMac] Core reported audio sample rate: %.1f Hz", g_audio_sample_rate);
            }
        }

        init_audio();

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        // Set Dock Icon if available
        NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
        if (iconPath) {
            NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
            if (appIcon) {
                [NSApp setApplicationIconImage:appIcon];
            }
        }

        // Add standard macOS Menubar with Quit Cmd+Q
        NSMenu *menubar = [NSMenu new];
        NSMenuItem *appMenuItem = [NSMenuItem new];
        [menubar addItem:appMenuItem];
        [NSApp setMainMenu:menubar];

        NSMenu *appMenu = [NSMenu new];
        NSString *quitTitle = [NSString stringWithFormat:@"Quit %@", gameTitle];
        NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                              action:@selector(terminate:)
                                                       keyEquivalent:@"q"];
        [appMenu addItem:quitMenuItem];
        [appMenuItem setSubmenu:appMenu];

        NSRect frame = NSMakeRect(100, 100, 960, 720);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:(NSWindowStyleMaskTitled |
                                                                  NSWindowStyleMaskClosable |
                                                                  NSWindowStyleMaskMiniaturizable |
                                                                  NSWindowStyleMaskResizable)
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.title = gameTitle;
        window.aspectRatio = NSMakeSize(4, 3);
        [window center];

        SaturnView *saturnView = [[SaturnView alloc] initWithFrame:frame];
        window.contentView = saturnView;

        SaturnWindowController *controller = [[SaturnWindowController alloc] initWithWindow:window];
        controller.saturnView = saturnView;
        window.delegate = controller;
        [NSApp setDelegate:controller];

        // Global Event Monitor for Keyboard Controls
        [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp) handler:^NSEvent *(NSEvent *event) {
            if (event.type == NSEventTypeKeyDown) {
                [controller handleKeyDown:event];
            } else if (event.type == NSEventTypeKeyUp) {
                [controller handleKeyUp:event];
            }
            return event;
        }];

        // Auto-configure connected Gamepads (Xbox, PlayStation, Switch Pro, MFi, 8BitDo)
        [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification *note) {
            GCController *c = note.object;
            NSLog(@"[SaturnMac] 🎮 Gamepad connectat i auto-configurat: %@ (%@)", c.vendorName ?: @"Generic Controller", c.productCategory);
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification
                                                         object:nil
                                                          queue:[NSOperationQueue mainQueue]
                                                     usingBlock:^(NSNotification *note) {
            GCController *c = note.object;
            NSLog(@"[SaturnMac] ⚠️ Gamepad desconnectat: %@", c.vendorName ?: @"Controller");
        }];
        [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];

        // 60 FPS Render Timer
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                                 target:controller
                                               selector:@selector(tick)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        controller.renderTimer = timer;

        [window makeKeyAndOrderFront:nil];
        [window makeFirstResponder:saturnView];
        [NSApp activateIgnoringOtherApps:YES];

        [NSApp run];

        [timer invalidate];
        p_retro_deinit();
        dlclose(g_core_handle);
    }
    return 0;
}
