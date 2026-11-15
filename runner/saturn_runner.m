//
//  saturn_runner.m
//  SaturnMac - Standalone Native Apple Silicon / macOS Player
//
//  Compiles with:
//  clang -O3 -fobjc-arc -framework Cocoa -framework Metal -framework MetalKit -framework AudioToolbox -framework GameController saturn_runner.m -o saturn_runner
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <GameController/GameController.h>
#import <dlfcn.h>
#include "libretro.h"

// Audio buffer settings
#define AUDIO_FREQ 44100
#define AUDIO_CHANNELS 2
#define AUDIO_BUF_COUNT 3
#define AUDIO_BUF_SIZE 4096

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

// Audio Queue
static AudioQueueRef g_audio_queue = NULL;
static AudioQueueBufferRef g_audio_buffers[AUDIO_BUF_COUNT];
static int16_t g_audio_staging[AUDIO_BUF_SIZE * 4];
static size_t g_audio_staging_pos = 0;

// Input state for RetroPad (Player 1)
static uint16_t g_input_buttons = 0;

@interface SaturnMetalView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLTexture> screenTexture;
@end

@implementation SaturnMetalView

- (instancetype)initWithFrame:(NSRect)frameRect device:(id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    if (self) {
        self.delegate = self;
        self.preferredFramesPerSecond = 60;
        self.enableSetNeedsDisplay = NO;
        self.paused = NO;
        self.commandQueue = [device newCommandQueue];
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    }
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    if (!g_core_handle || !p_retro_run) return;

    // Run one emulator frame
    p_retro_run();

    if (!g_fb_data || g_fb_width == 0 || g_fb_height == 0) return;

    id<MTLDevice> device = self.device;
    if (!self.screenTexture || self.screenTexture.width != g_fb_width || self.screenTexture.height != g_fb_height) {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                        width:g_fb_width
                                                                                       height:g_fb_height
                                                                                    mipmapped:NO];
        self.screenTexture = [device newTextureWithDescriptor:desc];
    }

    [self.screenTexture replaceRegion:MTLRegionMake2D(0, 0, g_fb_width, g_fb_height)
                          mipmapLevel:0
                            withBytes:g_fb_data
                          bytesPerRow:g_fb_width * 4];

    id<CAMetalDrawable> drawable = self.currentDrawable;
    if (!drawable) return;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *pass = self.currentRenderPassDescriptor;
    if (pass) {
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
        [encoder endEncoding];
    }
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end

// Libretro Callbacks
static bool core_environment(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            const enum retro_pixel_format *fmt = (const enum retro_pixel_format *)data;
            g_pixel_format = *fmt;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: {
            const char **dir = (const char **)data;
            NSString *home = NSHomeDirectory();
            NSString *saturnDir = [home stringByAppendingPathComponent:@"Library/Application Support/SaturnMac"];
            [[NSFileManager defaultManager] createDirectoryAtPath:saturnDir withIntermediateDirectories:YES attributes:nil error:nil];
            *dir = [saturnDir UTF8String];
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: {
            bool *b = (bool *)data;
            *b = true;
            return true;
        }
        default:
            return false;
    }
}

static void core_video_refresh(const void *data, unsigned width, unsigned height, size_t pitch) {
    if (!data) return;

    g_fb_width = width;
    g_fb_height = height;

    size_t needed = width * height * sizeof(uint32_t);
    if (g_fb_data_size < needed) {
        g_fb_data = realloc(g_fb_data, needed);
        g_fb_data_size = needed;
    }

    if (g_pixel_format == RETRO_PIXEL_FORMAT_XRGB8888) {
        const uint32_t *src = (const uint32_t *)data;
        size_t src_stride = pitch / 4;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint32_t c = src[y * src_stride + x];
                uint8_t r = (c >> 16) & 0xFF;
                uint8_t g = (c >> 8) & 0xFF;
                uint8_t b = c & 0xFF;
                // BGRA format for Metal
                g_fb_data[y * width + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            }
        }
    } else if (g_pixel_format == RETRO_PIXEL_FORMAT_RGB565) {
        const uint16_t *src = (const uint16_t *)data;
        size_t src_stride = pitch / 2;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint16_t c = src[y * src_stride + x];
                uint8_t r = ((c >> 11) & 0x1F) * 255 / 31;
                uint8_t g = ((c >> 5) & 0x3F) * 255 / 63;
                uint8_t b = (c & 0x1F) * 255 / 31;
                g_fb_data[y * width + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            }
        }
    } else { // 0RGB1555
        const uint16_t *src = (const uint16_t *)data;
        size_t src_stride = pitch / 2;
        for (unsigned y = 0; y < height; ++y) {
            for (unsigned x = 0; x < width; ++x) {
                uint16_t c = src[y * src_stride + x];
                uint8_t r = ((c >> 10) & 0x1F) * 255 / 31;
                uint8_t g = ((c >> 5) & 0x1F) * 255 / 31;
                uint8_t b = (c & 0x1F) * 255 / 31;
                g_fb_data[y * width + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            }
        }
    }
}

