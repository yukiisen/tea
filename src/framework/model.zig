const std = @import("std");

const engine = @import("../engine/root.zig");
const Mesh = engine.Mesh;
const MeshConfig = engine.MeshConfig;

/// A 3D model: one or more meshes loaded from config.
const Self = @This();

gpa: std.mem.Allocator,
meshes: []const Mesh,

/// Load a single-mesh model.
pub fn load(gpa: std.mem.Allocator, config: MeshConfig) !Self {
    const mesh = try Mesh.init(config);
    const meshes = try gpa.alloc(Mesh, 1);
    meshes[0] = mesh;

    return .{ .gpa = gpa, .meshes = meshes };
}

/// Load a multi-mesh model from several configs.
pub fn loadMulti(gpa: std.mem.Allocator, configs: []const MeshConfig) !Self {
    const meshes = try gpa.alloc(Mesh, configs.len);

    for (configs, 0..) |config, i| {
        meshes[i] = try Mesh.init(config);
    }

    return .{ .gpa = gpa, .meshes = meshes };
}

pub fn deinit(self: *Self) void {
    for (self.meshes) |mesh| {
        mesh.deinit();
    }

    self.gpa.free(self.meshes);
}
