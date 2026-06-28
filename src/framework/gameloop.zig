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

const ServiceManager = @import("services.zig").ServiceManager;

const Type = std.builtin.Type;

/// Type-erased scene wrapping any struct with optional load/exit/update/render/deinit.
/// This interface provides the ability to inject dynamic dependencies into children.
pub const Scene = struct {
    const Self = @This();

    ptr: *anyopaque,
    draw_children: bool,

    loadFn: *const fn(ptr: *anyopaque) anyerror!void,
    exitFn: *const fn (ptr: *anyopaque) void,
    updateFn: *const fn (ptr: *anyopaque, dt: f32, ctx: *GameContext) anyerror!void,
    drawFn: *const fn (ptr: *anyopaque, frame: *Frame) anyerror!void,
    deinitFn: *const fn (ptr: *anyopaque) void,

    injectDependencies: *const fn(ptr: *anyopaque, services: *const ServiceManager) void,

    /// Convert a concrete pointer to a type-erased Scene.
    pub fn wrap(ptr: anytype) Self {
        const scene = std.meta.Child(@TypeOf(ptr));

        const draw_children: bool = if (@hasDecl(scene, "draw_children")) scene.draw_children else false;

        return .{
            .ptr = @ptrCast(ptr),
            .draw_children = draw_children,
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
                fn f(p: *anyopaque, dt: f32, ctx: *GameContext) anyerror!void { 
                    if (@hasDecl(scene, "update")) return @call(.auto, scene.update, .{ @as(*scene, @ptrCast(@alignCast(p))), dt, ctx }); 
                }
            }.f,
            .drawFn = struct {
                fn f(p: *anyopaque, frame: *Frame) anyerror!void { 
                    if (@hasDecl(scene, "draw")) return @call(.auto, scene.draw, .{ @as(*scene, @ptrCast(@alignCast(p))), frame }); 
                }
            }.f,
            .deinitFn = struct {
                fn f(p: *anyopaque) void {
                    if (@hasDecl(scene, "deinit")) return @call(.auto, scene.deinit, .{ @as(*scene, @ptrCast(@alignCast(p))) }); 
                }
            }.f,
            .injectDependencies = struct {
                const dest_field: []const u8 = "resolved";

                fn f(p: *anyopaque, services: *const ServiceManager) void {
                    if (!@hasField(scene, dest_field)) return;
                    const T = @FieldType(scene, dest_field);
                    if (@typeInfo(T) != .@"struct") return;

                    const fields: []const Type.StructField = std.meta.fields(T);
                    const instance: *scene = @ptrCast(@alignCast(p));

                    inline for (fields) |field| {
                        if (@typeInfo(field.type) != .pointer) continue;
                        const C = std.meta.Child(field.type);

                        if (services.get(C)) |service| {
                            @field(@field(instance, dest_field), field.name) = service;
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

    pub fn update(self: *const Self, dt: f32, ctx: *GameContext) !void {
        return self.updateFn(self.ptr, dt, ctx);
    }

    pub fn draw(self: *const Self, frame: *Frame) !void {
        return self.drawFn(self.ptr, frame);
    }

    pub fn deinit(self: *const Self) void {
        return self.deinitFn(self.ptr);
    }

    /// Injects all required dependencies and calls the scene's .load() function.
    pub fn load(self: *const Self, services: *const ServiceManager) !void {
        self.injectDependencies(self.ptr, services);
        return try self.loadFn(self.ptr);
    }
};

/// Stack-based.
/// Todo: if there's no scenes, we're cooked.
pub const SceneManager = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    scenes: std.ArrayList(Scene),
    _services: *const ServiceManager,

    pub fn init(allocator: std.mem.Allocator, services: *const ServiceManager) Self {
        return .{
            .gpa = allocator,
            .scenes = .empty,
            ._services = services,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.scenes.items) |scene| {
            scene.deinit();
        }
        self.scenes.deinit(self.gpa);
    }

    /// Push a scene onto the stack. Calls exit on the old scene and enter on the new.
    pub fn push(self: *Self, scene: Scene) !void {
        if (self.scenes.getLastOrNull()) |current| {
            current.exit();
        }

        try self.scenes.append(self.gpa, scene);
        try scene.load(self._services);
    }

    /// Pop the current scene. Goes back to the previous one (if any).
    pub fn pop(self: *Self) void {
        if (self.scenes.items.len == 0) return;

        const idx = self.scenes.items.len - 1;
        var scene = self.scenes.orderedRemove(idx);

        scene.exit();
        scene.deinit();
    }

    pub fn update(self: *const Self, dt: f32, ctx: *GameContext) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.update(dt, ctx);
    }

    // TODO: draw all scenes instead of only the top one.
    pub fn draw(self: *const Self, frame: *Frame) !void {
        const scene = self.scenes.getLastOrNull() orelse return;
        try scene.draw(frame);
    }
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
    services: *ServiceManager,

    ctx: GameContext,


    pub fn init(gpa: std.mem.Allocator, services: *ServiceManager, pipeline: Pipeline) Self {
        return .{
            .gpa = gpa,
            .clock = pipeline.ctx.clock,
            .window = pipeline.ctx.window,
            .scene_mgr = .init(gpa, services),
            .services = services,
            .pipeline = pipeline,
            .ctx = .{},
        };
    }

    /// Main loop: tick clock, update at fixed dt, render with frame + pipeline.
    pub fn run(self: *Self) !void {
        self.ctx._parent = self;
        self.scene_mgr._services = self.services;

        var frame = Frame.init(self.gpa);
        defer frame.deinit();

        while (!self.window.shouldClose()) {
            self.clock.tick();
            if (self.services.get(Mouse)) |mouse| mouse.updatePos();

            try self.scene_mgr.update(self.clock.dt(), &self.ctx);

            frame.clear();

            try self.scene_mgr.draw(&frame);
            try self.pipeline.render(&frame);
            self.window.swapBuffers();
        }
    }

    pub fn deinit(self: *Self) void {
        self.scene_mgr.deinit();
    }
};
