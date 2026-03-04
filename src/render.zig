const std = @import("std");
const e = @import("engine/root.zig");

/// sets up essential systems for creating a render pipeline.
/// *Assumes* that a window and a renderer have already been created.
pub fn initRenderPipeline (app: *e.Sekai) !void {
    try app.addSystem(render, .Render);
}

pub fn initFramebuffers (app: *e.Sekai) void {
    const renderer = app.getResource(e.Renderer).?;

    // we use this framebuffer to draw lower resolution output.
    _ = renderer.createFramebuffer(.{ 1440, 900 }) catch @panic("fuck we can't create fb.");
}

pub fn render (app: *e.Sekai) void {
    const window = app.getResource(e.Window).?;
    const renderer = app.getResource(e.Renderer).?;
    const mouse = app.getResource(e.Mouse).?;

    window.useFrameBuffer();
    renderer.clearFrame(.{ 0, 0, 0, 1.0 });
    window.swapBuffers();
    mouse.updatePos();
}
