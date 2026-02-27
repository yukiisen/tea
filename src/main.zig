const std = @import("std");
const engine = @import("engine/root.zig");

const createResources = @import("resources.zig").createResources;
const destroyResources = @import("resources.zig").destroyResources;

const initRenderPipeline = @import("render.zig").initRenderPipeline;

const Sekai = engine.Sekai;
const KeyBoard = engine.Keyboard;

fn stopOnQ (app: *Sekai) void  {
    const kb = app.getResource(KeyBoard).?;
    if (kb.isPressed(.Q)) app.running = false;

    const mouse = app.getResource(engine.Mouse).?;
    if (mouse.pos_changed) std.debug.print("cursor: {d} {d}\n", .{ mouse.xpos, mouse.ypos });
}

pub fn main(init: std.process.Init) !void { 
    const allocator = init.gpa;

    var app = Sekai.init(allocator);
    defer app.deinit();

    try app.addSystem(createResources, .Setup);
    try app.addSystem(destroyResources, .Destroy);
    try app.addSystem(stopOnQ, .Update);
    try initRenderPipeline(&app);

    app.run();
}
