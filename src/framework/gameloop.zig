const std = @import("std");
const engine = @import("../engine/root.zig");

const Clock = engine.Clock;
const Window = engine.Window;
const AssetManager = engine.AssetManager;
const Audio = engine.Audio;
const ShaderManager = engine.ShaderManager;
const Clipboard = engine.Clipboard;
const KeyBoard = engine.Keyboard;
const Mouse = engine.Mouse;

const Frame = @import("frame.zig").Frame;
const Pipeline = @import("pipeline.zig").Pipeline;

const InputMapper = @import("input.zig").InputMapper;
const Camera = @import("camera.zig").Camera;

/// Type-erased scene wrapping any struct with optional enter/exit/update/render/deinit.
pub const Scene = struct {
    const Self = @This();

    ptr: *anyopaque,
    enterFn: *const fn (ptr: *anyopaque) anyerror!void,
    exitFn: *const fn (ptr: *anyopaque) void,
    updateFn: *const fn (ptr: *anyopaque, dt: f64, ctx: *GameContext) anyerror!void,
    renderFn: *const fn (ptr: *anyopaque, frame: *Frame) anyerror!void,
    deinitFn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,

    /// Convert a concrete pointer to a type-erased Scene. Methods are looked up via @hasDecl.
    pub fn wrap(ptr: anytype) Self {
        const child = std.meta.Child(@TypeOf(ptr));

        return .{
            .ptr = @ptrCast(ptr),
            .enterFn = struct {
                fn f(p: *anyopaque) anyerror!void { 
                    if (@hasDecl(child, "enter")) return @call(.auto, child.enter, .{ @as(*child, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .exitFn = struct {
                fn f(p: *anyopaque) void { 
                    if (@hasDecl(child, "exit")) return @call(.auto, child.exit, .{ @as(*child, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .updateFn = struct {
                fn f(p: *anyopaque, dt: f64, ctx: *GameContext) anyerror!void { 
                    if (@hasDecl(child, "update")) return @call(.auto, child.update, .{ @as(*child, @ptrCast(@alignCast(p))), dt, ctx }); 
                }
            }.f,
            .renderFn = struct {
                fn f(p: *anyopaque, frame: *Frame) anyerror!void { 
                    if (@hasDecl(child, "render")) return @call(.auto, child.render, .{ @as(*child, @ptrCast(@alignCast(p))), frame }); 
                }
            }.f,
            .deinitFn = struct {
                fn f(p: *anyopaque, allocator: std.mem.Allocator) void {
                    const typed: *child = @ptrCast(@alignCast(p));
                    if (@hasDecl(child, "deinit")) typed.deinit();
                    allocator.destroy(typed);
                }
            }.f,
        };
    }

    pub fn enter(self: *const Self) !void {
        return self.enterFn(self.ptr);
    }

    pub fn exit(self: *const Self) void {
        return self.exitFn(self.ptr);
    }

    pub fn update(self: *const Self, dt: f64, ctx: *GameContext) !void {
        return self.updateFn(self.ptr, dt, ctx);
    }

    pub fn render(self: *const Self, frame: *Frame) !void {
        return self.renderFn(self.ptr, frame);
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        return self.deinitFn(self.ptr, allocator);
    }
};

/// Stack-based scene manager. Push scenes on, pop them off — only the top scene runs.
pub const SceneManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    scenes: std.ArrayList(Scene),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .scenes = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.scenes.items) |scene| {
            scene.deinit(self.allocator);
        }
        self.scenes.deinit(self.allocator);
    }

    /// Push a scene onto the stack. Calls exit on the old scene and enter on the new.
    pub fn push(self: *Self, scene: Scene) !void {
        if (self.scenes.getLastOrNull()) |current| {
            current.exit();
        }

        try self.scenes.append(self.allocator, scene);
        try scene.enter();
    }

    /// Pop the current scene. Goes back to the previous one (if any).
    pub fn pop(self: *Self) void {
        if (self.scenes.items.len == 0) return;

        const idx = self.scenes.items.len - 1;
        var scene = self.scenes.orderedRemove(idx);

        scene.exit();
        scene.deinit(self.allocator);
    }

    pub fn update(self: Self, dt: f64, ctx: *GameContext) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.update(dt, ctx);
    }

    pub fn render(self: Self, frame: *Frame) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.render(frame);
    }
};

pub const GameContext = struct {
    const Self = @This();

    _parent: *GameLoop = undefined,

    window: *Window,
    input: InputMapper,
    assets: AssetManager,
    shader: ShaderManager,
    audio: Audio,
    mouse: Mouse,
    kb: KeyBoard,
    clipboard: Clipboard,

    /// Closes the main window, enging the game loop.
    pub fn quit(self: *Self) void {
        self._parent.window.close();
    }

    /// Changes the camera sent to the renderer on each frame.
    pub fn setCamera(self: *Self, cam: *Camera) void {
        self._parent.pipeline.ctx.camera = cam;
    }

    pub fn sceneMgr(self: *Self) *SceneManager {
        return &self._parent.scene_mgr;
    }

};

/// Fixed-timestep game loop: accumulates real time and runs updates in discrete dt chunks.
pub const GameLoop = struct {
    const Self = @This();

    gpa: std.mem.Allocator,

    clock: *Clock,
    window: *Window,
    
    scene_mgr: SceneManager,
    pipeline: Pipeline,

    target_fps: f64,
    target_dt: f64,
    accumulator: f64,

    ctx: GameContext,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, pipeline: Pipeline) Self {
        return .{
            .gpa = gpa,
            .clock = pipeline.ctx.clock,
            .window = pipeline.ctx.window,
            .scene_mgr = .init(gpa),
            .pipeline = pipeline,
            .target_fps = 60.0,
            .target_dt = 1.0 / 60.0,
            .accumulator = 0.0,
            .ctx = .{
                .window = pipeline.ctx.window,
                .input = .init(gpa),
                .assets = .init(gpa),
                .audio = .init(gpa),
                .shader = .init(gpa, io),
                .mouse = .init(pipeline.ctx.window),
                .kb = .init(pipeline.ctx.window),
                .clipboard = .init(pipeline.ctx.window),
            }
        };
    }

    pub fn deinit(self: *Self) void {
        self.scene_mgr.deinit();
        self.ctx.input.deinit();
        self.ctx.assets.deinit();
        self.ctx.shader.deinit();
        self.ctx.audio.deinit();
    }

    pub fn setTargetFps(self: *Self, fps: f64) void {
        self.target_fps = fps;
        self.target_dt = 1.0 / fps;
    }

    /// Main loop: tick clock, update at fixed dt, render with frame + pipeline.
    pub fn run(self: *Self) void {
        self.ctx._parent = self;

        var frame = Frame.init(self.gpa);
        defer frame.deinit();

        while (!self.window.shouldClose()) {
            self.clock.tick();
            self.ctx.mouse.updatePos();
            self.ctx.input.update(self.ctx.kb, self.ctx.mouse);

            self.accumulator += self.clock.dt();

            while (self.accumulator >= self.target_dt) {
                self.scene_mgr.update(self.target_dt, self.ctx);
                self.accumulator -= self.target_dt;
            }

            frame.clear();

            self.scene_mgr.render(&frame);
            self.pipeline.execute(&frame);
        }
    }
};
