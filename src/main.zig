const std = @import("std");
const z = @import("zmath");
const engine = @import("engine/root.zig");

const fw = @import("framework/root.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // const MyState = struct {
    //     greet: []const u8,
    //
    //     pub fn update(self: *@This(), dt: f64) void { 
    //         _ = dt;
    //
    //
    //         std.debug.print("{s} update mom\n", .{self.greet});
    //     }
    //
    //     pub fn render(self: *@This(), f: *fw.Frame) void { 
    //         _ = f;
    //
    //         std.debug.print("{s} render mom\n", .{self.greet});
    //     }
    // };
    //
    // const state = try allocator.create(MyState);
    // state.greet = "hello";
    //
    // const gs = fw.Scene.wrap(state);
    //
    // try gs.update(4);
    // try gs.render(undefined);
    //
    // gs.deinitFn(gs.ptr, allocator);
    //
    // var scene = fw.SceneGraph.init(allocator);
    // defer scene.deinit();
    //
    // const player = try scene.createEntity("player");
    // const femboy = try scene.createEntity("femboy");
    // const tomboy = try scene.createEntity("tomboy");
    //
    // try scene.setParent(player, femboy);
    //
    // const Signed = struct {
    //     val: i8 = -6,
    // };
    //
    // const UnSigned = struct {
    //     val: u8 = 6,
    // };
    //
    // try scene.addComponent(player, Signed, .{});
    // try scene.addComponent(player, UnSigned, .{});
    //
    // try scene.addComponent(femboy, Signed, .{ .val = -1 });
    //
    // try scene.addComponent(tomboy, UnSigned, .{ .val = 20 });
    //
    // try scene.runSystem(&.{ *Signed }, struct {
    //     pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *Signed })) anyerror!void {
    //         std.debug.print("id: {d}\n", .{ id });
    //
    //         const signed = comps.@"0";
    //         std.debug.print("signed: {any}\n", .{ signed });
    //     }
    // }.f, state);
    //
    // try scene.runSystem(&.{ *UnSigned }, struct {
    //     pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *UnSigned })) anyerror!void {
    //         std.debug.print("id: {d}\n", .{ id });
    //
    //         const unsigned = comps.@"0";
    //         std.debug.print("unsigned: {any}\n", .{ unsigned });
    //     }
    // }.f, state);
    //
    // try scene.runSystem(&.{ *Signed, *UnSigned }, struct {
    //     pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *Signed, *UnSigned })) anyerror!void {
    //         std.debug.print("id: {d}\n", .{ id });
    //
    //         const signed, const unsigned = comps;
    //         std.debug.print("signed: {any}\nunsigned: {any}\n", .{ signed, unsigned });
    //     }
    // }.f, state);
    //
    // std.process.exit(0);

    var window = try engine.Window.init(800, 600, "tea");
    defer window.deinit();
    window.prepare();

    window.setWindowMode(.Borderless);

    var renderer = try engine.Renderer.init(allocator);
    defer renderer.deinit();

    var shaders = engine.ShaderManager.init(allocator, io);
    defer shaders.deinit();

    const shader = try shaders.createUntyped(.{
        .vertex = "shaders/quad.vert",
        .fragment = "shaders/quad.frag",
    });

    var camera = fw.Camera.Default2D(&window, .vec2(0, 0));
    camera.calculateMatrices();

    var mesh = try engine.Mesh.init(.circle(32));
    defer mesh.deinit();
    //
    var keyboard = engine.Keyboard.init(&window);
    var clock = engine.Clock.init();

    var pos_x: f32 = 0;
    var pos_y: f32 = 0;
    const speed = 4;

    while (!window.shouldClose()) {
        clock.tick();
        const dt = @as(f32, @floatCast(clock.dt()));

        if (keyboard.isPressed(.Left)) pos_x -= speed * dt;
        if (keyboard.isPressed(.Right)) pos_x += speed * dt;
        if (keyboard.isPressed(.Up)) pos_y += speed * dt;
        if (keyboard.isPressed(.Down)) pos_y -= speed * dt;

        if (keyboard.isPressed(.Q)) window.close();

        const model = z.mul(z.translation(pos_x, pos_y, 0), z.scaling(128, 128, 1));
        const model2 = z.mul(z.translation(-pos_x, -pos_y, 0), z.scaling(128, 128, 1));

        renderer.clearFrame(.{ 0.1, 0.1, 0.15, 1.0 });
        renderer.useShader(&shader);

        try shader.setUniform("u_view", camera.view);
        try shader.setUniform("u_proj", camera.proj);

        try shader.setUniform("u_model", model);
        try shader.setUniform("u_color", z.Vec{ 0.2, 0.7, 1.0, 1.0 });

        renderer.drawMesh(&mesh, &shader, .Triangles);

        try shader.setUniform("u_model", model2);
        try shader.setUniform("u_color", z.Vec{ 1.0, 1.0, 1.0, 1.0 } - z.Vec{ 0.2, 0.7, 1.0, 1.0 });

        renderer.drawMesh(&mesh, &shader, .Triangles);

        window.swapBuffers();
    }
}
