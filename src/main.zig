const std = @import("std");
const z = @import("zmath");
const engine = @import("engine/root.zig");

const FontAtlas = @import("engine/font.zig").FontAtlas;
const Text2D = @import("engine/font.zig").Text2D;

const fw = @import("framework/root.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const MyState = struct {
        greet: []const u8,

        pub fn update(self: *@This(), dt: f64, ctx: *fw.GameContext) void { 
            _ = dt;
            _ = ctx;

            std.debug.print("{s} update mom\n", .{self.greet});
        }

        pub fn render(self: *@This(), f: *fw.Frame) void { 
            _ = f;

            std.debug.print("{s} render mom\n", .{self.greet});
        }

        pub fn deinit(self: *@This()) void {
            _ = self;

            std.debug.print("it is the end of mine!!\n", .{});
        }
    };

    const state = try allocator.create(MyState);
    defer allocator.destroy(state);
    state.greet = "hello";

    const gs = fw.Scene.wrap(state);
    defer gs.deinit();

    try gs.update(4, undefined);
    try gs.render(undefined);
    try gs.load(undefined);

    //
    var scene = fw.SceneGraph.init(allocator);
    defer scene.deinit();

    const player = try scene.createEntity("player");
    const femboy = try scene.createEntity("femboy");
    const tomboy = try scene.createEntity("tomboy");

    try scene.setParent(player, femboy);

    const Signed = struct {
        val: i8 = -6,
    };

    const UnSigned = struct {
        val: u8 = 6,
    };

    try scene.addComponent(player, Signed, .{});
    try scene.addComponent(player, UnSigned, .{});

    try scene.addComponent(femboy, Signed, .{ .val = -1 });

    try scene.addComponent(tomboy, UnSigned, .{ .val = 20 });

    try scene.runSystem(&.{ *Signed }, struct {
        pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *Signed })) anyerror!void {
            std.debug.print("id: {d}\n", .{ id });

            const signed = comps.@"0";
            std.debug.print("signed: {any}\n", .{ signed });
        }
    }.f, undefined);

    try scene.runSystem(&.{ *UnSigned }, struct {
        pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *UnSigned })) anyerror!void {
            std.debug.print("id: {d}\n", .{ id });

            const unsigned = comps.@"0";
            std.debug.print("unsigned: {any}\n", .{ unsigned });
        }
    }.f, undefined);

    try scene.runSystem(&.{ *Signed, *UnSigned }, struct {
        pub fn f(_: *anyopaque, id: u32, comps: @Tuple(&.{ *Signed, *UnSigned })) anyerror!void {
            std.debug.print("id: {d}\n", .{ id });

            const signed, const unsigned = comps;
            std.debug.print("signed: {any}\nunsigned: {any}\n", .{ signed, unsigned });
        }
    }.f, undefined);

    var window = try engine.Window.init(800, 600, "tea");
    defer window.deinit();
    window.prepare();

    window.setWindowMode(.Borderless);
    window.setVSync(false);

    var renderer = try engine.Renderer.init(allocator);
    defer renderer.deinit();

    var font = try FontAtlas.init(allocator, io, "fonts/font.json", "fonts/font.png");
    defer font.deinit();
    defer @import("zstbi").deinit();

    var text = try Text2D.init(allocator, &font);
    defer text.deinit();

    var shaders = engine.ShaderManager.init(allocator, io);
    defer shaders.deinit();

    const shader = try shaders.createUntyped(.{
        .vertex = "shaders/quad.vert.glsl",
        .fragment = "shaders/quad.frag.glsl",
    });

    const textShader = try shaders.createUntyped(.{
        .vertex = "shaders/text.vert.glsl",
        .fragment = "shaders/text.frag.glsl",
    });

    var camera = fw.Camera.Default2D(&window, .vec2(200, 0));
    camera.calculateMatrices();

    var mesh = try engine.Mesh.init(.circle(32));
    defer mesh.deinit();

    var mesh2 = try engine.Mesh.init(.circle(5));
    defer mesh2.deinit();

    var keyboard = engine.Keyboard.init(&window);
    var clock = engine.Clock.init();

    var joystick = try engine.Joystick.init(.Joystick3);
    std.debug.print("Detected Joystick {s}\n", .{ joystick.name });
    var gamepad = try engine.Gamepad.init(&joystick);
    std.debug.print("Detected Gamepad {s}\n", .{ gamepad.name });

    var pos_x: f32 = 0;
    var pos_y: f32 = 0;
    const speed = 4;

    while (!window.shouldClose()) {
        clock.tick();
        try gamepad.update();
        const dt = @as(f32, @floatCast(clock.dt()));

        try text.print("{d:.0}FPS", .{1/dt});
        try text.flush();

        if (keyboard.isPressed(.Left) or gamepad.isPressed(.DpadLeft)) pos_x -= speed * dt
        else if (keyboard.isPressed(.Right) or gamepad.isPressed(.DpadRight)) pos_x += speed * dt
        else if (keyboard.isPressed(.Up) or gamepad.isPressed(.DpadUp)) pos_y += speed * dt
        else if (keyboard.isPressed(.Down) or gamepad.isPressed(.DpadDown)) pos_y -= speed * dt
        else {
            pos_x += gamepad.getAxis(.RightX) * speed * dt;
            pos_y -= gamepad.getAxis(.RightY) * speed * dt;
        }

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
        try shader.setUniform("u_color", z.Vec{ 1.0, 1.0, 1.0, 2.0 } - z.Vec{ 0.2, 0.7, 1.0, 1.0 });

        renderer.drawMesh(&mesh2, &shader, .Triangles);

        renderer.useShader(&textShader);

        try textShader.setUniform("u_view", camera.view);
        try textShader.setUniform("u_proj", camera.proj);
        try textShader.setUniform("u_color", text.getColor());
        try textShader.setUniform("u_pxRange", 2.0);

        text.font.texture.bind(0);
        try textShader.setUniform("u_atlas", 0);

        text.color = 0xFFFFFFFF;
        renderer.drawMesh(&text.asMesh(), &textShader, .Triangles);

        window.swapBuffers();
    }
}
