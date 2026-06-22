const std = @import("std");

const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");

const Image = zstbi.Image;

/// Low-Level Abstraction over a Texture
/// It is safe to copy this struct around.
pub const Texture2D = struct {
    const Self = @This();
    id: u32,
    meta: ImageMeta,

    pub fn init (image: Image, pixelated: bool) Self {
        var tex: u32 = undefined;
        gl.genTextures(1, &tex);
        gl.bindTexture(gl.TEXTURE_2D, tex);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, if (pixelated) gl.NEAREST else gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, if (pixelated) gl.NEAREST else gl.LINEAR);

        gl.texImage2D(
            gl.TEXTURE_2D, 
            0,
            if (image.num_components == 3) gl.SRGB else gl.SRGB_ALPHA, 
            image.width, 
            image.height, 
            0, 
            if (image.num_components == 3) gl.RGB else gl.RGBA,
            gl.UNSIGNED_BYTE, 
            image.data
        );

        gl.generateMipmap(gl.TEXTURE_2D);

        return .{
            .meta = .{ .width = image.width, .height = image.height, .nChannels = image.num_components, .pixelated = pixelated },
            .id = tex,
        };
    }

    pub fn deinit(self: Self) void {
        gl.deleteTextures(1, &self.id);
    }

    pub fn bind(self: Self, point: i32) void {
        gl.activeTexture(@intCast(gl.TEXTURE0 + point));
        gl.bindTexture(gl.TEXTURE_2D, self.id);
    }
};

/// Low-Level Abstraction over a Cubemap
pub const CubeTexture = struct {
    const Self = @This();
    id: u32,

    pub fn init(faces: [6]Image) Self {
        var id: u32 = undefined;
        gl.genTextures(1, &id);
        gl.bindTexture(gl.TEXTURE_CUBE_MAP, id);
        defer gl.bindTexture(gl.TEXTURE_CUBE_MAP, 0);

        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        for (faces, 0..) |image, i| {
            gl.texImage2D(
                gl.TEXTURE_CUBE_MAP_POSITIVE_X + i,
                0,
                if (image.num_components == 3) gl.SRGB else gl.SRGB_ALPHA, 
                image.width, 
                image.height, 
                0, 
                if (image.num_components == 3) gl.RGB else gl.RGBA,
                gl.UNSIGNED_BYTE, 
                image.data,
            );
        }

        return .{ .id = id };
    }

    pub fn deinit(self: Self) void {
        gl.deleteTextures(1, &self.id);
    }

    pub fn bind(self: Self, point: i32) void {
        gl.activeTexture(@intCast(gl.TEXTURE0 + point));
        gl.bindTexture(gl.TEXTURE_CUBE_MAP, self.id);
    }
};

/// image metadata per texture.
pub const ImageMeta = struct {
    width: i32,
    height: i32,
    nChannels: i32,
    pixelated: bool,
};

/// Container for all program assets.
/// this is responsible of loading assets and converting them accordingly
/// TODO: implement loading cubemaps from a single file.
pub const AssetManager = struct {
    const Self = @This();
    
    textures: std.StringHashMap(Texture2D),
    cubes: std.StringHashMap(CubeTexture),

    pub fn init(allocator: std.mem.Allocator) Self {
        zstbi.setFlipVerticallyOnLoad(true);
        zstbi.init(allocator);

        return .{
            .textures = .init(allocator),
            .cubes = .init(allocator),
        };
    }

    /// load a Texture from path into a texture object
    /// Textures created using this method are automatically freed using the `deinit` method of this instance.
    pub fn loadTexture(self: *Self, label: []const u8, path: []const u8, pixelated: bool) !void {
        // image loading stuff.
        const image = try zstbi.Image.loadFromFile(path, 4);
        defer image.deinit();

        const tex = Texture2D.init(image, pixelated);
        try self.textures.put(label, tex);
    }

    /// load a cube map from `files` as its faces.
    /// Textures created using this method are automatically freed using the `deinit` method of this instance.
    pub fn loadCubeMultipleFiles(self: *Self, label: []const u8, files: [6][]const u8) !void {
        var images: [6]Image = undefined;
        var loaded: usize = 0;
        errdefer for (images[0..loaded]) |*img| img.deinit();

        for (files, 0..) |path, i| {
            images[i] = try Image.loadFromFile(path, 4);
            loaded = i + 1;
        }

        const cube_texture = CubeTexture.init(images);

        for (images) |*img| img.deinit();
        loaded = 0;

        try self.cubes.put(label, cube_texture);
    }

    /// loads a cube map from a single image as all faces
    /// Textures created using this method are automatically freed using the `deinit` method of this instance.
    pub fn loadCubeRepeat(self: *Self, label: []const u8, path: []const u8) !void {
        const image = try Image.loadFromFile(path, 4);
        defer image.deinit();
        const images = [6]Image{ image, image, image, image, image, image };

        const cube_texture = CubeTexture.init(images);
        try self.cubes.put(label, cube_texture);
    }

    pub fn deinit(self: *Self) void {
        var textures = self.textures.valueIterator();
        while (textures.next()) |texture| texture.deinit();

        var cubes = self.cubes.valueIterator();
        while (cubes.next()) |cube| cube.deinit();
        
        self.textures.deinit();
        self.cubes.deinit();

        zstbi.deinit();
    }
};
