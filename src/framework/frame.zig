const std = @import("std");
const engine = @import("../engine/root.zig");
const zm = @import("zmath");

const Model = @import("model.zig");
const Vec = @import("utils.zig").Vec;
const Pair = @import("utils.zig").Pair;

const Texture2D = engine.Texture2D;
const Shader = engine.Shader;

/// Which axes to mirror the sprite on.
pub const SpriteFlip = enum(u2) {
    horizontal, vertical, both, none
};

/// A renderable image with position, rotation, pivot, and optional shader.
/// Multiple textures supported (e.g. for normal/light maps).
pub const Sprite = struct {
    textures: []Texture2D,
    position: Vec,
    size: Vec,
    pivot: Vec = .vec2(0.5, 0.5),
    rotation: Vec = .vec(0),
    layer: u32 = 0,
    flip: SpriteFlip = .none,
    shader: ?Shader = null,
};

/// Collects draw calls for one frame, then handed to the pipeline for execution.
pub const Frame = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    sprites: std.ArrayList(Sprite),
    models: std.ArrayList(Pair(Model, zm.Mat)),

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{
            .allocator = gpa,
            .sprites = .empty,
            .models = .empty,
        };
    }

    /// Queue a sprite. textures array is duplicated — owned by the frame now.
    pub fn drawSprite(self: *Self, sprite: Sprite) !void {
        const textures = try self.allocator.dupe(Texture2D, sprite.textures);

        var new_sprite = sprite;
        new_sprite.textures = textures;

        try self.sprites.append(self.allocator, new_sprite);
    }

    /// Queue a 3D model with a world transform matrix.
    pub fn drawModel(self: *Self, model: Model, transform: zm.Mat) !void {
        try self.models.append(self.allocator, .{ model, transform });
    }

    /// Reset draw lists (keeps allocated capacity for reuse).
    pub fn clear(self: *Self) void {
        for (self.sprites.items) |sprite| { 
            self.allocator.free(sprite.textures);
        }

        self.sprites.clearRetainingCapacity();
        self.models.clearRetainingCapacity();
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.sprites.deinit(self.allocator);
        self.models.deinit(self.allocator);
    }
};

