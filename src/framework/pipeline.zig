const std = @import("std");
const engine = @import("../engine/root.zig");

const zm = @import("zmath");
const Frame = @import("frame.zig").Frame;

const Window = engine.Window;
const Renderer = engine.Renderer;
const Clock = engine.Clock;
const FrameBuffer = engine.FrameBuffer;
const Vec = @import("utils.zig").Vec;

const Camera = @import("camera.zig").Camera;

/// Plumbing shared by every render pass.
pub const RenderContext = struct {
    window: *Window,
    renderer: *Renderer,
    clock: *Clock,
    camera: *Camera,
};

/// Type-erased pipeline: wraps any concrete RenderPipeline(T) for storage in GameLoop.
pub const Pipeline = struct {
    const Self = @This();

    ptr: *anyopaque,
    ctx: RenderContext,
    execFn: *const fn(*anyopaque, *const Frame, RenderContext) anyerror!void,
    deinitFn: *const fn(*anyopaque) void,

    pub fn deinit(self: Self) void {
        self.deinitFn(self.ptr);
    }

    pub fn execute(self: Self, frame: *const Frame) !void {
        try self.execFn(self.ptr, frame, self.ctx);
    }

    pub fn singular(ctx: RenderContext, handler: *const fn(RenderContext, *const Frame) anyerror!void) Self {
        return .{
            .ptr = undefined,
            .ctx = ctx,
            .execFn = struct {
                fn f(_: *anyopaque, frame: *const Frame, r_ctx: RenderContext) anyerror!void {
                    return handler(r_ctx, frame);
                }
            }.f,
            .deinitFn = struct { fn d(_: *anyopaque) void {} }.d,
        };
    }
};

/// Generic render pipeline with ordered passes and a user-defined context T.
/// Call GetPipeline() to obtain a type-erased Pipeline for the game loop.
pub fn RenderPipeline(comptime T: type) type {
    return struct {
        const Self = @This();

        const RenderFn = *const fn (RenderContext, *const Frame, *T) anyerror!void;

        pub const RenderPass = struct {
            exec: RenderFn,
            framebuffer: ?FrameBuffer = null,
            camera: ?Camera = null,
            clear: ?Vec = null,
        };

        pub const PassBuilder = struct {
            pass: RenderPass,

            pub fn from(handler: RenderFn) @This() {
                return .{ 
                    .pass = .{ .exec = handler }
                };
            }

            pub fn camera(self: *@This(), cam: Camera) *@This() {
                self.pass.camera = cam;
                return self;
            }

            pub fn clear(self: *@This(), color: Vec) *@This() {
                self.pass.clear = color;
                return self;
            }

            pub fn framebuffer(self: *@This(), fb: FrameBuffer) *@This() {
                self.pass.framebuffer = fb;
                return self;
            }

            pub fn build(self: @This()) RenderPass {
                return self.pass;
            }
        };

        allocator: std.mem.Allocator,
        passes: std.ArrayList(RenderPass),
        renderCtx: RenderContext,
        userCtx: *T,

        pub fn init(gpa: std.mem.Allocator, ctx: RenderContext) !Self {
            const userCtx = try gpa.create(T);

            return .{
                .allocator = gpa,
                .passes = .empty,
                .renderCtx = ctx,
                .userCtx = userCtx,
            };
        }

        pub fn addRenderPass(self: *Self, pass: PassBuilder) !void {
            try self.passes.append(self.allocator, pass.build());
        }

        pub fn deinit(self: Self) void {
            self.passes.deinit(self.allocator);
            self.allocator.destroy(self.userCtx);
        }

        pub fn execute(self: Self, f: *const Frame, ctx: RenderContext) !void {
            for (self.passes.items) |pass| {
                if (pass.framebuffer) |fb| fb.bind();
                if (pass.clear) |color| ctx.renderer.clearFrame(color.value);

                var backupCamera: ?*Camera = null;
                if (pass.camera) {
                    backupCamera = ctx.camera;
                    ctx.camera = &pass.camera;
                }

                try pass.exec(ctx, f, self.userCtx);

                if (backupCamera) |cam| ctx.camera = cam;
            }
        }

        /// Erases type so it can be stored as Pipeline.
        pub fn pipeline(self: *Self) Pipeline {
            return .{
                .ptr = self,
                .ctx = self.renderCtx,
                .execFn = struct {
                    pub fn f(ptr: *anyopaque, frame: *const Frame, ctx: RenderContext) !void {
                        const instance: *Self = @ptrCast(@alignCast(ptr));
                        instance.execute(frame, ctx);
                    }
                }.f,
                .deinitFn = struct {
                    pub fn f(ptr: *anyopaque) void {
                        const instance: *Self = @ptrCast(@alignCast(ptr));
                        instance.deinit();
                    }
                }.f,
            };
        }
    };
}
