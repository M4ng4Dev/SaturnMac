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
static uint16_t g_input_buttons = 0;

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
    for (GCController *controller in [GCController controllers]) {
        GCExtendedGamepad *pad = controller.extendedGamepad;
        if (pad) {
            if (pad.dpad.up.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP);
            else g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_UP);

            if (pad.dpad.down.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN);
            else g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_DOWN);

            if (pad.dpad.left.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT);
            else g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_LEFT);

            if (pad.dpad.right.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);
            else g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_RIGHT);

            if (pad.buttonA.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_B);
            if (pad.buttonB.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_A);
            if (pad.buttonX.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_Y);
            if (pad.buttonY.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_X);
            if (pad.buttonMenu.pressed) g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_START);
        }
    }
}

static int16_t core_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port == 0 && device == RETRO_DEVICE_JOYPAD) {
        return (g_input_buttons & (1 << id)) ? 1 : 0;
    }
    return 0;
}

// Display View using macOS CoreAnimation Layer
@interface SaturnView : NSView
- (void)updateFrameImage;
@end

@implementation SaturnView

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

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 126: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP); break;
        case 125: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;
        case 123: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;
        case 124: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break;
        case 6:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_B); break;     // Z (Saturn A)
        case 7:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_A); break;     // X (Saturn B)
        case 8:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R); break;     // C (Saturn C)
        case 0:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_Y); break;     // A (Saturn X)
        case 1:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_X); break;     // S (Saturn Y)
        case 2:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L); break;     // D (Saturn Z)
        case 36:  g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_START); break; // Enter
        default: break;
    }
}

- (void)keyUp:(NSEvent *)event {
    switch (event.keyCode) {
        case 126: g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_UP); break;
        case 125: g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;
        case 123: g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;
        case 124: g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break;
        case 6:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_B); break;
        case 7:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_A); break;
        case 8:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R); break;
        case 0:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_Y); break;
        case 1:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_X); break;
        case 2:   g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L); break;
        case 36:  g_input_buttons &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START); break;
        default: break;
    }
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

        NSLog(@"[SaturnMac] Loading game with retro_load_game(): %@", romPath);
        struct retro_game_info ginfo = {0};
        ginfo.path = [romPath UTF8String];
        if (!p_retro_load_game(&ginfo)) {
            NSLog(@"[SaturnMac] Failed to load ROM: %@", romPath);
            return 1;
        }
        NSLog(@"[SaturnMac] Game loaded successfully!");

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

        // 60 FPS Render Timer
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                                 target:controller
                                               selector:@selector(tick)
                                               userInfo:nil
                                                repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        controller.renderTimer = timer;

        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        [NSApp run];

        [timer invalidate];
        p_retro_deinit();
        dlclose(g_core_handle);
    }
    return 0;
}
