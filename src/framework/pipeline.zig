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
    camera: *const Camera,
};

/// Type-erased pipeline.
pub const Pipeline = struct {
    const Self = @This();

    ptr: *anyopaque,
    ctx: RenderContext,
    renderFn: *const fn(*anyopaque, *const Frame, RenderContext) anyerror!void,
    deinitFn: *const fn(*anyopaque, std.mem.Allocator) void,

    pub fn init(ptr: anytype, ctx: RenderContext) Self {
        const child = std.meta.Child(@TypeOf(ptr));

        if (!@hasDecl(child, "render")) @compileError("Type " ++ @typeName(child) ++ " doesn't have a .render() method.");

        return .{
            .ptr = @ptrCast(@alignCast(ptr)),
            .ctx = ctx,
            .renderFn = struct {
                fn f(p: *anyopaque, frame: *const Frame, renderCtx: RenderContext) anyerror!void {
                    if (@hasDecl(child, "clear")) renderCtx.renderer.clearFrame(child.clear.value);
                    return @call(.auto, child.render, .{ @as(*child, @ptrCast(@alignCast(p))), frame, renderCtx });
                }
            }.f,
            .deinitFn = struct {
                fn f(p: *anyopaque, gpa: std.mem.Allocator) void {
                    const instance: *child = @ptrCast(@alignCast(p));
                    if (@hasDecl(child, "deinit")) instance.deinit();
                    gpa.destroy(instance);
                }
            }.f,
        };
    }

    pub fn deinit(self: Self, gpa: std.mem.Allocator) void {
        self.deinitFn(self.ptr, gpa);
    }

    pub fn render(self: Self, frame: *const Frame) !void {
        try self.renderFn(self.ptr, frame, self.ctx);
    }
};

pub const DefaultPipeline = struct {
    const Self = @This();

    const clear: Vec = .vec(0);

    pub const TextUniform = struct {
        u_model: zm.Mat,
        u_view: zm.Mat,
        u_proj: zm.Mat,
        u_pxRange: f32,
        u_atlas: i32,
        u_color: zm.Vec,
    };

    quad: engine.Mesh,
    shader_mgr: *engine.ShaderManager,

    pub fn render(self: *Self, frame: *const Frame, ctx: RenderContext) !void {
        for (frame.sprites.items) |sprite| {
            const shader = self.shader_mgr.get("general").?;

            ctx.renderer.useShader(&shader);
            sprite.texture.bind(0);

            try shader.setUniform("u_texture", 0);
            try shader.setUniform("u_proj", ctx.camera.proj);
            try shader.setUniform("u_view", ctx.camera.view);
            try shader.setUniform("u_model", 
                zm.mul(
                    zm.scalingV(sprite.size.value), 
                    zm.translationV(sprite.position.value + zm.f32x4(0, 0, @floatFromInt(sprite.layer), 0))
                )
            );

            ctx.renderer.drawMesh(self.quad, shader, .Triangles);
        }

        for (frame.text.items) |pair| {
            const text , const model = pair;
            const shader = self.shader_mgr.get("text").?;

            ctx.renderer.useShader(&shader);
            text.font.texture.bind(0);

            const uniforms = shader.uniformPtr(TextUniform);
            uniforms.u_atlas = 0;
            uniforms.u_color = text.getColor();
            uniforms.u_pxRange = 2.0;
            uniforms.u_model = zm.mul(zm.translation(-ctx.window.width / 2, -(ctx.window.height / 2), 0), model);
            uniforms.u_view = ctx.camera.view;
            uniforms.u_proj = ctx.camera.proj;

            try shader.updateUniforms(TextUniform);

            ctx.renderer.drawMesh(text.asMesh(), shader, .Triangles);
        }
    }
};
