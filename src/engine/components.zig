const std = @import("std");

const gl = @import("zopengl").bindings;
const z = @import("zmath");

/// Holds Vertex Data of a specific entity
/// Don't change internal data of this struct unless you know what you're doing
pub const Mesh = struct {
    const Self = @This();
    VAO: u32,
    VBO: u32,
    EBO: u32,
    indexed: bool,
    count: i32,

    /// create a mesh.
    /// The input buffers in `config` don't need to outlive this instance, you can free them at any time.
    pub fn init(config: MeshConfig) !Self {
        var VAO: u32 = undefined;
        var VBO: u32 = undefined;
        var EBO: u32 = undefined;
        const indexed = config.indices != null;

        gl.genVertexArrays(1, &VAO);
        gl.genBuffers(1, &VBO);
        if (indexed) gl.genBuffers(1, &EBO);

        gl.bindVertexArray(VAO);
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        if (indexed) gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);

        gl.bufferData(gl.ARRAY_BUFFER, @intCast(config.vertices.len * @sizeOf(Vertex)), config.vertices.ptr, gl.STATIC_DRAW);
        if (config.indices) |indices| gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);

        const fields: []const std.builtin.Type.StructField = std.meta.fields(Vertex);

        inline for (fields, 0..) |field, i| {
            gl.vertexAttribPointer(
                i,
                @typeInfo(field.type).array.len,
                gl.FLOAT,
                gl.FALSE, 
                @sizeOf(Vertex), 
                @ptrFromInt(@offsetOf(Vertex, field.name))
            );

            gl.enableVertexAttribArray(i);
        }

        if (gl.getError() != gl.NO_ERROR) {
            return error.GlfuckedUp;
        }

        return .{
            .VBO = VBO,
            .VAO = VAO,
            .EBO = EBO,
            .indexed = indexed,
            .count = @intCast(if (config.indices) |i| i.len else config.vertices.len),
        };
    }

    pub fn bind (self: *const Self) void {
        gl.bindVertexArray(self.VAO);
    }

    pub fn deinit(self: Self) void {
        gl.bindVertexArray(0);
        gl.deleteBuffers(1, &self.VBO);
        if (self.indexed) gl.deleteBuffers(1, &self.EBO);
        gl.deleteVertexArrays(1, &self.VAO);
    }
};

pub const Vertex = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    texCoords: [2]f32 = .{ 0, 0 },
    normal: [3]f32 = .{ 0, 0, 0 },
};

pub const MeshConfig = struct {
    vertices: []const Vertex = &.{},
    indices: ?[]const u32 = null,

    pub const quad: MeshConfig = .{
        .vertices = &.{
            .{ .position = .{ -0.5, -0.5, 0 }, .texCoords = .{ 0, 0 } },
            .{ .position = .{ 0.5, -0.5, 0 }, .texCoords = .{ 1, 0 } },
            .{ .position = .{ 0.5, 0.5, 0 }, .texCoords = .{ 1, 1 } },
            .{ .position = .{ -0.5, 0.5, 0 }, .texCoords = .{ 0, 1 } },
        },
        .indices = &.{ 0, 1, 2, 2, 3, 0 },
    };

    pub const cube: MeshConfig = .{
        .vertices = &.{
            .{ .position = .{ -0.5, -0.5, 0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ 0, 0, 1 } },
            .{ .position = .{ 0.5, -0.5, 0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ 0, 0, 1 } },
            .{ .position = .{ 0.5, 0.5, 0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ 0, 0, 1 } },
            .{ .position = .{ -0.5, 0.5, 0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ 0, 0, 1 } },

            .{ .position = .{ 0.5, -0.5, -0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ 1, 0, 0 } },
            .{ .position = .{ 0.5, -0.5, 0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ 1, 0, 0 } },
            .{ .position = .{ 0.5, 0.5, 0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ 1, 0, 0 } },
            .{ .position = .{ 0.5, 0.5, -0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ 1, 0, 0 } },

            .{ .position = .{ 0.5, -0.5, -0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ 0, 0, -1 } },
            .{ .position = .{ -0.5, -0.5, -0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ 0, 0, -1 } },
            .{ .position = .{ -0.5, 0.5, -0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ 0, 0, -1 } },
            .{ .position = .{ 0.5, 0.5, -0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ 0, 0, -1 } },

            .{ .position = .{ -0.5, -0.5, 0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ -1, 0, 0 } },
            .{ .position = .{ -0.5, -0.5, -0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ -1, 0, 0 } },
            .{ .position = .{ -0.5, 0.5, -0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ -1, 0, 0 } },
            .{ .position = .{ -0.5, 0.5, 0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ -1, 0, 0 } },

            .{ .position = .{ -0.5, 0.5, 0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ 0, 1, 0 } },
            .{ .position = .{ 0.5, 0.5, 0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ 0, 1, 0 } },
            .{ .position = .{ 0.5, 0.5, -0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ 0, 1, 0 } },
            .{ .position = .{ -0.5, 0.5, -0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ 0, 1, 0 } },

            .{ .position = .{ -0.5, -0.5, -0.5 }, .texCoords = .{ 0, 0 }, .normal = .{ 0, -1, 0 } },
            .{ .position = .{ 0.5, -0.5, -0.5 }, .texCoords = .{ 1, 0 }, .normal = .{ 0, -1, 0 } },
            .{ .position = .{ 0.5, -0.5, 0.5 }, .texCoords = .{ 1, 1 }, .normal = .{ 0, -1, 0 } },
            .{ .position = .{ -0.5, -0.5, 0.5 }, .texCoords = .{ 0, 1 }, .normal = .{ 0, -1, 0 } },
        },
        .indices = &.{
            0, 1, 2, 0, 2, 3,
            4, 5, 6, 4, 6, 7,
            8, 9, 10, 8, 10, 11,
            12, 13, 14, 12, 14, 15,
            16, 17, 18, 16, 18, 19,
            20, 21, 22, 20, 22, 23,
        },
    };

    pub fn circle(comptime segments: u32) MeshConfig {
        const vert_count = segments + 1;
        const idx_count = segments * 3;

        // this is created per-call (similar segments inputs are the same call).
        const static = struct {
            var vertices: [vert_count]Vertex = undefined;
            var indices: [idx_count]u32 = undefined;
        };

        static.vertices[0] = .{
            .position = .{ 0, 0, 0 },
            .texCoords = .{ 0.5, 0.5 },
            .normal = .{ 0, 0, 1 },
        };

        for (0..segments) |i| {
            const angle = @as(f32, @floatFromInt(i)) * (2.0 * std.math.pi) / @as(f32, @floatFromInt(segments));
            const cos_a = @cos(angle);
            const sin_a = @sin(angle);
            static.vertices[i + 1] = .{
                .position = .{ 0.5 * cos_a, 0.5 * sin_a, 0 },
                .texCoords = .{ 0.5 + 0.5 * cos_a, 0.5 + 0.5 * sin_a },
                .normal = .{ 0, 0, 1 },
            };
        }

        for (0..segments) |i| {
            static.indices[i * 3] = 0;
            static.indices[i * 3 + 1] = @intCast(i + 1);
            static.indices[i * 3 + 2] = @intCast(if (i + 1 == segments) 1 else i + 2);
        }

        return .{
            .vertices = &static.vertices,
            .indices = &static.indices,
        };
    }
};

/// Contains the local transformations of a Mesh/Model
pub const Transform = struct {
    translate: z.Mat,
    rotate: z.Mat,
    scale: z.Mat,
};

/// Allows rendering text on the screen
pub const Text2D = struct {

};
