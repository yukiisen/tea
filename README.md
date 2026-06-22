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

- **InputMapper**: only checks the first binding per action — should OR across all bindings
- **Frame.drawSprite**: appends the original sprite instead of the duplicated textures copy
- **Model**: `load`, `loadMulti`, and `deinit` methods need `pub` visibility
- **UniformBuffer**: vec3 fields overallocate (std140 uses 12 bytes, not 16)
- **Shader**: array uniforms limited to 99 elements by `digits2`
- **Text2D**: empty placeholder, not implemented
- **Audio**: sound groups not implemented
- **Cursors**: custom cursor support missing
- **Cubemaps**: loading from a single file not implemented
- **Shaders**: precompiled shaders and hot-reloading not supported
