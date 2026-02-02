const std = @import("std");

const c = @import("deps/glad.zig");
const stbi = @import("deps/stb_image.zig");

/// Low-Level Abstraction over a Texture
/// This may replace the Sprite if I find it useless
pub const Texture2D = struct {
    const Self = @This();
    id: u32,
    meta: ImageMeta,

    pub fn init (pixels: [*c]const u8, image: ImageMeta) Self {
        var tex: u32 = undefined;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);
        defer c.glBindTexture(c.GL_TEXTURE_2D, 0);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, if (image.pixelated) c.GL_NEAREST else c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, if (image.pixelated) c.GL_NEAREST else c.GL_LINEAR);

        c.glTexImage2D(
            c.GL_TEXTURE_2D, 
            0,
            if (image.nChannels == 3) c.GL_SRGB else c.GL_SRGB_ALPHA, 
            image.width, 
            image.height, 
            0, 
            if (image.nChannels == 3) c.GL_RGB else c.GL_RGBA,
            c.GL_UNSIGNED_BYTE, 
            pixels
        );

        c.glGenerateMipmap(c.GL_TEXTURE_2D);

        return .{
            .meta = image,
            .id = tex,
        };
    }

    pub fn deinit(self: Self) void {
        c.glDeleteTextures(1, &self.id);
    }

    pub fn bind(self: Self) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }
};

/// Low-Level Abstraction over a Cubemap
pub const CubeTexture = struct {
    const Self = @This();
    id: u32,

    pub fn init(faces: [6]Image) Self {
        var id: u32 = undefined;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, id);
        defer c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, 0);

        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_WRAP_R, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

        for (faces, 0..) |face, i| {
            const image = face.meta;
            c.glTexImage2D(
                c.GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                0,
                if (image.nChannels == 3) c.GL_SRGB else c.GL_SRGB_ALPHA, 
                image.width, 
                image.height, 
                0, 
                if (image.nChannels == 3) c.GL_RGB else c.GL_RGBA,
                c.GL_UNSIGNED_BYTE, 
                face.pixels,
            );
        }

        return .{ .id = id };
    }

    pub fn deinit(self: Self) void {
        c.glDeleteTextures(1, &self.id);
    }

    pub fn bind(self: Self) void {
        c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, self.id);
    }
};

/// image metadata per texture.
pub const ImageMeta = struct {
    width: i32,
    height: i32,
    nChannels: i32,
    pixelated: bool,
};

/// full image with pixels
pub const Image = struct {
    meta: ImageMeta,
    pixels: [*c]const u8,
};

/// Container for all program assets.
/// this is responsible of loading assets and converting them accordingly
/// TODO: implement loading cubemaps from a single file.
pub const AssetManager = struct {
    const Self = @This();
    
    io: std.Io,
    allocator: std.mem.Allocator,
    textures: std.StringHashMap(Texture2D),
    cubes: std.StringHashMap(CubeTexture),

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Self {
        stbi.stbi_set_flip_vertically_on_load(@intFromBool(true));
        return .{
            .io = io,
            .allocator = allocator,
            .textures = .init(allocator),
            .cubes = .init(allocator),
        };
    }

    /// load a Texture from path into a texture object
    pub fn loadTexture(self: *Self, path: []const u8, pixelated: bool, label: []const u8) !void {
        // image loading stuff.
        const file = try std.Io.Dir.cwd().openFile(self.io, path, .{ .mode = .read_only });
        defer file.close(self.io);

        const meta = try file.stat(self.io);

        const buffer = try self.allocator.alloc(u8, meta.size);
        defer self.allocator.free(buffer);

        _ = try file.readPositionalAll(self.io, buffer, 0);
        
        var width: i32 = undefined;
        var height: i32 = undefined; 
        var nChannels: i32 = undefined;

        const data = stbi.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &width, &height, &nChannels, 0);
        if (data == null) return error.FuckStbiFailed;
        defer stbi.stbi_image_free(data);

        const image: ImageMeta = .{
            .width = width,
            .height = height,
            .pixelated = pixelated,
            .nChannels = nChannels
        };

        try self.textures.put(label, Texture2D.init(data, image));
    }

    /// load a cube map from `files` as its faces.
    pub fn loadCubeMultipleFiles(self: *Self, label: []const u8, files: [6][]const u8) !void {
        var images: [6]Image = undefined;
        defer for (images) |img| stbi.stbi_image_free(img.pixels);

        for (files, 0..) |path, i| {
            const file = try std.Io.Dir.cwd().openFile(self.io, path, .{ .mode = .read_only });
            defer file.close(self.io);

            const stat = try file.stat(self.io);
            const size = stat.size;

            const buffer = try self.allocator.alloc(u8, size);
            defer self.allocator.free(buffer);

            file.readPositionalAll(self.io, buffer, 0);

            const pixels = stbi.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &images[i].meta.width, &images[i].meta.height, &images[i].meta.nChannels, 0);
            if (pixels == null) return error.FuckStbiFailed;

            images[i].pixels = pixels;
        }

        const cube_texture = CubeTexture.init(images);
        try self.cubes.put(label, cube_texture);
    }

    /// loads a cube map from a single image as all faces
    pub fn loadCubeRepeat(self: *Self, label: []const u8, path: []const u8) !void {
        var image: Image = undefined;

        const file = try std.Io.Dir.cwd().openFile(self.io, path, .{ .mode = .read_only });
        defer file.close(self.io);

        const stat = try file.stat(self.io);
        const size = stat.size;

        const buffer = try self.allocator.alloc(u8, size);
        defer self.allocator.free(buffer);

        file.readPositionalAll(self.io, buffer, 0);

        const pixels = stbi.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &image.meta.width, &image.meta.height, &image.meta.nChannels, 0);
        if (pixels == null) return error.FuckStbiFailed;
        defer stbi.stbi_image_free(pixels);

        image.pixels = pixels;

        const images = [6]Image{ image, image, image, image, image, image };

        const cube_texture = CubeTexture.init(images);
        try self.cubes.put(label, cube_texture);
    }

    pub fn deinit(self: *Self) void {
        var textures = self.textures.valueIterator();
        while (textures.next()) |texture| texture.deinit();

        var cubes = self.textures.valueIterator();
        while (cubes.next()) |cube| cube.deinit();
        
        self.textures.deinit();
        self.cubes.deinit();
    }
};
