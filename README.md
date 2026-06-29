# tea

A work-in-progress game engine and framework in Zig.

This project is still in early stages. The ECS(?) needs improvement, 2D features beyond sprites are missing, and model loading is unimplemented.

## Dependencies

**System:**
- [GLFW](https://www.glfw.org/) — windowing and input

**Zig packages** (local paths in `build.zig.zon` change them accordingly):
- [zmath](https://github.com/zig-gamedev/zmath) — SIMD linear algebra
- [zopengl](https://github.com/zig-gamedev/zopengl) — OpenGL bindings (core 4.2)
- [zstbi](https://github.com/zig-gamedev/zstbi) — image loading (PNG/JPG)

**Bundled:**
- [stb_vorbis](https://github.com/nothings/stb) via [miniaudio.h](include/miniaudio.h) — audio playback


## Engine vs Framework

The **engine** layer (`src/engine/`) owns all GPU/audio/input state. Each module wraps a single concern (OpenGL, GLFW, miniaudio) and is framework-agnostic — you can use it standalone.

The **framework** layer (`src/framework/`) provides opinionated game patterns on top of the engine:
- A **Scene** stack with lifecycle hooks (`load` / `update` / `draw` / `exit`)
- A **ServiceManager** for dependency injection (services are registered by type, injected into scenes automatically)
- A type-erased **Pipeline** (implement a struct with `render()`, wrap it with `Pipeline.init()`)
- A **DefaultPipeline** for 2D sprite + text rendering out of the box
- A hierarchical **SceneGraph** ECS with component-based queries
- A **Camera** system (orthographic for 2D, perspective for 3D)
- An **InputMapper** for named actions with `justPressed`/`pressed`/`justReleased` edge detection

## Minimal example

```zig
const fw = @import("framework/root.zig");
const en = @import("engine/root.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const win = try en.Window.init(800, 600, "tea");
    const ren = try en.Renderer.init(gpa);

    var services = fw.ServiceManager.init(gpa);
    defer services.deinit();
    try services.register(win);
    try services.register(ren);

    const clock = en.Clock.init();
    var camera = fw.Camera.init2D(win, .origin);
    var shaderMgr = en.ShaderManager.init(gpa, init.io);

    // ... create pipeline, register scene, run gameloop ...
}
```

Scenes declare dependencies via a `resolved` struct — services are injected before `load()`:

```zig
const MyScene = struct {
    resolved: struct { kb: *en.Keyboard, window: *en.Window } = undefined,
    // ...
    pub fn update(self: *Self, dt: f32, ctx: *fw.GameContext) !void {
        if (self.resolved.kb.isPressed(.Q)) ctx.quit();
    }
    pub fn draw(self: *Self, frame: *fw.Frame) !void {
        try frame.drawSprite(.{ .texture = ..., .position = .vec2(100, 100), .size = .vec2(64, 64) });
    }
};
```

## TODO

- [ ] External model loading.
- [x] Controller support.
- [x] Vsync support.
- [x] Text rendering.
- [x] Default render pipeline.
- [ ] Implement Sound groups.
- [ ] Improve the SceneGraph implementation.
- [ ] Some 2D features (Animations, Collisions, Particles)
- [ ] Cubemap loading from a single file.
- [ ] Precompiled shaders and hot-reloading.
- [ ] Add more tests.
- [ ] Support custom cursors.
- [ ] Render buffer type selection.
- [x] Proper error handling for window creation.
- [ ] Improve code quality.
