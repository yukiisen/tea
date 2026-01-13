const std = @import("std");

const c = @import("deps/glad.zig");
const w = @import("deps/glfw3.zig");
const ma = @import("deps/miniaudio.zig");
const z = @import("zmath");

// resources
/// A window object is an extension over `FrameBuffer`.
/// It's a wrapper over GLFW's Window object
pub const Window = struct {
    const Self = @This();

    window: *w.GLFWwindow,
    mode: WindowMode = .Windowed,
    width: i32,
    height: i32,

    /// creates a GLFW window with the specified attributes.
    /// Additional windows will share the same resources with the first created window.
    /// TODO: add proper error handling
    /// TODO: allow the user to separate window contexts.
    pub fn init (width: i32, height: i32, title: []const u8) !Self {
        if (w.glfwInit() == w.GLFW_FALSE) return error.FuckWindowBroke;

        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MAJOR, 3);
        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MINOR, 3);
        w.glfwWindowHint(w.GLFW_OPENGL_PROFILE, w.GLFW_OPENGL_CORE_PROFILE);

        const context = w.glfwGetCurrentContext();
        const window = w.glfwCreateWindow(width, height, title.ptr, null, context).?; // assert for now
        
        _ = w.glfwSetFramebufferSizeCallback(window, winresize);

        if (context == null) w.glfwMakeContextCurrent(window); // first window is used as current context

        return .{
            .window = window,
            .width = width,
            .height = height
        };
    }

    /// used to init the window struct as a UserPointer.
    /// it's automatically called during setup, don't touch.
    /// this is separated from the init function because it needs a pointer to self (Window) which will likely change whenever you move the struct around.
    /// TODO: find a safer way to implement this.
    pub fn prepare (self: *Self) void {
        w.glfwSetWindowUserPointer(self.window, self);
    }

    /// window resize global callback.
    fn winresize(window: ?*w.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
        const s: ?*Self = @ptrCast(@alignCast(w.glfwGetWindowUserPointer(window))); 
        // don't crash if prepare was not called
        if (s) |self| { 
            self.*.width = width;
            self.*.height = height;
        }
        c.glViewport(0, 0, width, height);
    }
    
    pub fn deinit(self: *Self) void {
        w.glfwDestroyWindow(self.window);
        w.glfwTerminate();
    }

    pub fn close(self: Self) void {
        w.glfwSetWindowShouldClose(self.window, 1);
    }

    /// Changes the CurrentContext to this window.
    pub fn setMainContext (self: Self) void {
        w.glfwMakeContextCurrent(self.window);
    }

    /// Changes window mode between FullScreen/Windowed
    /// Asserts that a monitor exists
    pub fn setWindowMode (self: *Self, mode: WindowMode) void {
        if (self.mode == mode) return;
        const monitor = w.glfwGetPrimaryMonitor().?;
        const width, const height = self.getSize();

        switch (mode) {
            .Windowed => w.glfwSetWindowMonitor(self.window, null, 0, 0, width, height, 0), // separate window and monitor
            .Borderless => {
                const video_mode = w.glfwGetVideoMode(monitor).?; // use monitor dimentions
                w.glfwSetWindowMonitor(self.window, monitor, 0, 0, video_mode.*.width, video_mode.*.height, video_mode.*.refreshRate);
            },
            .FullScreen => w.glfwSetWindowMonitor(self.window, monitor, 0, 0, width, height, 60), // make monitor follow window
        }

        self.*.mode = mode;
    }

    pub fn setTitle(self: Self, title: []const u8) void {
        w.glfwSetWindowTitle(self.window, title.ptr);
    }

    pub fn getSize (self: Self) @Vector(2, i32) {
        var width: i32 = 0;
        var height: i32 = 0;
        w.glfwGetFramebufferSize(self.window, &width, &height);
        return .{ width, height };
    }

    /// updates the window content from the FrameBuffer and polls new events.
    pub fn swapBuffers(self: Self) void {
        w.glfwSwapBuffers(self.window);
        w.glfwPollEvents();
    }

    /// returns the close flag of the window
    pub fn shouldClose(self: Self) bool {
        return w.glfwWindowShouldClose(self.window) != 0;
    }
};

