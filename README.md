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
