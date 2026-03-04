const std = @import("std");
const engine = @import("engine/root.zig");

const Sekai = engine.Sekai;
const Window = engine.Window;
const Keyboard = engine.Keyboard;
const Mouse = engine.Mouse;
const Renderer = engine.Renderer;
const AssetManager = engine.AssetManager;

/// create essential render resources for general usage.
pub fn createResources(app: *Sekai) void {
    const _window = Window.init(800, 600, "Minia") catch @panic("Fuck Can't create window!!!");
    const renderer = Renderer.init(app.allocator) catch @panic("Fuck can't create renderer!!!");

    app.addResource(Window, _window) catch @panic("fuck can't allocate mem");
    app.addResource(Renderer, renderer) catch @panic("fuck can't allocate mem");

    // we get the window again since we need to give it a constant pointer.
    const window = app.getResource(Window).?;
    window.setWindowMode(.Borderless);
    window.prepare();

    const keyboard = Keyboard.init(window);
    app.addResource(Keyboard, keyboard) catch @panic("fuck can't allocate mem");

    const mouse = Mouse.init(window);
    app.addResource(Mouse, mouse) catch @panic("fuck can't allocate mem");

    const io = std.Io.Threaded.global_single_threaded.io();

    const assetManager = AssetManager.init(app.allocator, io);
    app.addResource(AssetManager, assetManager) catch @panic("Fuck we couldn't allocate mem!");
}

/// free resources created by `createResources`.
pub fn destroyResources(app: *Sekai) void {
    const window = app.getResource(Window).?;
    const renderer = app.getResource(Renderer).?;

    renderer.deinit();
    window.deinit();
}
