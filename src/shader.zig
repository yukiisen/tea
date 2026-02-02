const std = @import("std");

const c = @import("deps/glad.zig");
const z = @import("zmath");

/// Compiles and Holds Shader data.
pub const Shader = struct {
    const Self = @This();
    id: u32,
    /// this is kept only to free memory after use.
    allocator: std.mem.Allocator,
    /// blob of uniform data.
    uniforms: []u8, 
    config: ShaderConfig,

    /// TODO: optimize buffer operations
    pub fn init(allocator: std.mem.Allocator, io: std.Io, comptime T: type, config: ShaderConfig) !Self {
        const ffrag = try std.Io.Dir.cwd().openFile(io, config.fragment, .{ .mode = .read_only });
        const fvert = try std.Io.Dir.cwd().openFile(io, config.vertex , .{ .mode = .read_only });
        defer ffrag.close(io);
        defer fvert.close(io);

        const fragstat = try ffrag.stat(io);
        const vertstat = try fvert.stat(io);

        var buf = try allocator.alloc(u8, fragstat.size);
        defer allocator.free(buf);

        // read and compile fragment shader.
        _ = try ffrag.readPositionalAll(io, buf, 0); // this should return fragstat.size so I won't check it right now.
        
        var info: [512]u8 = undefined;
        var success: i32 = 0;
        
        const sfrag = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        defer c.glDeleteShader(sfrag);

        c.glShaderSource(sfrag, 1, &buf.ptr, @ptrCast(&buf.len));
        c.glCompileShader(sfrag);
        c.glGetShaderiv(sfrag, c.GL_COMPILE_STATUS, &success);
        
        if (success == 0) {
            c.glGetShaderInfoLog(sfrag, @sizeOf(@TypeOf(info)), null, &info);
            std.debug.print("Error: during fragment shader compilation:\n{s}\n", .{ info });
            return error.ShaderCompilationFailed;
        }


        // read and compile vertex shader.
        buf = try allocator.realloc(buf, vertstat.size); // we resize because I don't want to deal with zig's shit now
        _ = try fvert.readPositionalAll(io, buf, 0); // this should return vertstat.size so I won't check it right now.
        
        const svert = c.glCreateShader(c.GL_VERTEX_SHADER);
        defer c.glDeleteShader(svert);

        c.glShaderSource(svert, 1, &buf.ptr, @ptrCast(&buf.len));
        c.glCompileShader(svert);
        c.glGetShaderiv(svert, c.GL_COMPILE_STATUS, &success);
        
        if (success == 0) {
            c.glGetShaderInfoLog(svert, @sizeOf(@TypeOf(info)), null, &info);
            std.debug.print("Error: during vertex shader compilation:\n{s}\n", .{ info });
            return error.ShaderCompilationFailed;
        }
        
        var geometry_shaders: []u32 = &.{};

        if (config.geometry) |files| {
            geometry_shaders = try allocator.alloc(u32, files.len);
            errdefer allocator.free(geometry_shaders);

            for (files, 0..) |file, i|  {
                geometry_shaders[i] = try createGeometryShader(allocator, io, file);
            }
        }

        defer if (config.geometry != null) allocator.free(geometry_shaders); // free when done
        defer for (geometry_shaders) |s| c.glDeleteShader(s);

        const program = c.glCreateProgram();

        c.glAttachShader(program, sfrag);
        c.glAttachShader(program, svert);

        for (geometry_shaders) |sgeom| {
            c.glAttachShader(program, sgeom);
        }

        c.glLinkProgram(program);

        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);

        if (success == 0) {
            c.glGetProgramInfoLog(program, @sizeOf(@TypeOf(info)), null, &info);
            std.debug.print("Error: during shader program linking:\n{s}\n", .{ info });
            return error.ShaderProgramLinkingFailed;
        }

        const uniforms = try allocator.alloc(u8, @sizeOf(T));

        return .{ 
            .id = program, 
            .allocator = allocator, 
            .uniforms = uniforms, 
            .config = config,
        };
    }

    inline fn createGeometryShader (allocator: std.mem.Allocator, io: std.Io, path: []const u8) !u32 {
        const fgeom = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
        defer fgeom.close(io);

        const geomstat = try fgeom.stat(io);

        const buf = try allocator.alloc(u8, geomstat.size);
        defer allocator.free(buf);

        _ = try fgeom.readPositionalAll(io, buf, 0); // this should return stat.size so I won't check it right now.
        
        var info: [512]u8 = undefined;
        var success: i32 = 0;
        
        const sgeom = c.glCreateShader(c.GL_GEOMETRY_SHADER);
        c.glShaderSource(sgeom, 1, &buf.ptr, @ptrCast(&buf.len));
        c.glCompileShader(sgeom);
        c.glGetShaderiv(sgeom, c.GL_COMPILE_STATUS, &success);
        
        if (success == 0) {
            c.glGetShaderInfoLog(sgeom, @sizeOf(@TypeOf(info)), null, &info);
            std.debug.print("Error: during geometry shader compilation:\n{s}\n", .{ info });
            return error.ShaderCompilationFailed;
        }

        return sgeom;
    }

    /// updates uniforms based on `T` and the values set using `alterUniforms`.
    /// note that this function doen't check for updated data and just uploads everything.
    pub fn updateUniforms(self: *Self, comptime T: type) !void {
        const tinfo = @typeInfo(T);
        if (tinfo != .@"struct") @compileError("Attempt to use a non struct type, Uniforms must be of struct type!");

        const info = tinfo.@"struct";
        const uniforms: *T = @ptrCast(@alignCast(self.uniforms.ptr));

        inline for (info.fields) |field| {
            try self.setUniform(field.name, @field(uniforms.*, field.name));
        }
    }

    /// sets the `uniform` variable as the shader's uniforms.
    /// supports recursion as well.
    /// This function does not update the uniform blob which may cause conflicts so make sure to update it manually.
    pub fn setUniform(self: *const Self, name: []const u8, uniform: anytype) !void {
        const info = @typeInfo(@TypeOf(uniform));
        const location = c.glGetUniformLocation(self.id, name.ptr);
        std.debug.print("{s}\n", .{ name });
        if (location == -1 and info != .@"struct" and info != .array) return error.UniformDoesntExist;

        switch (info) {
            inline .int => |i|
                if (i.signedness == .signed) c.glUniform1i(location, uniform)
                else c.glUniform1ui(location, uniform)
            ,
            inline .float => c.glUniform1f(location, uniform),
            inline .bool => c.glUniform1i(location, @intFromBool(uniform)),
            inline .vector => |v| {
                switch (@typeInfo(v.child)) {
                    inline .int => switch (v.len) {
                        inline 1 => c.glUniform1iv(location, 1, z.arrNPtr(&uniform)),
                        inline 2 => c.glUniform2iv(location, 1, z.arrNPtr(&uniform)),
                        inline 3 => c.glUniform3iv(location, 1, z.arrNPtr(&uniform)),
                        inline 4 => c.glUniform4iv(location, 1, z.arrNPtr(&uniform)),
                        inline else => @compileError("fouck"),
                    },
                    inline .float => switch (v.len) {
                        inline 1 => c.glUniform1fv(location, 1, z.arrNPtr(&uniform)),
                        inline 2 => c.glUniform2fv(location, 1, z.arrNPtr(&uniform)),
                        inline 3 => c.glUniform3fv(location, 1, z.arrNPtr(&uniform)),
                        inline 4 => c.glUniform4fv(location, 1, z.arrNPtr(&uniform)),
                        inline else => @compileError("fouck 2"),
                    },
                    inline else => return error.UnsupportedVectorType
                }
            },
            inline .@"struct" => |s| {
                inline for (s.fields) |field| {
                    const label = try std.mem.concat(self.allocator, u8, &[_][]const u8{ name, ".", field.name });
                    defer self.allocator.free(label);
                    try self.setUniform(label, @field(uniform, field.name));
                }
            },
            inline .array => |a| {
                const child = @typeInfo(a.child);
                if (child == .vector) {
                    switch (a.len) {
                        inline 2 => c.glUniformMatrix2fv(location, 1, 0, z.arrNPtr(&uniform)),
                        inline 3 => c.glUniformMatrix3fv(location, 1, 0, z.arrNPtr(&uniform)),
                        inline 4 => c.glUniformMatrix4fv(location, 1, 0, z.arrNPtr(&uniform)),
                        inline else => @compileError("fouck 2"),
                    }
                } else {
                    for (0..a.len) |i| {
                        const label = try std.mem.concat(self.allocator, u8, &[_][]const u8{ name, "[", std.fmt.digits2(i, .lower), "]" });
                        defer self.allocator.free(label);
                        try self.setUniform(label, uniform[i]);
                    }
                }
            },
            inline else => return error.UnsupportedType
        }
    }

    /// returns a pointer to the uniform blob of this shader.
    /// use `updateUniforms` to update gpu data from this blob.
    pub fn uniformPtr(self: Self, comptime T: type) *T {
        return @ptrCast(@alignCast(self.uniforms.ptr));
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.uniforms);
        c.glDeleteProgram(self.id);
    }
};