pub const WindowMode = enum {
    Windowed,
    Borderless,
    FullScreen
};

/// A renderer is responsible of managing framebuffers and rendering commands
/// All GPU communication except data loading should be abstracted here for easier encapsulation
/// TODO: those flags may be useless.. consider removing them..
pub const Renderer = struct {
    const Self = @This();

    // opengl feature flags
    depth_test: bool = true,
    blend: bool = true,
    cull_face: bool = true,
    gamma_correction: bool = true,
    stencil_test: bool = false,
    point_size: bool = false,
    multi_sample: bool = false,

    /// Init OpenGL and load all relevant functions
    /// This will burn if you create it before creating at least one window
    pub fn init() !Self {
        if (c.gladLoadGLLoader(@ptrCast(&w.glfwGetProcAddress)) == c.GL_FALSE) {
            return error.FuckGLBurned;
        }

        c.glEnable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_BLEND);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_FRAMEBUFFER_SRGB);

        return .{};
    }

    pub fn disableDepthTest (self: *Self) void {
        c.glDisable(c.GL_DEPTH_TEST);
        self.*.depth_test = false;
    }

    pub fn enableDepthTest (self: *Self) void {
        c.glEnable(c.GL_DEPTH_TEST);
        self.*.depth_test = true;
    }

    pub fn disableStencilTest (self: *Self) void {
        c.glDisable(c.GL_STENCIL_TEST);
        self.*.stencil_test = false;
    }

    pub fn enableStencilTest (self: *Self) void {
        c.glEnable(c.GL_STENCIL_TEST);
        self.*.stencil_test = true;
    }

    pub fn disableBlending (self: *Self) void {
        c.glDisable(c.GL_BLEND);
        self.*.blend = false;
    }

    pub fn enableBlending (self: *Self) void {
        c.glEnable(c.GL_BLEND);
        self.*.blend = true;
    }

    pub fn clearFrame(self: Self, color: [4]f32) void {
        c.glClearColor(color[0], color[1], color[2], color[3]);
        var mask = c.GL_COLOR_BUFFER_BIT;
        if (self.depth_test) mask |= c.GL_DEPTH_BUFFER_BIT;
        if (self.stencil_test) mask |= c.GL_STENCIL_BUFFER_BIT;
        c.glClear(@intCast(mask));
    }
};

/// A camera object, it can be used as 3D or 2D camera depending on the configuration
pub const Camera = struct {};

// deps
/// A rendering target, may output to a RenderBuffer or a Texture
pub const FrameBuffer = struct {};

/// This is used by FrameBuffers internally for depth/stencil buffers 
/// Not a part of the High-Level API
/// use with caution
pub const RenderBuffer = struct {};

/// Used internally by the renderer for shared uniforms
/// Not a part of the High-Level API
pub const UniformBuffer = struct {};

// components
/// Holds Vertex Data of a specific entity
/// This is used a component and shall be used as a dependency for the Model component later.
/// Don't change internal data of this struct unless you know what you're doing
pub const Mesh = struct {};

/// Contains the local transformations of a Mesh/Model
pub const Transform = struct {};

/// High-Level abstraction over the Transform component.
pub const Position = struct {};

/// Controls the speed of an object
pub const Velocity = struct {};

/// Controls the acceleration of an object
pub const Acceleration = struct {};

/// Holds 2D Texture Data
pub const Sprite = struct {};

/// Allows rendering text on the screen
/// This is used for UI text since it uses a separate camera from the default one (no perspective).
pub const Text2D = struct {};

var io = std.Io.Threaded.global_single_threaded.io();

