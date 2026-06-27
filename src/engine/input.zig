const std = @import("std");

const w = @import("deps/glfw3.zig").w;

const Window = @import("renderer.zig").Window;

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
        self.cursor_mode = mode;
    }

    /// updates mouse data.
    /// use this function after calls to `Window.swapBuffers()` to update internal data
    pub fn updatePos(self: *Self) void {
        var v = [_]f64{ 0, 0 }; // tmp data.
        w.glfwGetCursorPos(self.window, &v[0], &v[1] );

        self.pos_changed = v[0] != self.xpos or v[1] != self.ypos;
        self.xpos = v[0];
        self.ypos = v[1];
    }

    pub fn isPressed(self: Self, button: MouseButton) bool {
        return w.glfwGetMouseButton(self.window, @intFromEnum(button)) == w.GLFW_PRESS;
    }

    /// when this is enabled, the state of a button will remain the same (not update even if it changes) until you read it via `isPressed`.
    pub fn setStickyKeys(self: Self, enabled: bool) void {
        w.glfwSetInputMode(self.window, w.GLFW_STICKY_MOUSE_BUTTONS, @intFromBool(enabled));
    }
};

pub const MouseButton = enum (i32) {
    ButtonLeft   = @as(i32, 0),
    ButtonRight  = @as(i32, 1),
    ButtonMiddle = @as(i32, 2),
    Button4     = @as(i32, 3),
    Button5     = @as(i32, 4),
    Button6     = @as(i32, 5),
    Button7     = @as(i32, 6),
    Button8     = @as(i32, 7),
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
/// is it pervert to get turned on by vim?
pub const KeyboardKey = enum(i32) {
    Unknown = -@as(i32, 1),
    Space = @as(i32, 32),
    Apostrophe = @as(i32, 39),
    Comma = @as(i32, 44),
    Minus = @as(i32, 45),
    Period = @as(i32, 46),
    Slash = @as(i32, 47),
    Num0 = @as(i32, 48),
    Num1 = @as(i32, 49),
    Num2 = @as(i32, 50),
    Num3 = @as(i32, 51),
    Num4 = @as(i32, 52),
    Num5 = @as(i32, 53),
    Num6 = @as(i32, 54),
    Num7 = @as(i32, 55),
    Num8 = @as(i32, 56),
    Num9 = @as(i32, 57),
    Semicolon = @as(i32, 59),
    Equal = @as(i32, 61),
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
    LeftBracket = @as(i32, 91),
    Backslash = @as(i32, 92),
    RightBracket = @as(i32, 93),
    GraveAccent = @as(i32, 96),
    World1 = @as(i32, 161),
    World2 = @as(i32, 162),
    Escape = @as(i32, 256),
    Enter = @as(i32, 257),
    Tab = @as(i32, 258),
    Backspace = @as(i32, 259),
    Insert = @as(i32, 260),
    Delete = @as(i32, 261),
    Right = @as(i32, 262),
    Left = @as(i32, 263),
    Down = @as(i32, 264),
    Up = @as(i32, 265),
    PageUp = @as(i32, 266),
    PageDown = @as(i32, 267),
    Home = @as(i32, 268),
    End = @as(i32, 269),
    CapsLock = @as(i32, 280),
    ScrollLock = @as(i32, 281),
    NumLock = @as(i32, 282),
    PrintScreen = @as(i32, 283),
    Pause = @as(i32, 284),
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
    Kp0 = @as(i32, 320),
    Kp1 = @as(i32, 321),
    Kp2 = @as(i32, 322),
    Kp3 = @as(i32, 323),
    Kp4 = @as(i32, 324),
    Kp5 = @as(i32, 325),
    Kp6 = @as(i32, 326),
    Kp7 = @as(i32, 327),
    Kp8 = @as(i32, 328),
    Kp9 = @as(i32, 329),
    KpDecimal = @as(i32, 330),
    KpDivide = @as(i32, 331),
    KpMultiply = @as(i32, 332),
    KpSubtract = @as(i32, 333),
    KpAdd = @as(i32, 334),
    KpEnter = @as(i32, 335),
    KpEqual = @as(i32, 336),
    LeftShift = @as(i32, 340),
    LeftControl = @as(i32, 341),
    LeftAlt = @as(i32, 342),
    LeftSuper = @as(i32, 343),
    RightShift = @as(i32, 344),
    RightControl = @as(i32, 345),
    RightAlt = @as(i32, 346),
    RightSuper = @as(i32, 347),
    Menu = @as(i32, 348),
};

pub const Clipboard = struct {
    const Self = @This();

    window: *w.GLFWwindow,

    pub fn init(window: *Window) Self {
        return .{ .window = window.window };
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
    pub fn dt(self: Self) f32 {
        return @floatCast(self.delta_time);
    }

    /// updates the clock with a new delta time data.
    /// use at the beginning of each frame.
    pub fn tick(self: *Self) void {
        self.delta_time = w.glfwGetTime() - self.last_frame;
        self.last_frame = w.glfwGetTime();
    }

    /// Returns the elapsed time since the game launched.
    pub fn elapsed(self: *Self) f64 {
        _ = self;
        return w.glfwGetTime();
    }
};

pub const Joystick = struct {
    const Self = @This();

    id: c_int,
    name: [*c]const u8,

    _axes: [16]f32 = undefined,
    _buttons: [128]bool = undefined,
    _hats: [16]JoystickHatPos = undefined,

    axes: []const f32 = &.{},
    buttons: []const bool = &.{},
    hats: []const JoystickHatPos = &.{},

    pub fn init(id: JoystickId) !Self {
        if (!present(id)) return error.JoystickNotPresent;

        return .{
            .id = @intFromEnum(id),
            .name = w.glfwGetJoystickName(@intFromEnum(id)),
        };
    }

    pub fn update(self: *Self) !void {
        var count: i32 = undefined;

        const axes = w.glfwGetJoystickAxes(self.id, &count);
        for (0..@intCast(count)) |i| self._axes[i] = axes[i];

        self.axes = self._axes[0..@intCast(count)];
        
        const buttons = w.glfwGetJoystickButtons(self.id, &count);
        for (0..@intCast(count)) |i| self._buttons[i] = buttons[i] == w.GLFW_PRESS;

        self.buttons = self._buttons[0..@intCast(count)];

        const hats = w.glfwGetJoystickHats(self.id, &count);
        for (0..@intCast(count)) |i| self._hats[i] = @enumFromInt(hats[i]);

        self.hats = self._hats[0..@intCast(count)];
    }

    pub fn asGamepad(self: Self) !Gamepad {
        return try Gamepad.init(&self);
    }

    pub fn getFirstConnected() ?JoystickId {
        for (0..16) |i| {
            const id: JoystickId = @enumFromInt(i);
            if (present(id)) return id;
        }

        return null;
    }

    pub fn present(id: JoystickId) bool {
        const val = w.glfwJoystickPresent(@intFromEnum(id));
        return val != 0;
    }
};

pub const JoystickHatPos = enum (u8) {
    const Self = @This();

    Centered = 0,
    Up = 1,
    Right = 2,
    Down = 4,
    Left = 8,
    RightUp = w.GLFW_HAT_RIGHT | w.GLFW_HAT_UP,
    RightDown= w.GLFW_HAT_RIGHT | w.GLFW_HAT_DOWN,
    LeftUp = w.GLFW_HAT_LEFT | w.GLFW_HAT_UP,
    LeftDown = w.GLFW_HAT_LEFT | w.GLFW_HAT_DOWN,

    pub fn is(self: Self, val: Self) bool {
        return (@intFromEnum(self) & @intFromEnum(val)) != 0;
    }
};

pub const JoystickId = enum (c_int) {
    Joystick1 = @as(c_int, 0),
    Joystick2 = @as(c_int, 1),
    Joystick3 = @as(c_int, 2),
    Joystick4 = @as(c_int, 3),
    Joystick5 = @as(c_int, 4),
    Joystick6 = @as(c_int, 5),
    Joystick7 = @as(c_int, 6),
    Joystick8 = @as(c_int, 7),
    Joystick9 = @as(c_int, 8),
    Joystick10 = @as(c_int, 9),
    Joystick11 = @as(c_int, 10),
    Joystick12 = @as(c_int, 11),
    Joystick13 = @as(c_int, 12),
    Joystick14 = @as(c_int, 13),
    Joystick15 = @as(c_int, 14),
    Joystick16 = @as(c_int, 15),
};

pub const Gamepad = struct {
    const Self = @This();

    id: c_int,
    name: [*c]const u8,
    state: w.GLFWgamepadstate = undefined,

    pub fn init(base: *const Joystick) !Self {
        if (!isGamepad(base)) return error.JoystickIsNotAGamepad;

        var state: w.GLFWgamepadstate = undefined;
        if (w.glfwGetGamepadState(base.id, &state) == 0) return error.StateQueryFailed;

        return .{
            .id = base.id,
            .name = w.glfwGetGamepadName(base.id),
            .state = state,
        };
    }

    pub fn update(self: *Self) !void {
        if (w.glfwGetGamepadState(self.id, &self.state) == 0) return error.StateQueryFailed;
    }

    pub fn isPressed(self: *const Self, button: GamepadButton) bool {
        return self.state.buttons[button.value()] == w.GLFW_PRESS;
    }

    pub fn getAxis(self: *const Self, axis: GamepadAxis) f32 {
        return self.state.axes[@intFromEnum(axis)];
    }

    pub fn isGamepad(joystick: *const Joystick) bool {
        return w.glfwJoystickIsGamepad(joystick.id) != 0;
    }
};

pub const GamepadAxis = enum (u3) {
    LeftX = @as(u3, 0),
    LeftY = @as(u3, 1),
    RightX = @as(u3, 2),
    RightY = @as(u3, 3),
    LeftTrigger = @as(u3, 4),
    RightTrigger = @as(u3, 5),
};

pub const GamepadButton = enum {
    A, B, X, Y,
    LeftBumper, RightBumper,
    Back, Start, Guide,
    LeftThumb, RightThumb,
    DpadUp, DpadRight, DpadDown, DpadLeft,
    Cross, Circle, Square, Triangle,

    pub fn value(self: GamepadButton) usize {
        return @intCast(
            switch (self) {
                .A, .Cross => w.GLFW_GAMEPAD_BUTTON_A,
                .B, .Circle => w.GLFW_GAMEPAD_BUTTON_B,
                .X, .Square => w.GLFW_GAMEPAD_BUTTON_X,
                .Y, .Triangle => w.GLFW_GAMEPAD_BUTTON_Y,
                .LeftBumper => w.GLFW_GAMEPAD_BUTTON_LEFT_BUMPER,
                .RightBumper => w.GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER,
                .Back => w.GLFW_GAMEPAD_BUTTON_BACK,
                .Start => w.GLFW_GAMEPAD_BUTTON_START,
                .Guide => w.GLFW_GAMEPAD_BUTTON_GUIDE,
                .LeftThumb => w.GLFW_GAMEPAD_BUTTON_LEFT_THUMB,
                .RightThumb => w.GLFW_GAMEPAD_BUTTON_RIGHT_THUMB,
                .DpadUp => w.GLFW_GAMEPAD_BUTTON_DPAD_UP,
                .DpadDown => w.GLFW_GAMEPAD_BUTTON_DPAD_DOWN,
                .DpadLeft => w.GLFW_GAMEPAD_BUTTON_DPAD_LEFT,
                .DpadRight => w.GLFW_GAMEPAD_BUTTON_DPAD_RIGHT,
            }
        );
    }
};
