# tea

A work-in-progress game engine and framework in Zig.

## Quick start

```bash
zig build run
```

Opens a borderless window with sprite and MSDF text rendering.

## Dependencies

**System:**
- [GLFW](https://www.glfw.org/) — windowing and input

**Zig packages** (local paths in `build.zig.zon`):
- [zmath](https://github.com/zig-gamedev/zmath) — SIMD linear algebra
- [zopengl](https://github.com/ziglibs/zopengl) — OpenGL bindings (core 4.2)
- [zstbi](https://github.com/ziglibs/zstbi) — image loading (PNG/JPG)

**Bundled:**
- [stb_vorbis](https://github.com/nothings/stb) via [miniaudio.h](include/miniaudio.h) — audio playback

## Project structure

```
src/
├── main.zig                  Entry point (example 2D app)
├── engine/                   Low-level GPU/audio/input abstractions
│   ├── root.zig              Public re-exports
│   ├── renderer.zig          Window (GLFW), Renderer (OpenGL), DrawMode
│   ├── shader.zig            Shader compilation, uniform reflection, ShaderManager
│   ├── mesh.zig              Mesh (VAO/VBO/EBO), Vertex, MeshConfig (quad/cube/circle)
│   ├── assets.zig            Texture2D, CubeTexture, AssetManager
│   ├── font.zig              FontAtlas (MSDF JSON), Text2D (dynamic text)
│   ├── framebuffer.zig       FrameBuffer, RenderBuffer
│   ├── uniformbuffer.zig     UBO (std140 comptime aligned)
│   ├── input.zig             Mouse, Keyboard, Clock, Joystick, Gamepad, Clipboard
│   ├── audio.zig             Audio (miniaudio engine), Sound, SoundConfig
│   ├── utils.zig             glError helper, loadFile
│   └── deps/                 C imports (glfw3.zig, miniaudio.zig)
├── framework/                Higher-level opinionated game framework
│   ├── root.zig              Public re-exports
│   ├── gameloop.zig          Scene, SceneManager, GameLoop, GameContext
│   ├── pipeline.zig          Pipeline (type-erased), DefaultPipeline, RenderContext
│   ├── frame.zig             Frame (draw-call collector), Sprite, SpriteFlip
│   ├── camera.zig            Camera (2D/3D), CameraProjection
│   ├── ecs.zig               SceneGraph (hierarchical ECS)
│   ├── services.zig          ServiceManager (type-erased DI container)
│   ├── input.zig             InputMapper (named actions with edge detection)
│   ├── model.zig             Model (multi-mesh container)
│   └── utils.zig             Vec wrapper (.vec2/.vec3/.vec4 helpers)
shaders/
├── quad.vert.glsl            Sprite/quad vertex shader
├── quad.frag.glsl            Sprite/quad fragment shader (textured)
├── text.vert.glsl            MSDF text vertex shader
└── text.frag.glsl            MSDF text fragment shader (multi-channel SDF)
```

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
    resolved: struct { kb: *en.Keyboard, window: *en.Window } = .{},
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
