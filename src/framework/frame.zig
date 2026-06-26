const std = @import("std");
const engine = @import("../engine/root.zig");
const zm = @import("zmath");

const Model = @import("model.zig");
const Vec = @import("utils.zig").Vec;
const Pair = @import("utils.zig").Pair;

const Texture2D = engine.Texture2D;
const Shader = engine.Shader;
const Text2D = engine.Text2D;
const Mesh = engine.Mesh;

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

/// Collects draw calls for one frame then hands them to the pipeline for rendering.
pub const Frame = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    sprites: std.ArrayList(Sprite),
    models: std.ArrayList(Pair(Model, zm.Mat)),
    meshes: std.ArrayList(Pair(Mesh, zm.Mat)),

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{
            .gpa = gpa,
            .sprites = .empty,
            .models = .empty,
        };
    }

    // Queue a text mesh for drawing.
    pub fn drawText(self: *Self, text: *Text2D, pos: Vec) !void {
        try self.meshes.append(self.gpa, .{ text.asMesh(), zm.translationV(pos.value) });
    }

    /// Queue a sprite with a texture, position and a size. 
    /// textures array is duplicated.
    pub fn drawSprite(self: *Self, sprite: Sprite) !void {
        const textures = try self.gpa.dupe(Texture2D, sprite.textures);

        var new_sprite = sprite;
        new_sprite.textures = textures;

        try self.sprites.append(self.gpa, new_sprite);
    }

    /// Queue a 3D model with a world transform matrix.
    pub fn drawModel(self: *Self, model: Model, transform: zm.Mat) !void {
        try self.models.append(self.gpa, .{ model, transform });
    }

    /// Reset draw lists (keeps allocated capacity for reuse).
    pub fn clear(self: *Self) void {
        for (self.sprites.items) |sprite| { 
            self.gpa.free(sprite.textures);
        }

        self.sprites.clearRetainingCapacity();
        self.models.clearRetainingCapacity();
        self.meshes.clearRetainingCapacity();
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.sprites.deinit(self.gpa);
        self.models.deinit(self.gpa);
        self.meshes.deinit(self.gpa);
    }
};

