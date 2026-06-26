const std = @import("std");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const zm = @import("zmath");

const glError = @import("utils.zig").glError;

const mesh = @import("mesh.zig");
const Mesh = mesh.Mesh;
const MeshConfig = mesh.MeshConfig;

const assets = @import("assets.zig");
const Texture2D = assets.Texture2D;

const Dir = std.Io.Dir;

const json = std.json;
const gl = zopengl.bindings;

pub const Box = struct {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
};

pub const Glyph = struct {
    unicode: u32,
    advance: f32,
    atlasBounds: ?Box,
    planeBounds: ?Box,
};

pub const FontJson = struct {
    atlas: struct {
        distanceRange: u32,
        distanceRangeMiddle: u32,
        height: u32,
        width: u32,
        size: u32,
        type: []const u8,
        yOrigin: []const u8,
    },
    metrics: struct {
        ascender: f32,
        descender: f32,
        emSize: f32,
        lineHeight: f32,
        underlineThickness: f32,
        underlineY: f32,
    },
    glyphs: []struct {
        unicode: u32,
        advance: f32,
        atlasBounds: ?Box = null,
        planeBounds: ?Box = null,
    },
    kerning: []struct {
        unicode1: u32,
        unicode2: u32,
        advance: f32,
    },
};

pub const FontAtlas = struct {
    const Self = @This();

    pub const FontMetrics = struct {
        em_size: f32,
        line_height: f32,
        ascender: f32,
        descender: f32,
    };

    metrics: FontMetrics,
    texture: Texture2D,
    glyphs: std.AutoHashMap(u32, Glyph),
    kerning: std.AutoHashMap(u64, f32),

    pub fn init(gpa: std.mem.Allocator, io: std.Io, comptime json_path: []const u8, comptime texture_path: []const u8) !Self {
        const file = try Dir.cwd().openFile(io, json_path, .{ .mode = .read_only });
        defer file.close(io);

        var stat = try file.stat(io);

        const content = try gpa.alloc(u8, stat.size);
        defer gpa.free(content);

        _ = try file.readPositionalAll(io, content, 0);

        const parsed: json.Parsed(FontJson) = try json.parseFromSlice(FontJson, gpa, content, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
        defer parsed.deinit();

        const metadata = parsed.value;

        const metrics: FontMetrics = .{
            .ascender = metadata.metrics.ascender,
            .descender = metadata.metrics.descender,
            .line_height = metadata.metrics.lineHeight,
            .em_size = @floatFromInt(metadata.atlas.size),
        };

        var glyphs = std.AutoHashMap(u32, Glyph).init(gpa);

        for (metadata.glyphs) |g| {
            try glyphs.put(g.unicode, .{
                .unicode = g.unicode,
                .advance = g.advance,
                .planeBounds = g.planeBounds,
                .atlasBounds = g.atlasBounds,
            });
        }

        var kerning = std.AutoHashMap(u64, f32).init(gpa);

        for (metadata.kerning) |k| {
            try kerning.put(hashKerning(k.unicode1, k.unicode2), k.advance);
        }

        const tex_file = try Dir.cwd().openFile(io, texture_path, .{ .mode = .read_only });
        defer tex_file.close(io);

        stat = try tex_file.stat(io);

        const image_data = try gpa.alloc(u8, stat.size);
        defer gpa.free(image_data);

        _ = try tex_file.readPositionalAll(io, image_data, 0);

        if (!zstbi.isInitialized()) zstbi.init(gpa) catch unreachable;
        zstbi.setFlipVerticallyOnLoad(true);

        var image = try zstbi.Image.loadFromMemory(image_data, 4); // load from mem in case the user didn't initialize zstbi yet.
        defer image.deinit();

        const texture = try Texture2D.init(image, false);

        return .{
            .metrics = metrics,
            .texture = texture,
            .glyphs = glyphs,
            .kerning = kerning,
        };
    }

    fn hashKerning(left: u32, right: u32) u64 {
        return (@as(u64, left) << 32) | right;
    }

    pub fn getGlyph(self: *const Self, codepoint: u32) ?Glyph {
        return self.glyphs.get(codepoint);
    }

    pub fn getKerning(self: *const Self, left: u32, right: u32) f32 {
        return self.kerning.get(hashKerning(left, right)) orelse 0.0;
    }

    pub fn deinit(self: *Self) void {
        self.glyphs.deinit();
        self.kerning.deinit();
        self.texture.deinit();
    }
};

pub const Coord = struct {
    x: f32,
    y: f32
};

/// Allows rendering text on the screen
pub const Text2D = struct {
    const Self = @This();
    pub const MAX_TEXT_LENGTH = 512;

    pub const Vertex = struct {
        pos: [2]f32,
        uv: [2]f32,
    };

    gpa: std.mem.Allocator,

    vao: u32,
    vbo: u32,
    ebo: u32,

    content: []u8,
    font: *FontAtlas,

    /// Hexadecimal text color.
    color: u32 = 0x00000000,

    /// TODO: handle different charsets
    pub fn init(gpa: std.mem.Allocator, font: *FontAtlas) !Self {
        const n_indices = MAX_TEXT_LENGTH * 6;
        const n_vertices = MAX_TEXT_LENGTH * 4;

        var VAO: u32 = undefined;
        var VBO: u32 = undefined;
        var EBO: u32 = undefined;

        gl.genVertexArrays(1, &VAO);
        gl.genBuffers(1, &VBO);
        gl.genBuffers(1, &EBO);

        gl.bindVertexArray(VAO);
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, VBO);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);

        gl.bufferData(gl.ARRAY_BUFFER, @intCast(n_vertices * @sizeOf(Vertex)), null, gl.DYNAMIC_DRAW);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(n_indices * @sizeOf(u32)), genQuadIndices(MAX_TEXT_LENGTH).ptr, gl.DYNAMIC_DRAW);

        const fields = @typeInfo(Vertex).@"struct".fields;

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

        try glError(gl.getError());

        return .{
            .gpa = gpa,
            .vbo = VBO,
            .vao = VAO,
            .ebo = EBO,
            .content = &.{},
            .font = font,
        };
    }

    pub fn clear(self: *Self) void {
        self.gpa.free(self.content);
    }

    pub fn write(self: *Self, slice: []const u8) !void {
        self.clear();
        self.content = try self.gpa.dupe(u8, slice);
    }

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const slice = try std.fmt.allocPrint(self.gpa, fmt, args);
        self.clear();
        self.content = slice;
    }

    pub fn flush(self: *Self) !void {
        const text = self.content;

        var cursor = Coord { .x = 0, .y = 0 };

        const vertex_buffer = try self.gpa.alloc(Vertex, text.len * 4);
        defer self.gpa.free(vertex_buffer);

        for (text, 0..) |char, i| {
            const glyph = self.font.getGlyph(char) orelse continue;

            if (glyph.atlasBounds != null) {
                const atlasBounds = glyph.atlasBounds.?;
                const planeBounds = glyph.planeBounds.?;

                const l = cursor.x + planeBounds.left  * self.font.metrics.em_size;
                const b = cursor.y + planeBounds.bottom * self.font.metrics.em_size;
                const r = cursor.x + planeBounds.right  * self.font.metrics.em_size;
                const t = cursor.y + planeBounds.top    * self.font.metrics.em_size;

                const width = @as(f32, @floatFromInt(self.font.texture.meta.width));
                const height = @as(f32, @floatFromInt(self.font.texture.meta.height));

                const tl = atlasBounds.left   / width;
                const tb = atlasBounds.bottom / height;
                const tr = atlasBounds.right  / width;
                const tt = atlasBounds.top    / height;

                vertex_buffer[i * 4 + 0] = .{ .pos = .{ l, b }, .uv = .{ tl, tb } };
                vertex_buffer[i * 4 + 1] = .{ .pos = .{ r, b }, .uv = .{ tr, tb } };
                vertex_buffer[i * 4 + 2] = .{ .pos = .{ r, t }, .uv = .{ tr, tt } };
                vertex_buffer[i * 4 + 3] = .{ .pos = .{ l, t }, .uv = .{ tl, tt } };
            }

            cursor.x += glyph.advance * self.font.metrics.em_size;
            if (i+1 < text.len) cursor.x += self.font.getKerning(char, text[i+1]);
        }


        gl.bindVertexArray(self.vao);
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        
        gl.bufferSubData(gl.ARRAY_BUFFER, 0, @intCast(vertex_buffer.len * @sizeOf(Vertex)), vertex_buffer.ptr);

        try glError(gl.getError());
    }

    pub fn setColor(self: *Self, color: zm.Vec) void {
        const base = @as(@Vector(4, u32), @intFromFloat(color)) * @as(@Vector(4, u32), @splat(256));
        self.color = (base[0] << 24) | (base[1] << 16) | (base[2] << 8) | (base[3] << 0);
    }

    pub fn getColor(self: *const Self) zm.Vec {
        const vec = zm.f32x4(
            @floatFromInt((self.color >> 24) & 0xFF),
            @floatFromInt((self.color >> 16) & 0xFF),
            @floatFromInt((self.color >>  8) & 0xFF),
            @floatFromInt((self.color >>  0) & 0xFF),
        );

        return vec / zm.splat(zm.Vec, 0xFF);
    }

    pub fn genQuadIndices(comptime n: u32) []const u32 {
        const static = struct {
            var indices: [n * 6]u32 = undefined;
        };

        inline for (0..n) |i| {
            static.indices[i * 6 + 0] = (i * 4) + 0;
            static.indices[i * 6 + 1] = (i * 4) + 1;
            static.indices[i * 6 + 2] = (i * 4) + 2;
            static.indices[i * 6 + 3] = (i * 4) + 2;
            static.indices[i * 6 + 4] = (i * 4) + 3;
            static.indices[i * 6 + 5] = (i * 4) + 0;
        }

        return static.indices[0..];
    }

    pub fn asMesh(self: *const Self) Mesh {
        return .{ 
            .VAO = self.vao,
            .EBO = self.ebo,
            .VBO = self.vbo,
            .count = @intCast(self.content.len * 6),
            .indexed = true
        };
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        gl.bindVertexArray(0);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        gl.deleteVertexArrays(1, &self.vao);
    }
};
