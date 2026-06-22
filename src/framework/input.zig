const std = @import("std");
const engine = @import("../engine/root.zig");

/// Per-frame lifecycle of a key/button.
pub const InputState = enum {
    pressed,
    released,
    just_pressed,
    just_released,
};

/// What physical input can trigger an action.
pub const InputBinding = union(enum) {
    key: engine.KeyboardKey,
    mouse_button: engine.MouseButton,
};

/// A named action mapped to one or more bindings, with current state and analog value.
pub const InputAction = struct {
    name: []const u8,
    bindings: []InputBinding,
    state: InputState,
    value: f32,
};

const KeySet = std.StaticBitSet(350);
const MouseSet = std.StaticBitSet(10);

/// Maps raw keyboard/mouse input to named actions with edge detection.
pub const InputMapper = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    actions: std.StringHashMap(InputAction),
    prev_keys: KeySet,
    curr_keys: KeySet,
    prev_mouse: MouseSet,
    curr_mouse: MouseSet,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .actions = .init(allocator),
            .prev_keys = KeySet.initEmpty(),
            .curr_keys = KeySet.initEmpty(),
            .prev_mouse = MouseSet.initEmpty(),
            .curr_mouse = MouseSet.initEmpty(),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.actions.valueIterator();
        while (it.next()) |action| {
            self.allocator.free(action.name);
            self.allocator.free(action.bindings);
        }
        self.actions.deinit();
    }

    /// Register a named action with one or more bindings.
    pub fn addAction(self: *Self, name: []const u8, bindings: []const InputBinding) !void {
        const name_copy = try self.allocator.dupe(u8, name);
        const bindings_copy = try self.allocator.dupe(InputBinding, bindings);
        try self.actions.put(name_copy, .{
            .name = name_copy,
            .bindings = bindings_copy,
            .state = .released,
            .value = 0,
        });
    }

    /// Poll hardware, derive just_pressed/just_released from prev/curr bit sets.
    pub fn update(self: *Self, keyboard: *engine.Keyboard, mouse: *engine.Mouse) void {
        self.prev_keys = self.curr_keys;
        self.prev_mouse = self.curr_mouse;

        self.curr_keys = KeySet.initEmpty();
        self.curr_mouse = MouseSet.initEmpty();

        inline for (@typeInfo(engine.KeyboardKey).@"enum".fields) |field| {
            const key = @as(engine.KeyboardKey, @enumFromInt(field.value));
            if (key != .Unknown and keyboard.isPressed(key)) {
                self.curr_keys.set(@as(usize, field.value + 1));
            }
        }

        inline for (@typeInfo(engine.MouseButton).@"enum".fields) |field| {
            const btn = @as(engine.MouseButton, @enumFromInt(field.value));
            if (mouse.isPressed(btn)) {
                self.curr_mouse.set(@as(usize, field.value + 1));
            }
        }

        var it = self.actions.valueIterator();
        while (it.next()) |action| {
            const pressed = for (action.bindings) |binding| {
                break switch (binding) {
                    .key => |k| self.curr_keys.isSet(@as(usize, @intCast(@intFromEnum(k) + 1))),
                    .mouse_button => |mb| self.curr_mouse.isSet(@as(usize, @intCast(@intFromEnum(mb) + 1))),
                };
            } else false;

            const was_pressed = for (action.bindings) |binding| {
                break switch (binding) {
                    .key => |k| self.prev_keys.isSet(@as(usize, @intCast(@intFromEnum(k) + 1))),
                    .mouse_button => |mb| self.prev_mouse.isSet(@as(usize, @intCast(@intFromEnum(mb) + 1))),
                };
            } else false;

            action.state = if (pressed and !was_pressed) .just_pressed
                else if (pressed and was_pressed) .pressed
                else if (!pressed and was_pressed) .just_released
                else .released;

            action.value = if (pressed) 1.0 else 0.0;
        }
    }

    pub fn actionState(self: Self, name: []const u8) InputState {
        return self.actions.get(name).?.state;
    }

    pub fn actionValue(self: Self, name: []const u8) f32 {
        return self.actions.get(name).?.value;
    }

    pub fn isPressed(self: Self, name: []const u8) bool {
        const action = self.actions.get(name) orelse return false;
        return action.state == .pressed or action.state == .just_pressed;
    }

    pub fn justPressed(self: Self, name: []const u8) bool {
        const action = self.actions.get(name) orelse return false;
        return action.state == .just_pressed;
    }

    pub fn justReleased(self: Self, name: []const u8) bool {
        const action = self.actions.get(name) orelse return false;
        return action.state == .just_released;
    }
};
