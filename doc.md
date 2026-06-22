# Architecture

The project is split into two layers: **engine** and **framework**.

## Engine (`src/engine/`)

Thin wrappers around OpenGL, GLFW and miniaudio. Each module owns a single concern.

| Module | Responsibility |
|---|---|
| `renderer.zig` | Window creation, OpenGL init, draw commands, framebuffer management |
| `shader.zig` | Shader compilation, uniform reflection and upload |
| `components.zig` | Mesh (VAO/VBO/EBO), Vertex, Transform, MeshConfig presets |
| `assets.zig` | Texture2D / CubeTexture loading via zstbi, AssetManager |
| `framebuffer.zig` | Framebuffer and RenderBuffer objects |
| `uniformbuffer.zig` | UBO with std140 layout computed at comptime |
| `input.zig` | Mouse, Keyboard, Clipboard, Clock — all thin GLFW wrappers |
| `audio.zig` | Sound loading/playback via miniaudio |

## Framework (`src/framework/`)

Higher-level opinionated game abstractions built on the engine.

| Module | Responsibility |
|---|---|
| `gameloop.zig` | Scene manager, GameContext, fixed-timestep GameLoop |
| `scene.zig` | Type-erased Scene with optional enter/exit/update/render/deinit |
| `ecs.zig` | Hierarchical Entity-Component system (SceneGraph) |
| `camera.zig` | 2D/3D camera with orthographic and perspective projections |
| `pipeline.zig` | Type-erased render pipeline with ordered passes |
| `frame.zig` | Per-frame draw call collector (sprites, models) |
| `input.zig` | InputMapper — named actions with edge detection |
| `model.zig` | Mesh container for multi-mesh models |
| `utils.zig` | Vec wrapper, Pair type helper |

## Usage flow

```
GameLoop.init()
  -> SceneManager manages Scene stack
     -> each Scene gets enter()/update()/render()/exit()
        -> render() populates Frame with draw calls
           -> Pipeline.execute() processes the Frame
```

Input is handled via `InputMapper` — register named actions with bindings, then query `.justPressed` / `.pressed` / `.justReleased` in your update logic.