// resource/dep
/// Compiles and Holds Shader data.
pub const Shader = struct {
    const Self = @This();
    const BUFFER_GROW: usize = 512;
    id: u32,

    pub fn init(allocator: *std.mem.Allocator, config: ShaderConfig) !Self {
        // read each file and compile it quickly.
        var buffer = try allocator.alloc(u8, BUFFER_GROW); // initial buf size
        defer allocator.free(buffer);

        const fragmentFile = try std.Io.Dir.cwd().openFile(io, config.fragment, .{ .mode = .read_only });
        defer fragmentFile.close(io);

        var n: usize = try fragmentFile.readPositionalAll(io, buffer, 0);
        var buffer_filled: usize = 0; // this will be set in the first loop.

        while (n > 0) : (n = try fragmentFile.readPositionalAll(io, buffer[buffer_filled..], buffer_filled)) {
            buffer_filled += n; // update length
            // EOF occured, fuck off
            // well... it's hard to explain..
            if (n < BUFFER_GROW) break
            else buffer = try allocator.realloc(buffer, buffer.len + BUFFER_GROW);
        }

        std.debug.print("{s}\n{}\n", .{ buffer[0..buffer_filled], n });

        return .{ .id = 0 };
    }

//     pub fn reload(self: Self) !void {

//     }

    pub fn deinit() void {}
};

pub const ShaderConfig = struct {
    /// vertex shader file path
    vertex: []const u8,
    /// fragment shader file path
    fragment: []const u8,
    /// geometry shaders
    geometry: ?[]const []const u8 = null,
};

/// Container for all shaders in a program.
/// Shaders inside this struct can be referenced by external components.
/// TODO: support precompiled shaders
/// TODO: support hot reloading
pub const ShaderManager = struct {
    const Self = @This();
    allocator: *std.mem.Allocator,
    tags: std.StringHashMap(usize),
    shaders: std.ArrayList(Shader),

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .tags = .init(allocator.*),
            .shaders = .empty,
        };
    }

    pub fn createShader(self: Self, config: ShaderConfig) !*Shader {
        const shader = try Shader.init(config);
        try self.shaders.append(self.allocator.*, shader);
    }

    pub fn createShaderTagged (self: Self, label: []const u8, config: ShaderConfig) !*Shader {
        const shader = try self.createShader(config);
        self.tags.put(label, shader - self.shaders.items.ptr);
        return shader;
    }

    pub fn deinit (self: *Self) void {
        for (self.shaders.items) |shader| {
            shader.deinit();
        }

        self.shaders.deinit(self.allocator.*);
        self.tags.deinit();
    }
};

// resource/deps
/// Low-Level Abstraction over a Texture
/// This may replace the Sprite if I find it useless
pub const Texture2D = struct {};

/// Low-Level Abstraction over a Cubemap
pub const CubeTexture2D = struct {};

/// Container for all program assets.
/// this is responsible of loading assets and converting them accordingly
pub const AssetManager = struct {};

