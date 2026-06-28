# Architecture

Two layers: **engine** and **framework**.

## Engine (`src/engine/`)

Thin wrappers around OpenGL, GLFW, and miniaudio.

| Module | Responsibility |
|---|---|
| `renderer.zig` | Window creation, OpenGL init, draw commands, framebuffer management |
| `shader.zig` | Shader compilation, uniform reflection and upload, ShaderManager |
| `mesh.zig` | Mesh (VAO/VBO/EBO), Vertex, MeshConfig presets (quad/cube/circle) |
| `assets.zig` | Texture2D / CubeTexture loading via zstbi, AssetManager |
| `font.zig` | FontAtlas (MSDF JSON parser), Text2D (dynamic text mesh generation) |
| `framebuffer.zig` | Framebuffer and RenderBuffer objects |
| `uniformbuffer.zig` | UBO with std140 layout computed at comptime |
| `input.zig` | Mouse, Keyboard, Clipboard, Clock, Joystick, Gamepad — all thin GLFW wrappers |
| `audio.zig` | Sound loading/playback via miniaudio |
| `utils.zig` | `glError` helper, `loadFile` utility |

## Framework (`src/framework/`)

Higher-level opinionated game abstractions built on the engine.

| Module | Responsibility |
|---|---|
| `gameloop.zig` | Scene (type-erased wrapper), SceneManager (stack), GameLoop, GameContext |
| `pipeline.zig` | Pipeline (type-erased wrapper), DefaultPipeline (2D), RenderContext |
| `frame.zig` | Per-frame draw call collector (sprites, text, models) |
| `camera.zig` | 2D/3D camera with orthographic and perspective projections |
| `ecs.zig` | Hierarchical Entity-Component system (SceneGraph) |
| `services.zig` | ServiceManager — type-erased DI container with Wyhash type IDs |
| `input.zig` | InputMapper — named actions with edge detection |
| `model.zig` | Mesh container for multi-mesh models |
| `utils.zig` | Vec wrapper (.vec2 / .vec3 / .vec4 helpers) |

## Dependency injection

Services are registered by type in `ServiceManager`. Scenes that need them declare a `resolved` struct:

```zig
const MyScene = struct {
    resolved: struct { kb: *en.Keyboard, window: *en.Window } = .{},
    // ...
};
```

Before `load()` is called, `SceneManager` iterates the fields of `resolved`, looks up each type in the service registry, and writes the pointer. This replaces the old monolithic `GameContext`.

## Usage flow

```txt
GameLoop.init()
  -> SceneManager manages Scene stack
     -> each Scene gets load() / update() / draw() / exit()
        -> update() advances game logic
        -> draw() populates Frame with draw calls
           -> Pipeline.render() processes the Frame
```

Input is handled via `InputMapper` — register named actions with bindings, then query `.justPressed` / `.pressed` / `.justReleased` in your update logic.

## Pipeline

Instead of a generic `RenderPipeline(T)`, the project now uses a type-erased `Pipeline.init(ptr, ctx)`. Any struct with a `render(self, *const Frame, RenderContext)` method can be wrapped. `DefaultPipeline` is the built-in 2D implementation — it draws sprites and MSDF text using a camera-based view/projection.

---

This project is still in early stages. The ECS needs improvement, 2D features beyond sprites are missing, and model loading is unimplemented.
