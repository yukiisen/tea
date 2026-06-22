// Public API surface of the framework. Import via `@import("framework/root.zig")`.

pub const GameLoop = @import("gameloop.zig").GameLoop;
pub const Scene = @import("gameloop.zig").Scene;
pub const SceneManager = @import("gameloop.zig").SceneManager;
pub const GameContext = @import("gameloop.zig").GameContext;

pub const Camera = @import("camera.zig").Camera;
pub const CameraProjection = @import("camera.zig").CameraProjection;

pub const SceneGraph = @import("ecs.zig").SceneGraph;
pub const Entity = @import("ecs.zig").Entity;
pub const Component = @import("ecs.zig").Component;
pub const ComponentId = @import("ecs.zig").ComponentType;
pub const EntityId = @import("ecs.zig").EntityId;

pub const RenderPipeline = @import("pipeline.zig").RenderPipeline;
pub const Pipeline = @import("pipeline.zig").Pipeline;
pub const RenderContext = @import("pipeline.zig").RenderContext;

pub const Model = @import("model.zig");

pub const Frame = @import("frame.zig").Frame;
pub const Sprite = @import("frame.zig").Sprite;
pub const SpriteFlip = @import("frame.zig").SpriteFlip;

pub const Vec = @import("utils.zig").Vec;

pub const InputMapper = @import("input.zig").InputMapper;
pub const InputAction = @import("input.zig").InputAction;
pub const InputBinding = @import("input.zig").InputBinding;
pub const InputState = @import("input.zig").InputState;
