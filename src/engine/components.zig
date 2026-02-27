const std = @import("std");

const c = @import("deps/glad.zig");
const z = @import("zmath");

/// Holds Vertex Data of a specific entity
/// This is used a component and shall be used as a dependency for the Model component later.
/// Don't change internal data of this struct unless you know what you're doing
pub const Mesh = struct {
    const Self = @This();
    VAO: u32,
    VBO: u32,
    EBO: u32,
    indexed: bool,
    count: i32,

    pub fn init(config: MeshConfig) Self {
        var VAO: u32 = undefined;
        var VBO: u32 = undefined;
        var EBO: u32 = undefined;
        const indexed = config.indices != null;

        c.glGenVertexArrays(1, &VAO);
        c.glGenBuffers(1, &VBO);
        if (indexed) c.glGenBuffers(1, &EBO);

        c.glBindVertexArray(VAO);
        defer c.glBindVertexArray(0);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
        if (indexed) c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, EBO);

        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(config.vertices.len * @sizeOf(Vertex)), config.vertices.ptr, c.GL_STATIC_DRAW);
        if (config.indices) |indices| c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, c.GL_STATIC_DRAW);

        const info = @typeInfo(Vertex).@"struct";

        inline for (info.fields, 0..) |field, i| {
            c.glVertexAttribPointer(
                i,
                @typeInfo(field.type).array.len,
                c.GL_FLOAT,
                c.GL_FALSE, 
                @sizeOf(Vertex), 
                @ptrFromInt(@offsetOf(Vertex, field.name))
            );

            c.glEnableVertexAttribArray(i);
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
        c.glBindVertexArray(self.VAO);
    }

    pub fn deinit(self: Self) void {
        c.glBindVertexArray(0);
        c.glDeleteBuffers(1, &self.VBO);
        if (self.indexed) c.glDeleteBuffers(1, &self.EBO);
        c.glDeleteVertexArrays(1, &self.VAO);
    }
};

pub const Vertex = struct {
    position: [3]f32,
    texCoords: [2]f32,
    normal: [3]f32,
};

pub const MeshConfig = struct {
    vertices: []Vertex = &[_]Vertex{},
    indices: ?[]const u32 = null,
};

/// Contains the local transformations of a Mesh/Model
pub const Transform = struct {
    translate: z.Mat,
    rotate: z.Mat,
    scale: z.Mat,
};

/// Controls the speed of an object
pub const Velocity = struct {
    x: f32,
    y: f32,
    z: f32,
};

/// Controls the acceleration of an object
pub const Acceleration = struct {
    x: f32,
    y: f32,
    z: f32,
};

/// Allows rendering text on the screen
/// This is used for UI text since it uses a separate camera from the default one (no perspective).
pub const Text2D = struct {

};
