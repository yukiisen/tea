# tea

A work-in-progress game engine and framework in Zig.

## Build

```
zig build
```

Requires [glfw](https://www.glfw.org/) as a system library.

## Dependencies

- [zmath](https://github.com/zig-gamedev/zmath) — linear algebra
- [zopengl](https://github.com/ziglibs/zopengl) — OpenGL bindings
- [zstbi](https://github.com/ziglibs/zstbi) — image loading

## Structure

```
src/engine/     low-level GPU/audio/input abstractions
src/framework/  high-level game framework (ECS, camera, pipeline)
shaders/        GLSL shaders
```

## TODO

- [ ] sound groups (Audio)
- [ ] custom cursors (Mouse)
- [ ] cubemap loading from a single file (AssetManager)
- [ ] precompiled shaders and hot-reloading (ShaderManager)
- [ ] render buffer type selection (FrameBuffer)
- [ ] proper error handling for window creation (Window)
- [ ] safe user-pointer registration (Window.prepare)
- [ ] Text2D rendering
