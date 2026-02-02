const std = @import("std");

const c = @import("deps/glad.zig");
const w = @import("deps/glfw3.zig");
const z = @import("zmath");

/// Used internally by the renderer for shared uniforms
/// Not a part of the High-Level API
pub const UniformBuffer = struct {
    const Self = @This();

    id: u32,
    allocator: std.mem.Allocator,
    blob: []u8,

    /// use glsl-compatible types pls :)
    pub fn init(comptime T: type, allocator: std.mem.Allocator) !Self {
        const tinfo = @typeInfo(T);
        if (tinfo != .@"struct") @compileError("A uniform block must be of struct type.");
        const info = tinfo.@"struct";

        var id: u32 = undefined;

        c.glGenBuffers(1, &id);
        c.glBindBuffer(c.GL_UNIFORM_BUFFER, id);
        defer c.glBindBuffer(c.GL_UNIFORM_BUFFER, 0);

        // Generate size from type at compile time because zig is so sexy.
        const size: i32 = comptime blk: {
            var s: i32 = 0;

            for (info.fields) |f| s = std140Alignment(f, s);

            break :blk s;
        };

        c.glBufferData(c.GL_UNIFORM_BUFFER, size, null, c.GL_STATIC_DRAW);

        const buf = try allocator.alloc(u8, @sizeOf(T));

        return .{ .id = id, .allocator = allocator, .blob = buf };
    }

    /// returns the new size of the struct after adding a field of type `T` to it.
    /// **Asserts** that `Type.array` fields are all matrices.
    fn std140Alignment (comptime f: std.builtin.Type.StructField, s: i32) i32 {
        const fi = @typeInfo(f.type);

        return switch (fi) {
            .int, .float, .bool => s += 4,
            .vector  => |v|
                // alignment shit
                if (v.len > 2) return s + 16 + (if (s % 16 == 0) 0 else 16 - (s % 16)) // vec3/4
                else if (s % 8 != 0) return s + 8 + 8 - (s % 8) // not aligned to vec2
                else s + 8 // aligned to vec2
            ,
            .array => |a| blk: {
                // Matrix
                const v = @typeInfo(a.child).vector;

                break :blk 
                    if (v.len > 2) s + 16 * a.len + (if (s % 16 == 0) 0 else 16 - (s % 16))
                    else if (s % 8 != 0) s + 8 * a.len + 8 - (s % 8)
                    else s + 8 * a.len;
            },
            else => unreachable,
        };
    }

    /// returns a pointer to the CPU blob that backs this buffer.
    pub fn getPtr(self: Self, comptime T: type) *T {
        return @ptrCast(@alignCast(self.blob));
    }

    /// converts and uploads blob data to the GPU.
    pub fn update(self: Self, comptime T: type) void {
        const tinfo = @typeInfo(T);
        if (tinfo != .@"struct") @compileError("Attempt to use a non-struct type as a uniform buffer.");
        const info = tinfo.@"struct";

        const offsets = comptime blk: {
            var offsets: [info.fields.len]i32 = undefined;
            offsets[0] = 0;

            for (info.fields, 0..) |f, i| {
                if (i + 1 < info.fields.len) // skip last 
                    offsets[i + 1] = std140Alignment(f, offsets[i]); // next offset = current size.
            }

            break :blk offsets;
        };

        c.glBindBuffer(c.GL_UNIFORM_BUFFER, self.id);
        defer c.glBindBuffer(c.GL_UNIFORM_BUFFER, 0);

        const buf = self.getPtr(T);

        inline for (info.fields, offsets) |field, offset| {
            const finfo = @typeInfo(field.type);

            switch (finfo) {
                inline .int, .float => c.glBufferSubData(c.GL_UNIFORM_BUFFER, offset, 4, &@field(buf.*, field.name)),
                inline .bool => c.glBufferSubData(c.GL_UNIFORM_BUFFER, offset, 4, if (@field(buf.*, field.name)) &1 else &0),
                inline .vector => |v| c.glBufferSubData(c.GL_UNIFORM_BUFFER, offset, 4 * v.len, z.arrNPtr(&@field(buf.*, field.name))),
                inline .array => |a| c.glBufferSubData(c.GL_UNIFORM_BUFFER, offset, 4 * 4 * a.len, z.arrNPtr(&@field(buf.*, field.name))),
                else => unreachable,
            }
        }
    }

    /// specifies the binding point for this buffer.
    pub fn bindAt(self: Self, point: u32) void {
        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, point, self.id);
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.blob);
        c.glDeleteBuffers(1, &self.id);
    }
};
