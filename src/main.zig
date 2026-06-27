const std = @import("std");
const fw = @import("framework/root.zig");
const en = @import("engine/root.zig");
const zm = @import("zmath");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const win = try en.Window.init(800, 600, "hentai communism");
    const ren = try en.Renderer.init(gpa);

    var services = fw.ServiceManager.init(gpa);
    defer services.deinit();

    try services.register(win);
    try services.register(ren);

    const window = services.get(en.Window).?;
    window.prepare();
    window.setWindowMode(.Borderless);

    const kb = en.Keyboard.init(window);
    try services.register(kb);

    const renderer = services.get(en.Renderer).?;
    var clock = en.Clock.init();
    var camera = fw.Camera.init2D(window, .origin);

    var assets = en.AssetManager.init(gpa, io);
    defer assets.deinit();

    var font = try en.FontAtlas.init(gpa, io, "fonts/font.json", "fonts/font.png");
    defer font.deinit();

    var shaderMgr = en.ShaderManager.init(gpa, io);
    defer shaderMgr.deinit();

    _ = try shaderMgr.createTagged(struct {}, "general", .{
        .vertex = "shaders/quad.vert.glsl",
        .fragment = "shaders/quad.frag.glsl",
    });

    _ = try shaderMgr.createTagged(fw.DefaultPipeline.TextUniform, "text", .{
        .vertex = "shaders/text.vert.glsl",
        .fragment = "shaders/text.frag.glsl",
    });
    
    const quad = try en.Mesh.init(.quad);
    defer quad.deinit();

    const renderCtx = fw.RenderContext {
        .window = window, .renderer = renderer, .camera = &camera, .clock = &clock,
    };

    var rp: fw.DefaultPipeline = .{
        .quad = quad,
        .shader_mgr = &shaderMgr,
    };

    const pipeline = fw.Pipeline.init(&rp, renderCtx);

    var gameloop = fw.GameLoop.init(gpa, &services, pipeline);
    defer gameloop.deinit();

    var scene = try Main.init(gpa, &font, &assets);
    try gameloop.scene_mgr.push(.wrap(&scene));

    try gameloop.run();
}

const Main = struct {
    const Self = @This();
    
    resolved: struct {
        assets: *en.AssetManager,
        kb: *en.Keyboard,
        window: *en.Window,
    } = undefined,

    text: en.Text2D,
    assets: *en.AssetManager,

    pub fn init(gpa: std.mem.Allocator, font: *en.FontAtlas, assets: *en.AssetManager) !Self {
        return .{
            .text = try en.Text2D.init(gpa, font),
            .assets = assets,
        };
    }

    pub fn load(self: *Self) !void {
        try self.assets.loadTexture("miku", "miku.jpg", false);
        try self.assets.loadTexture("amine", "amine.jpg", false);

        self.text.color = 0xFFFFFFFF;
    }

    pub fn update(self: *Self, dt: f32, ctx: *fw.GameContext) !void {
        try self.text.print("Brr bim batabim!!! - {d:.0}FPS - pixel is a femboy", .{1/dt});
        try self.text.flush();

        if (self.resolved.kb.isPressed(.Q)) ctx.quit();
    }

    pub fn draw(self: *Self, frame: *fw.Frame) !void { 
        const amine = self.assets.textures.get("amine").?;
        const miku = self.assets.textures.get("miku").?;

        try frame.drawText(self.text, .vec3((self.resolved.window.width - self.text.width) / 2, self.resolved.window.height - self.text.height * 3, 2));

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
    }

    pub fn deinit(self: *Self) void {
        self.text.deinit();
    }
};