// resource/deps
/// High-Level Abstraction over Miniaudio.
/// Used to load/play Sound objects.
/// TODO: implement sound groups.
pub const Audio = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    /// main audio player.
    engine: *ma.ma_engine,
    /// used to wait for loading
    fence: *ma.ma_fence,
    /// map of sound objects/labels
    /// this could probably be implemented in another way..
    sounds: std.StringHashMap(Sound),

    pub fn init(allocator: *std.mem.Allocator) !Self {
        // miniaudio stores pointers of its structs so we allocate them to keep the same location.
        const engine = try allocator.create(ma.ma_engine);
        const fence = try allocator.create(ma.ma_fence);

        if (ma.ma_engine_init(null, engine) != ma.MA_SUCCESS) return error.FuckMiniaudioMessedUpEngineInit;
        if (ma.ma_fence_init(fence) != ma.MA_SUCCESS) return error.FuckMiniaudioMessedUpFenceinit;

        return .{ 
            .allocator = allocator,
            .engine = engine,
            .sounds = .init(allocator.*),
            .fence = fence,
        };
    }

    pub fn deinit(self: *Self) void {
        ma.ma_fence_uninit(self.fence);
        ma.ma_engine_uninit(self.engine);
        var iter = self.sounds.valueIterator();
        while (iter.next()) |sound| {
            sound.*.deinit();
        }
        self.*.sounds.deinit();
        self.allocator.destroy(self.engine);
        self.allocator.destroy(self.fence);
    }

    /// Default volume is 1.
    pub fn setVolume(self: Self, volume: f32) void {
        _ = ma.ma_engine_set_volume(self.engine, volume);
    }

    /// Default volume is 1.
    pub fn getVolume(self: Self) f32 {
        return ma.ma_engine_get_volume(self.engine);
    }

    pub fn createSound(self: *Self, label: []const u8, config: SoundConfig) !*Sound {
        // Toggle sound init flags based on config
        var flags: c_int = 0; 
        if (!config.pitch) flags |= ma.MA_SOUND_FLAG_NO_PITCH;
        if (config.async) flags |= ma.MA_SOUND_FLAG_ASYNC;
        if (config.decode) flags |= ma.MA_SOUND_FLAG_DECODE;
        if (!config.spatialization) flags |= ma.MA_SOUND_FLAG_NO_SPATIALIZATION;
        if (config.stream) flags |= ma.MA_SOUND_FLAG_STREAM;

        const sound = try Sound.init(self.allocator, config.path, self, flags);
        try self.*.sounds.put(label, sound);

        return self.*.sounds.getPtr(label).?;
    }

    /// blocks the thread and waits until all sound objects (loaded with this interface) are loaded/decoded into memory.
    pub fn waitLoading(self: Self) void {
        _ = ma.ma_fence_wait(self.fence);
    }
};

/// Used to configure Sounds by the Audio service.
pub const SoundConfig = struct {
    /// setting this to false will optimize output but you can't change the pitch in return
    pitch: bool = true,
    /// whether to pre-decode the file or not
    decode: bool = true,
    /// load the sound file asyncronously
    async: bool = false,
    /// steam the file instead of reading it into memory
    stream: bool = false,
    /// something about positioning the audio in 3D space.
    /// shall be improved later.
    spatialization: bool = false,
    /// file to load
    path: []const u8,
};

/// Loads and Configures audio for playback
/// A sound object holds per-track configuration to make applying filters easier.
pub const Sound = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    sound: *ma.ma_sound,
    playing: bool = false,
    allow_pitch: bool,

    pub fn init(allocator: *std.mem.Allocator, path: []const u8, audio: *Audio, flags: c_int) !Self {
        const sound = try allocator.create(ma.ma_sound);
        if (ma.ma_sound_init_from_file(audio.engine, path.ptr, 0, null, audio.fence, sound) != ma.MA_SUCCESS) return error.FuckSoundInitMessedUp;

        return .{
            .allocator = allocator,
            .sound = sound,
            .allow_pitch = flags & ma.MA_SOUND_FLAG_NO_PITCH != 0,
        };
    }

    pub inline fn toggle(self: *Self) void {
        if (self.playing) self.pause() else self.play();
    }

    pub inline fn stop(self: *Self) void {
        self.pause();
        self.seek(0);
    }

    pub fn play(self: *Self) void {
        self.*.playing = true;
        _ = ma.ma_sound_start(self.sound);
    }

    pub fn pause(self: *Self) void {
        self.*.playing = false;
        _ = ma.ma_sound_stop(self.sound);
    }

    /// moves the playback cursor to `time` (in seconds)
    pub fn seek(self: Self, time: f32) void {
        _ = ma.ma_sound_seek_to_second(self.sound, time);
    }

    /// Default volume is 1.
    pub fn setVolume(self: Self, volume: f32) void {
        _ = ma.ma_sound_set_volume(self.sound, volume);
    }

    /// Default volume is 1.
    pub fn getVolume(self: Self) f32 {
        return ma.ma_sound_get_volume(&self.sound);
    }

    /// changes the pitch of a sound
    /// this function won't work if you created the sound with { pitch = false }
    pub fn setPitch(self: Self, pitch: f32) void {
        if (!self.allow_pitch) return;
        ma.ma_sound_set_pitch(self.sound, pitch);
    }

    /// enables/diables looping in this sound.
    pub fn setLoop(self: Self, v: bool) void {
        ma.ma_sound_set_looping(self.sound, @intFromBool(v));
    }

    pub fn deinit(self: Self) void {
        ma.ma_sound_uninit(self.sound);
        self.allocator.destroy(self.sound);
    }
};

