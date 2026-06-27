const std = @import("std");
const fw = @import("framework/root.zig");
const en = @import("engine/root.zig");
const zm = @import("zmath");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var window = try en.Window.init(800, 600, "hentai communism");
    defer window.deinit();
    window.prepare();

    window.setWindowMode(.Windowed);

    var renderer = try en.Renderer.init(gpa);
    defer renderer.deinit();

    var clock = en.Clock.init();

    var camera = fw.Camera.init2D(&window, .origin);

    var assetMgr = en.AssetManager.init(gpa, io);
    defer assetMgr.deinit();

    try assetMgr.loadTexture("miku", "miku.jpg", false);
    try assetMgr.loadTexture("amine", "amine.jpg", false);

    const miku = assetMgr.textures.get("miku").?;
    const amine = assetMgr.textures.get("amine").?;

    var shaderMgr = en.ShaderManager.init(gpa, io);
    defer shaderMgr.deinit();

    var font = try en.FontAtlas.init(gpa, io, "fonts/font.json", "fonts/font.png");
    defer font.deinit();

    var text = try en.Text2D.init(gpa, &font);
    defer text.deinit();


    _ = try shaderMgr.createTagged(struct {}, "general", .{
        .vertex = "shaders/quad.vert.glsl",
        .fragment = "shaders/quad.frag.glsl",
    });

    _ = try shaderMgr.createTagged(fw.DefaultPipeline.TextUniform, "text", .{
        .vertex = "shaders/text.vert.glsl",
        .fragment = "shaders/text.frag.glsl",
    });
    
    const quad = try en.Mesh.init(.quad);

    const renderCtx = fw.RenderContext {
        .window = &window, .renderer = &renderer, .camera = &camera, .clock = &clock,
    };

    var rp: fw.DefaultPipeline = .{
        .quad = quad,
        .shader_mgr = &shaderMgr,
    };

    const pipeline = fw.Pipeline.init(&rp, renderCtx);

    var frame = fw.Frame.init(gpa);
    defer frame.deinit();

    text.color = 0xFFFFFFFF;

    while (!window.shouldClose()) {
        clock.tick();
        const dt = clock.dt();
        frame.clear();

        try text.print("Brr bim batabim!!! - {d:.0}FPS - pixel is a femboy", .{1/dt});
        try text.flush();

        try frame.drawText(text, .vec3((window.width - text.width) / 2, window.height - text.height * 3, 2));

        const n = 1;
        const d: f32 = 1;
        const div: u32 = 2;

        for (0..n) |idx| {
            const i: f32 = @floatFromInt(idx);

            try frame.drawSprite(.{
                .texture = amine,
                .position = .vec2(200 + d * i, -d * i),
                .size = .vec2(@floatFromInt(amine.meta.width / div), @floatFromInt(amine.meta.height / div)),
            });

            try frame.drawSprite(.{
                .texture = miku,
                .position = .vec2(-200 + d * i, -d * i),
                .size = .vec2(@floatFromInt(miku.meta.width / div), @floatFromInt(miku.meta.height / div)),
            });
        } 

        try pipeline.render(&frame);
        window.swapBuffers();
        camera.setBounds(&window);
    }
}
