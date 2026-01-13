const std = @import("std");
const sekai = @import("root.zig");

const ma = @import("deps/miniaudio.zig");

const HentaiMap = struct {
    meow: u32 = 0,
    hentai: u32 = 0
};

const HentaiMap2 = struct {
    hentai: *const u32
};

pub fn main() !void { 
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.print("No leaks: {any}\n", .{gpa.deinit() == .ok});
    var allocator = gpa.allocator();

    var app = sekai.Sekai.init(&allocator);
    defer app.deinit();


    try app.addResource(HentaiMap, .{ .hentai = 2 });
    try app.addResource(HentaiMap2, .{ .hentai = &3 });
    const hentai = app.getResource(HentaiMap2).?;

    std.debug.print("hentai res = {}\n", .{ hentai.hentai.* });
    
    var n: u32 = 3;

    n += 1;

    try app.spawn(.{ HentaiMap { .hentai = n - 2, .meow = n * 11 }, HentaiMap2 { .hentai = &n } });
    try app.spawn(.{ HentaiMap { .hentai = n - 2, .meow = 55 }, HentaiMap2 { .hentai = &n } });
    try app.spawn(.{ HentaiMap { .hentai = n - 2, .meow = 23 } });
    try app.spawn(.{ HentaiMap2 { .hentai = &n } });


    var t = app.query(struct { HentaiMap2, HentaiMap });

    while (t.next()) |d| {
        const p: *HentaiMap2, const b: *HentaiMap = d;

        std.debug.print("p hentai = {any}\n", .{p.hentai.*});
        std.debug.print("b hentai = {any}\n", .{b.meow});

        b.*.meow = 2;
    }

    var it = app.query(struct { HentaiMap });

    while (it.next()) |d| {
        const p: *HentaiMap = d.@"0";
        std.debug.print("p meow = {any}\n", .{p.meow});
    }

    var audio = try sekai.engine.Audio.init(&allocator);
    defer audio.deinit();
    const sound = try audio.createSound("main", .{
        .path = "./Spring Memory.mp3",
    });

    const shader = try sekai.engine.Shader.init(&allocator, .{ .fragment = "build.zig", .vertex = "vert" });
    _ = shader;

    if (true) return;

    var win = try sekai.engine.Window.init(800, 600, "hi mom");
    defer win.deinit();
    win.setWindowMode(.Borderless);
    win.prepare();

    var render = try sekai.engine.Renderer.init();

    const keyboard = sekai.engine.Keyboard.init(&win);
    const clipboard = sekai.engine.Clipboard.init(&win);
    _ = clipboard;
    var mouse = sekai.engine.Mouse.init(&win);
    mouse.updatePos();

    const name = keyboard.getKeyName(.A);
    if (name) |nm| {
        std.debug.print("key Super = {s}\n", .{ nm });
    }

    
    while (!win.shouldClose()) {
        if (keyboard.isPressed(.Q)) win.close();
        if (keyboard.isPressed(.P)) sound.pause();
        if (keyboard.isPressed(.O)) sound.play();
        // if (mouse.pos_changed) std.debug.print("mouse pos = {any}\n", .{ .{ mouse.xpos, mouse.ypos } });
        // if (mouse.isPressed(.ButtonLeft)) std.debug.print("Mouse pressed!\n", .{});

        // const data = clipboard.getString();
        // if (data) |d| {
        //     std.debug.print("clipboard = {s}\n", .{ d });
        // }

        render.clearFrame(.{ 0.05, 0.05, 0.05, 1.0 });
        win.swapBuffers();
        mouse.updatePos();
    }
}