// resources
/// Abstraction over GLFW's Mouse events.
/// TODO: implement custom cursors
pub const Mouse = struct {
    const Self = @This();

    window: *w.GLFWwindow,
    xpos: f64,
    ypos: f64,
    /// whether the mouse position changed since the last call to `updatePos`
    pos_changed: bool = false,
    cursor_mode: CursorMode = .Normal,

    pub fn init(window: *Window) Self {
        var xpos: f64 = 0;
        var ypos: f64 = 0;

        w.glfwGetCursorPos(window.window, &xpos, &ypos);

        return .{
            .window = window.window,
            .xpos = xpos,
            .ypos = ypos
        };
    }

    /// Changes cursor mode to be hidden/captured or disabled.
    pub fn setCursorMode(self: *Self, mode: CursorMode) void {
        if (self.cursor_mode == mode) return; // avoid useless calls
        w.glfwSetInputMode(self.window, w.GLFW_CURSOR, @intFromEnum(mode));
        self.*.cursor_mode = mode;
    }

    /// updates mouse data.
    /// use this function after calls to `Window.swapBuffers()` to update internal data
    pub fn updatePos(self: *Self) void {
        var v = [_]f64{ 0, 0 }; // tmp data.
        w.glfwGetCursorPos(self.window, &v[0], &v[1] );

        self.*.pos_changed = v[0] != self.xpos or v[1] != self.ypos;
        self.*.xpos = v[0];
        self.*.ypos = v[1];
    }

    pub fn isPressed(self: Self, button: MouseButton) bool {
        return w.glfwGetMouseButton(self.window, @intFromEnum(button)) == w.GLFW_PRESS;
    }

    /// when this is enabled, the state of a button will remain the same (not update even if it changes) until you read it via `isPressed`.
    pub fn enableStickyKeys(self: Self) void {
        w.glfwSetInputMode(self.window, w.GLFW_STICKY_MOUSE_BUTTONS, w.GLFW_TRUE);
    }

    pub fn disableStickyKeys(self: Self) void {
        w.glfwSetInputMode(self.window, w.GLFW_STICKY_MOUSE_BUTTONS, w.GLFW_FALSE);
    }
};

pub const MouseButton = enum (c_int) {
    // Those are removed since we have l/r/m
    // Button_1 = @as(c_int, 0),
    // Button_2 = @as(c_int, 1),
    // Button_3 = @as(c_int, 2),
    ButtonLeft   = @as(c_int, 0),
    ButtonRight  = @as(c_int, 1),
    ButtonMiddle = @as(c_int, 2),
    Button_4     = @as(c_int, 3),
    Button_5     = @as(c_int, 4),
    Button_6     = @as(c_int, 5),
    Button_7     = @as(c_int, 6),
    Button_8     = @as(c_int, 7),
};

pub const CursorMode = enum(c_int) {
    Normal = w.GLFW_CURSOR_NORMAL,
    Hidden = w.GLFW_CURSOR_HIDDEN,
    Disabled = w.GLFW_CURSOR_DISABLED,
    Captured = w.GLFW_CURSOR_CAPTURED,
};

/// Abstraction over GLFW's Keyboard events.
pub const Keyboard = struct {
    const Self = @This();
    window: *w.GLFWwindow,

    pub fn init(window: *Window) Self {
        return .{ .window = window.window };
    }

    /// Returns a null terminated string representing the name of the key in the user's keyboard.
    /// useful for displaying hints and all that..
    pub fn getKeyName (_: Self, key: KeyboardKey) ?[*:0]const u8 {
        return w.glfwGetKeyName(@intFromEnum(key), 0);
    }

    pub fn isPressed(self: Self, key: KeyboardKey) bool {
        return w.glfwGetKey(self.window, @intFromEnum(key)) == w.GLFW_PRESS;
    }

    /// when this is enabled, the state of a key will remain the same (not update even if it changes) until you read it via `isPressed`.
    pub fn enableStickyKeys(self: Self) void {
        w.glfwSetInputMode(self.window, w.GLFW_STICKY_KEYS, w.GLFW_TRUE);
    }

    pub fn disableStickyKeys(self: Self) void {
        w.glfwSetInputMode(self.window, w.GLFW_STICKY_KEYS, w.GLFW_FALSE);
    }
};

