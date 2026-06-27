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

const Type = std.builtin.Type;

/// Type-erased scene wrapping any struct with optional load/exit/update/render/deinit.
/// This interface provides the ability to inject dynamic dependencies into children.
pub const Scene = struct {
    const Self = @This();

    ptr: *anyopaque,
    render_children: bool,

    loadFn: *const fn(ptr: *anyopaque) anyerror!void,
    exitFn: *const fn (ptr: *anyopaque) void,
    updateFn: *const fn (ptr: *anyopaque, dt: f64, ctx: *GameContext) anyerror!void,
    renderFn: *const fn (ptr: *anyopaque, frame: *Frame) anyerror!void,
    deinitFn: *const fn (ptr: *anyopaque) void,

    injectDeps: *const fn(ptr: *anyopaque, deps: *const GameDeps) void,

    /// Convert a concrete pointer to a type-erased Scene.
    pub fn wrap(ptr: anytype) Self {
        const scene = std.meta.Child(@TypeOf(ptr));

        const render_children: bool = if (@hasDecl(scene, "render_children")) scene.render_children else false;

        return .{
            .ptr = @ptrCast(ptr),
            .render_children = render_children,
            .loadFn = struct {
                fn f(p: *anyopaque) anyerror!void { 
                    if (@hasDecl(scene, "load")) return @call(.auto, scene.load, .{ @as(*scene, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .exitFn = struct {
                fn f(p: *anyopaque) void { 
                    if (@hasDecl(scene, "exit")) return @call(.auto, scene.exit, .{ @as(*scene, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .updateFn = struct {
                fn f(p: *anyopaque, dt: f64, ctx: *GameContext) anyerror!void { 
                    if (@hasDecl(scene, "update")) return @call(.auto, scene.update, .{ @as(*scene, @ptrCast(@alignCast(p))), dt, ctx }); 
                }
            }.f,
            .renderFn = struct {
                fn f(p: *anyopaque, frame: *Frame) anyerror!void { 
                    if (@hasDecl(scene, "render")) return @call(.auto, scene.render, .{ @as(*scene, @ptrCast(@alignCast(p))), frame }); 
                }
            }.f,
            .deinitFn = struct {
                fn f(p: *anyopaque) void {
                    if (@hasDecl(scene, "deinit")) return @call(.auto, scene.deinit, .{ @as(*scene, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .injectDeps = struct {
                const dest_field: []const u8 = "resolved";

                fn f(p: *anyopaque, deps: *const GameDeps) void {
                    if (!@hasField(scene, dest_field)) return;
                    const T = @FieldType(scene, dest_field);
                    if (@typeInfo(T) != .@"struct") return;

                    const fields: []const Type.StructField = std.meta.fields(T);
                    const instance: *scene = @ptrCast(@alignCast(p));

                    const depFields: []const Type.StructField = std.meta.fields(GameDeps);

                    inline for (fields) |field| {
                        if (@typeInfo(field.type) != .pointer) continue;

                        inline for (depFields) |dep| {
                            const dep_t = 
                                if (@typeInfo(dep.type) == .pointer) std.meta.Child(dep.type) 
                                else dep.type;

                            const dep_v: *dep_t = 
                                if (@typeInfo(dep.type) == .pointer) @field(deps, dep.name) 
                                else &@field(deps, dep.name);

                            if (field.type == *dep_t) { 
                                @field(@field(instance, dest_field), field.name) = dep_v;
                                break;
                            }
                        }
                    }
                }
            }.f,
        };
    }

    // TODO: find a better name
    pub fn exit(self: *const Self) void {
        return self.exitFn(self.ptr);
    }

    pub fn update(self: *const Self, dt: f64, ctx: *GameContext) !void {
        return self.updateFn(self.ptr, dt, ctx);
    }

    pub fn render(self: *const Self, frame: *Frame) !void {
        return self.renderFn(self.ptr, frame);
    }

    pub fn deinit(self: *const Self) void {
        return self.deinitFn(self.ptr);
    }

    /// Injects all required dependencies and calls the scene's .load() function.
    pub fn load(self: *const Self, deps: *const GameDeps) !void {
        self.injectDeps(self.ptr, deps);
        return try self.loadFn(self.ptr);
    }
};

/// Stack-based.
/// Todo: if there's no scenes, we're cooked.
pub const SceneManager = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    scenes: std.ArrayList(Scene),
    deps: *GameDeps = undefined,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .gpa = allocator,
            .scenes = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.scenes.items) |scene| {
            scene.deinit(self.gpa);
        }
        self.scenes.deinit(self.gpa);
    }

    /// Push a scene onto the stack. Calls exit on the old scene and enter on the new.
    pub fn push(self: *Self, scene: Scene) !void {
        if (self.scenes.getLastOrNull()) |current| {
            current.exit();
        }

        try self.scenes.append(self.gpa, scene);
        try scene.load(self.deps);
    }

    /// Pop the current scene. Goes back to the previous one (if any).
    pub fn pop(self: *Self) void {
        if (self.scenes.items.len == 0) return;

        const idx = self.scenes.items.len - 1;
        var scene = self.scenes.orderedRemove(idx);

        scene.exit();
        scene.deinit(self.gpa);
    }

    pub fn update(self: *const Self, dt: f64, ctx: *GameContext) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.update(dt, ctx);
    }

    // TODO: render all scenes instead of the top one.
    pub fn render(self: *const Self, frame: *Frame) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.render(frame);
    }
};

pub const GameDeps = struct {
    window: *Window,
    assetManager: AssetManager,
    shaderManager: ShaderManager,
    audio: Audio,
    mouse: Mouse,
    keyBoard: KeyBoard,
    clipboard: Clipboard,
};

pub const GameContext = struct {
    const Self = @This();

    _parent: *GameLoop = undefined,

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
    deps: GameDeps,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, pipeline: Pipeline) !Self {
        return .{
            .gpa = gpa,
            .clock = pipeline.ctx.clock,
            .window = pipeline.ctx.window,
            .scene_mgr = .init(gpa),
            .pipeline = pipeline,
            .target_fps = 60.0,
            .target_dt = 1.0 / 60.0,
            .accumulator = 0.0,
            .ctx = .{},
            .deps = .{
                .window = pipeline.ctx.window,
                .assetManager = .init(gpa),
                .audio = try .init(gpa),
                .shaderManager = .init(gpa, io),
                .mouse = .init(pipeline.ctx.window),
                .keyBoard = .init(pipeline.ctx.window),
                .clipboard = .init(pipeline.ctx.window),
            }
        };
    }

    pub fn deinit(self: *Self) void {
        self.scene_mgr.deinit();
        self.deps.assetManager.deinit();
        self.deps.shaderManager.deinit();
        self.deps.audio.deinit();
    }

    pub fn setTargetFps(self: *Self, fps: f64) void {
        self.target_fps = fps;
        self.target_dt = 1.0 / fps;
    }

    /// Main loop: tick clock, update at fixed dt, render with frame + pipeline.
    pub fn run(self: *Self) void {
        self.ctx._parent = self;
        self.scene_mgr.deps = &self.deps;

        var frame = Frame.init(self.gpa);
        defer frame.deinit();

        while (!self.window.shouldClose()) {
            self.clock.tick();
            self.deps.mouse.updatePos();

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
