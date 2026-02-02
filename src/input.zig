const std = @import("std");

const w = @import("deps/glfw3.zig");

const Window = @import("renderer.zig").Window;

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

pub const MouseButton = enum (i32) {
    // Those are removed since we have l/r/m
    // Button_1 = @as(c_int, 0),
    // Button_2 = @as(c_int, 1),
    // Button_3 = @as(c_int, 2),
    ButtonLeft   = @as(i32, 0),
    ButtonRight  = @as(i32, 1),
    ButtonMiddle = @as(i32, 2),
    Button_4     = @as(i32, 3),
    Button_5     = @as(i32, 4),
    Button_6     = @as(i32, 5),
    Button_7     = @as(i32, 6),
    Button_8     = @as(i32, 7),
};

pub const CursorMode = enum(i32) {
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
pub const KeyboardKey = enum(i32) {
    UNKNOWN = -@as(i32, 1),
    SPACE = @as(i32, 32),
    APOSTROPHE = @as(i32, 39),
    COMMA = @as(i32, 44),
    MINUS = @as(i32, 45),
    PERIOD = @as(i32, 46),
    SLASH = @as(i32, 47),
    NUM_0 = @as(i32, 48),
    NUM_1 = @as(i32, 49),
    NUM_2 = @as(i32, 50),
    NUM_3 = @as(i32, 51),
    NUM_4 = @as(i32, 52),
    NUM_5 = @as(i32, 53),
    NUM_6 = @as(i32, 54),
    NUM_7 = @as(i32, 55),
    NUM_8 = @as(i32, 56),
    NUM_9 = @as(i32, 57),
    SEMICOLON = @as(i32, 59),
    EQUAL = @as(i32, 61),
    A = @as(i32, 65),
    B = @as(i32, 66),
    C = @as(i32, 67),
    D = @as(i32, 68),
    E = @as(i32, 69),
    F = @as(i32, 70),
    G = @as(i32, 71),
    H = @as(i32, 72),
    I = @as(i32, 73),
    J = @as(i32, 74),
    K = @as(i32, 75),
    L = @as(i32, 76),
    M = @as(i32, 77),
    N = @as(i32, 78),
    O = @as(i32, 79),
    P = @as(i32, 80),
    Q = @as(i32, 81),
    R = @as(i32, 82),
    S = @as(i32, 83),
    T = @as(i32, 84),
    U = @as(i32, 85),
    V = @as(i32, 86),
    W = @as(i32, 87),
    X = @as(i32, 88),
    Y = @as(i32, 89),
    Z = @as(i32, 90),
    LEFT_BRACKET = @as(i32, 91),
    BACKSLASH = @as(i32, 92),
    RIGHT_BRACKET = @as(i32, 93),
    GRAVE_ACCENT = @as(i32, 96),
    WORLD_1 = @as(i32, 161),
    WORLD_2 = @as(i32, 162),
    ESCAPE = @as(i32, 256),
    ENTER = @as(i32, 257),
    TAB = @as(i32, 258),
    BACKSPACE = @as(i32, 259),
    INSERT = @as(i32, 260),
    DELETE = @as(i32, 261),
    RIGHT = @as(i32, 262),
    LEFT = @as(i32, 263),
    DOWN = @as(i32, 264),
    UP = @as(i32, 265),
    PAGE_UP = @as(i32, 266),
    PAGE_DOWN = @as(i32, 267),
    HOME = @as(i32, 268),
    END = @as(i32, 269),
    CAPS_LOCK = @as(i32, 280),
    SCROLL_LOCK = @as(i32, 281),
    NUM_LOCK = @as(i32, 282),
    PRINT_SCREEN = @as(i32, 283),
    PAUSE = @as(i32, 284),
    F1 = @as(i32, 290),
    F2 = @as(i32, 291),
    F3 = @as(i32, 292),
    F4 = @as(i32, 293),
    F5 = @as(i32, 294),
    F6 = @as(i32, 295),
    F7 = @as(i32, 296),
    F8 = @as(i32, 297),
    F9 = @as(i32, 298),
    F10 = @as(i32, 299),
    F11 = @as(i32, 300),
    F12 = @as(i32, 301),
    F13 = @as(i32, 302),
    F14 = @as(i32, 303),
    F15 = @as(i32, 304),
    F16 = @as(i32, 305),
    F17 = @as(i32, 306),
    F18 = @as(i32, 307),
    F19 = @as(i32, 308),
    F20 = @as(i32, 309),
    F21 = @as(i32, 310),
    F22 = @as(i32, 311),
    F23 = @as(i32, 312),
    F24 = @as(i32, 313),
    F25 = @as(i32, 314),
    KP_0 = @as(i32, 320),
    KP_1 = @as(i32, 321),
    KP_2 = @as(i32, 322),
    KP_3 = @as(i32, 323),
    KP_4 = @as(i32, 324),
    KP_5 = @as(i32, 325),
    KP_6 = @as(i32, 326),
    KP_7 = @as(i32, 327),
    KP_8 = @as(i32, 328),
    KP_9 = @as(i32, 329),
    KP_DECIMAL = @as(i32, 330),
    KP_DIVIDE = @as(i32, 331),
    KP_MULTIPLY = @as(i32, 332),
    KP_SUBTRACT = @as(i32, 333),
    KP_ADD = @as(i32, 334),
    KP_ENTER = @as(i32, 335),
    KP_EQUAL = @as(i32, 336),
    LEFT_SHIFT = @as(i32, 340),
    LEFT_CONTROL = @as(i32, 341),
    LEFT_ALT = @as(i32, 342),
    LEFT_SUPER = @as(i32, 343),
    RIGHT_SHIFT = @as(i32, 344),
    RIGHT_CONTROL = @as(i32, 345),
    RIGHT_ALT = @as(i32, 346),
    RIGHT_SUPER = @as(i32, 347),
    MENU = @as(i32, 348),
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
    /// this may break `dt` variables so be careful.
    pub inline fn rewindClock(_: Self) void {
        w.glfwSetTime(0.0);
    }

    /// returns the time since the application's first window was initialized.
    /// this is affected with calls to `rewindClock`.
    pub inline fn getTime(_: Self) f64 {
        return w.glfwGetTime();
    }
};