/// Generated from GLFW using the sexiest vim motions I know.
/// is it pervert to be triggered by those?
pub const KeyboardKey = enum(c_int) {
    UNKNOWN = -@as(c_int, 1),
    SPACE = @as(c_int, 32),
    APOSTROPHE = @as(c_int, 39),
    COMMA = @as(c_int, 44),
    MINUS = @as(c_int, 45),
    PERIOD = @as(c_int, 46),
    SLASH = @as(c_int, 47),
    NUM_0 = @as(c_int, 48),
    NUM_1 = @as(c_int, 49),
    NUM_2 = @as(c_int, 50),
    NUM_3 = @as(c_int, 51),
    NUM_4 = @as(c_int, 52),
    NUM_5 = @as(c_int, 53),
    NUM_6 = @as(c_int, 54),
    NUM_7 = @as(c_int, 55),
    NUM_8 = @as(c_int, 56),
    NUM_9 = @as(c_int, 57),
    SEMICOLON = @as(c_int, 59),
    EQUAL = @as(c_int, 61),
    A = @as(c_int, 65),
    B = @as(c_int, 66),
    C = @as(c_int, 67),
    D = @as(c_int, 68),
    E = @as(c_int, 69),
    F = @as(c_int, 70),
    G = @as(c_int, 71),
    H = @as(c_int, 72),
    I = @as(c_int, 73),
    J = @as(c_int, 74),
    K = @as(c_int, 75),
    L = @as(c_int, 76),
    M = @as(c_int, 77),
    N = @as(c_int, 78),
    O = @as(c_int, 79),
    P = @as(c_int, 80),
    Q = @as(c_int, 81),
    R = @as(c_int, 82),
    S = @as(c_int, 83),
    T = @as(c_int, 84),
    U = @as(c_int, 85),
    V = @as(c_int, 86),
    W = @as(c_int, 87),
    X = @as(c_int, 88),
    Y = @as(c_int, 89),
    Z = @as(c_int, 90),
    LEFT_BRACKET = @as(c_int, 91),
    BACKSLASH = @as(c_int, 92),
    RIGHT_BRACKET = @as(c_int, 93),
    GRAVE_ACCENT = @as(c_int, 96),
    WORLD_1 = @as(c_int, 161),
    WORLD_2 = @as(c_int, 162),
    ESCAPE = @as(c_int, 256),
    ENTER = @as(c_int, 257),
    TAB = @as(c_int, 258),
    BACKSPACE = @as(c_int, 259),
    INSERT = @as(c_int, 260),
    DELETE = @as(c_int, 261),
    RIGHT = @as(c_int, 262),
    LEFT = @as(c_int, 263),
    DOWN = @as(c_int, 264),
    UP = @as(c_int, 265),
    PAGE_UP = @as(c_int, 266),
    PAGE_DOWN = @as(c_int, 267),
    HOME = @as(c_int, 268),
    END = @as(c_int, 269),
    CAPS_LOCK = @as(c_int, 280),
    SCROLL_LOCK = @as(c_int, 281),
    NUM_LOCK = @as(c_int, 282),
    PRINT_SCREEN = @as(c_int, 283),
    PAUSE = @as(c_int, 284),
    F1 = @as(c_int, 290),
    F2 = @as(c_int, 291),
    F3 = @as(c_int, 292),
    F4 = @as(c_int, 293),
    F5 = @as(c_int, 294),
    F6 = @as(c_int, 295),
    F7 = @as(c_int, 296),
    F8 = @as(c_int, 297),
    F9 = @as(c_int, 298),
    F10 = @as(c_int, 299),
    F11 = @as(c_int, 300),
    F12 = @as(c_int, 301),
    F13 = @as(c_int, 302),
    F14 = @as(c_int, 303),
    F15 = @as(c_int, 304),
    F16 = @as(c_int, 305),
    F17 = @as(c_int, 306),
    F18 = @as(c_int, 307),
    F19 = @as(c_int, 308),
    F20 = @as(c_int, 309),
    F21 = @as(c_int, 310),
    F22 = @as(c_int, 311),
    F23 = @as(c_int, 312),
    F24 = @as(c_int, 313),
    F25 = @as(c_int, 314),
    KP_0 = @as(c_int, 320),
    KP_1 = @as(c_int, 321),
    KP_2 = @as(c_int, 322),
    KP_3 = @as(c_int, 323),
    KP_4 = @as(c_int, 324),
    KP_5 = @as(c_int, 325),
    KP_6 = @as(c_int, 326),
    KP_7 = @as(c_int, 327),
    KP_8 = @as(c_int, 328),
    KP_9 = @as(c_int, 329),
    KP_DECIMAL = @as(c_int, 330),
    KP_DIVIDE = @as(c_int, 331),
    KP_MULTIPLY = @as(c_int, 332),
    KP_SUBTRACT = @as(c_int, 333),
    KP_ADD = @as(c_int, 334),
    KP_ENTER = @as(c_int, 335),
    KP_EQUAL = @as(c_int, 336),
    LEFT_SHIFT = @as(c_int, 340),
    LEFT_CONTROL = @as(c_int, 341),
    LEFT_ALT = @as(c_int, 342),
    LEFT_SUPER = @as(c_int, 343),
    RIGHT_SHIFT = @as(c_int, 344),
    RIGHT_CONTROL = @as(c_int, 345),
    RIGHT_ALT = @as(c_int, 346),
    RIGHT_SUPER = @as(c_int, 347),
    MENU = @as(c_int, 348),
};