static void core_audio_sample(int16_t left, int16_t right) {
    if (g_audio_staging_pos + 2 < sizeof(g_audio_staging) / sizeof(int16_t)) {
        g_audio_staging[g_audio_staging_pos++] = left;
        g_audio_staging[g_audio_staging_pos++] = right;
    }
}

static size_t core_audio_sample_batch(const int16_t *data, size_t frames) {
    size_t samples = frames * 2;
    size_t available = (sizeof(g_audio_staging) / sizeof(int16_t)) - g_audio_staging_pos;
    size_t to_copy = (samples < available) ? samples : available;
    memcpy(&g_audio_staging[g_audio_staging_pos], data, to_copy * sizeof(int16_t));
    g_audio_staging_pos += to_copy;
    return frames;
}

static void core_input_poll(void) {
    // Poll Apple GameController if connected
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

static void audio_callback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    size_t to_copy = (g_audio_staging_pos * sizeof(int16_t) < buffer->mAudioDataBytesCapacity) 
                     ? (g_audio_staging_pos * sizeof(int16_t)) 
                     : buffer->mAudioDataBytesCapacity;

    if (to_copy > 0) {
        memcpy(buffer->mAudioData, g_audio_staging, to_copy);
        buffer->mAudioDataByteSize = (UInt32)to_copy;
        g_audio_staging_pos = 0;
    } else {
        memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
    }
    AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

static void init_audio(void) {
    AudioStreamBasicDescription fmt = {0};
    fmt.mSampleRate = AUDIO_FREQ;
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    fmt.mBytesPerPacket = 4;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerFrame = 4;
    fmt.mChannelsPerFrame = AUDIO_CHANNELS;
    fmt.mBitsPerChannel = 16;

    AudioQueueNewOutput(&fmt, audio_callback, NULL, NULL, NULL, 0, &g_audio_queue);
    for (int i = 0; i < AUDIO_BUF_COUNT; ++i) {
        AudioQueueAllocateBuffer(g_audio_queue, AUDIO_BUF_SIZE, &g_audio_buffers[i]);
        g_audio_buffers[i]->mAudioDataByteSize = AUDIO_BUF_SIZE;
        memset(g_audio_buffers[i]->mAudioData, 0, AUDIO_BUF_SIZE);
        AudioQueueEnqueueBuffer(g_audio_queue, g_audio_buffers[i], 0, NULL);
    }
    AudioQueueStart(g_audio_queue, NULL);
}

// Window Controller
@interface SaturnWindowController : NSWindowController <NSWindowDelegate>
@end

@implementation SaturnWindowController
- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 126: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_UP); break;    // Up arrow
        case 125: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_DOWN); break;  // Down arrow
        case 123: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_LEFT); break;  // Left arrow
        case 124: g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT); break; // Right arrow
        case 6:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_B); break;     // Z (Saturn A)
        case 7:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_A); break;     // X (Saturn B)
        case 8:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_R); break;     // C (Saturn C)
        case 0:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_Y); break;     // A (Saturn X)
        case 1:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_X); break;     // S (Saturn Y)
        case 2:   g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_L); break;     // D (Saturn Z)
        case 36:  g_input_buttons |= (1 << RETRO_DEVICE_ID_JOYPAD_START); break; // Enter (Start)
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
        }

        if (!romPath) {
            NSLog(@"Usage: saturn_runner --rom <path_to_cue_or_iso> [--core <path_to_dylib>] [--title <game_title>]");
            return 1;
        }

        // Search for core if not provided
        if (!corePath) {
            NSString *appDir = [[NSBundle mainBundle] resourcePath];
            NSArray *candidates = @[
                [appDir stringByAppendingPathComponent:@"cores/yabasanshiro_libretro.dylib"],
                [appDir stringByAppendingPathComponent:@"cores/yabause_libretro.dylib"],
                [appDir stringByAppendingPathComponent:@"cores/beetle_saturn_libretro.dylib"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SaturnMac/cores/yabasanshiro_libretro.dylib"],
                [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SaturnMac/cores/yabause_libretro.dylib"]
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
            alert.informativeText = @"Please ensure a Saturn core (yabasanshiro_libretro.dylib) is placed inside SaturnMac.";
            [alert runModal];
            return 1;
        }

        // Load the core
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

        p_retro_set_environment(core_environment);
        p_retro_set_video_refresh(core_video_refresh);
        p_retro_set_audio_sample(core_audio_sample);
        p_retro_set_audio_sample_batch(core_audio_sample_batch);
        p_retro_set_input_poll(core_input_poll);
        p_retro_set_input_state(core_input_state);

        p_retro_init();

        struct retro_game_info ginfo = {0};
        ginfo.path = [romPath UTF8String];
        if (!p_retro_load_game(&ginfo)) {
            NSLog(@"[SaturnMac] Failed to load ROM: %@", romPath);
            return 1;
        }

        init_audio();

        // Create Cocoa Application & Window
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(100, 100, 960, 720); // 4:3 default window
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

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        SaturnMetalView *metalView = [[SaturnMetalView alloc] initWithFrame:frame device:device];
        window.contentView = metalView;

        SaturnWindowController *controller = [[SaturnWindowController alloc] initWithWindow:window];
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        [NSApp run];

        p_retro_deinit();
        dlclose(g_core_handle);
    }
    return 0;
}