pub const ShaderConfig = struct {
    /// vertex shader file path
    vertex: []const u8,
    /// fragment shader file path
    fragment: []const u8,
    /// geometry shaders
    geometry: ?[]const []const u8 = null,
};

/// Container for all shaders in a program.
/// Shaders inside this struct can be referenced by external components.
/// TODO: support precompiled shaders
/// TODO: support hot reloading
pub const ShaderManager = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    tags: std.StringHashMap(usize),
    shaders: std.ArrayList(Shader),
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .tags = .init(allocator),
            .shaders = .empty,
        };
    }

    /// Create a shader programs using files specified by `config` and uniform data of type `T`.
    pub fn create(self: Self, comptime T: type, config: ShaderConfig) !*Shader {
        const shader = try Shader.init(self.allocator, self.io, T, config);
        try self.shaders.append(self.allocator.*, shader);
    }

    /// Create a shader programs using files specified by `config` and uniform data of type `T`.
    /// The shader can be queried using the specified label.
    pub fn createTagged (self: Self, label: []const u8, config: ShaderConfig) !*Shader {
        const shader = try self.createShader(config);
        self.tags.put(label, shader - self.shaders.items.ptr);
        return shader;
    }

    pub fn get(self: Self, label: []const u8) ?*Shader {
        const idx = self.tags.get(label) orelse return null;
        return self.shaders[idx];
    }

    pub fn deinit (self: *Self) void {
        for (self.shaders.items) |shader| {
            shader.deinit();
        }

        self.shaders.deinit(self.allocator);
        self.tags.deinit();
    }
};