pub const Clipboard = struct {
    const Self = @This();
    /// Paths from the last file drop 
    /// check `paths_len`.
    var paths: ?[*]const [*:0]const u8 = null;
    var paths_len: u32 = 0;

    window: *w.GLFWwindow,

    /// ma3lik
    fn dropHandler (_: ?*w.GLFWwindow, n: c_int, path_names: [*c][*c]const u8) void {
        paths = path_names;
        paths_len = n;
    }

    pub fn init(window: *Window) Self {
        return .{ .window = window.window };
    }

    /// Registers callbacks for file drops
    /// Don't use if you don't plan to handle those.
    pub fn allowFileDrops (self: Self) void {
        w.glfwSetDropCallback(self.window, dropHandler);
    }

    pub fn getString(self: Self) ?[*:0]const u8 {
        return w.glfwGetClipboardString(self.window);
    }

    pub fn putString(self: Self, content: []const u8) void {
        w.glfwSetClipboardString(self.window, content.ptr);
    }
};

/// Time related utilities
pub const Clock = struct {
    const Self = @This();

    last_frame: f64,
    delta_time: f64,

    pub fn init() Self {
        return .{ .last_frame = w.glfwGetTime(), .delta_time = 0 };
    }

    /// DeltaTime
    pub fn dt(self: Self) f64 {
        return self.delta_time;
    }

    /// updates the clock with a new delta time data.
    /// use at the beginning of each frame.
    pub fn tick(self: *Self) void {
        self.*.delta_time = self.getTime() - self.last_frame;
        self.*.last_frame = self.getTime();
    }

    /// resets clock to zero.
    /// this may break dt variables to be careful.
    pub inline fn rewindClock(_: Self) void {
        w.glfwSetTime(0.0);
    }

    /// returns the time since the application's first window was initialized.
    /// this is affected with calls to rewindClock.
    pub inline fn getTime(_: Self) f64 {
        return w.glfwGetTime();
    }
};
