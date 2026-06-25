const std = @import("std");

const gl = @import("zopengl").bindings;
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

    /// TODO: convert into a generic implementation
    pub fn init(allocator: std.mem.Allocator, io: std.Io, comptime T: type, config: ShaderConfig) !Self {
        const vertex_source = try loadFile(allocator, io, config.vertex);
        defer allocator.free(vertex_source);

        const fragment_source = try loadFile(allocator, io, config.fragment);
        defer allocator.free(fragment_source);

        const vertex = try compileShader(gl.VERTEX_SHADER, vertex_source);
        defer gl.deleteShader(vertex);

        const fragment = try compileShader(gl.FRAGMENT_SHADER, fragment_source);
        defer gl.deleteShader(fragment);
        
        var geometry_shaders: []u32 = &.{};

        if (config.geometry) |files| {
            geometry_shaders = try allocator.alloc(u32, files.len);
            errdefer allocator.free(geometry_shaders);

            for (files, 0..) |file, i|  {
                const source = try loadFile(allocator, io, file);
                defer allocator.free(source);
                geometry_shaders[i] = try compileShader(gl.GEOMETRY_SHADER, source);
            }
        }

        defer if (config.geometry != null) allocator.free(geometry_shaders); // free when done
        defer for (geometry_shaders) |s| gl.deleteShader(s);

        const program = gl.createProgram();
        errdefer gl.deleteProgram(program);

        gl.attachShader(program, vertex);
        gl.attachShader(program, fragment);

        for (geometry_shaders) |shader| {
            gl.attachShader(program, shader);
        }

        gl.linkProgram(program);

        var success: i32 = 0;
        var info: [512]u8 = undefined;

        gl.getProgramiv(program, gl.LINK_STATUS, &success);

        if (success == 0) {
            gl.getProgramInfoLog(program, @sizeOf(@TypeOf(info)), null, &info);
            std.log.err("Error: during shader program linking:\n{s}\n", .{ info });
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

    inline fn loadFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
        defer file.close(io);

        const stat = try file.stat(io);
        const buf = try allocator.alloc(u8, stat.size);
        errdefer allocator.free(buf);

        _ = try file.readPositionalAll(io, buf, 0); // this should return fragstat.size but I won't check it right now.

        return buf;
    }

    inline fn compileShader (shadertype: u32, source: []const u8) !u32 {
        var info: [512]u8 = undefined;
        var success: i32 = 0;
        
        const shader = gl.createShader(shadertype);
        gl.shaderSource(shader, 1, &source.ptr, @ptrCast(&source.len));
        gl.compileShader(shader);
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
        
        if (success == 0) {
            gl.getShaderInfoLog(shader, @sizeOf(@TypeOf(info)), null, &info);
            std.log.err("Error: during shader compilation:\n{s}\n", .{ info });
            return error.ShaderCompilationFailed;
        }

        return shader;
    }

    pub fn use(self: *const Self) void {
        gl.useProgram(self.id);
    }

    /// updates uniforms based on `T` and the values of `self.uniformPtr()`
    /// note that this function doen't check for updated data and just uploads everything.
    pub fn updateUniforms(self: *const Self, comptime T: type) !void {
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
        const location = gl.getUniformLocation(self.id, name.ptr);
        if (location == -1 and info != .@"struct" and info != .array) return error.UniformDoesntExist;

        switch (info) {
            inline .int => |i|
                if (i.signedness == .signed) gl.uniform1i(location, uniform)
                else gl.uniform1ui(location, uniform)
            ,
            inline .comptime_int => gl.uniform1i(location, @intCast(uniform)),
            inline .float, .comptime_float => gl.uniform1f(location, uniform),
            inline .bool => gl.uniform1i(location, @intFromBool(uniform)),
            inline .vector => |v| {
                switch (@typeInfo(v.child)) {
                    inline .int => switch (v.len) {
                        inline 1 => gl.uniform1iv(location, 1, z.arrNPtr(&uniform)),
                        inline 2 => gl.uniform2iv(location, 1, z.arrNPtr(&uniform)),
                        inline 3 => gl.uniform3iv(location, 1, z.arrNPtr(&uniform)),
                        inline 4 => gl.uniform4iv(location, 1, z.arrNPtr(&uniform)),
                        inline else => @compileError("fouck"),
                    },
                    inline .float => switch (v.len) {
                        inline 1 => gl.uniform1fv(location, 1, z.arrNPtr(&uniform)),
                        inline 2 => gl.uniform2fv(location, 1, z.arrNPtr(&uniform)),
                        inline 3 => gl.uniform3fv(location, 1, z.arrNPtr(&uniform)),
                        inline 4 => gl.uniform4fv(location, 1, z.arrNPtr(&uniform)),
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
                        inline 2 => gl.uniformMatrix2fv(location, 1, 0, z.arrNPtr(&uniform)),
                        inline 3 => gl.uniformMatrix3fv(location, 1, 0, z.arrNPtr(&uniform)),
                        inline 4 => gl.uniformMatrix4fv(location, 1, 0, z.arrNPtr(&uniform)),
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
        gl.deleteProgram(self.id);
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

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Self {
        return .{
            .allocator = allocator,
            .tags = .init(allocator),
            .shaders = .empty,
            .io = io,
        };
    }

    /// Create a shader programs using files specified by `config` and uniform data of type `T`.
    pub fn create(self: *Self, comptime T: type, config: ShaderConfig) !Shader {
        const shader = try Shader.init(self.allocator, self.io, T, config);
        try self.shaders.append(self.allocator, shader);

        return shader;
    }

    /// Create a shader programs using files specified by `config`.
    pub fn createUntyped(self: *Self, config: ShaderConfig) !Shader {
        const shader = try Shader.init(self.allocator, self.io, struct {}, config);
        try self.shaders.append(self.allocator, shader);

        return shader;
    }

    /// Create a shader programs using files specified by `config` and uniform data of type `T`.
    /// The shader can be queried using the specified label.
    pub fn createTagged (self: *Self, T: type, label: []const u8, config: ShaderConfig) !Shader {
        const shader = try self.create(T, config);
        try self.tags.put(label, self.shaders.items.len - 1);

        return shader;
    }

    pub fn get(self: *const Self, label: []const u8) ?Shader {
        const idx = self.tags.get(label) orelse return null;
        return self.shaders.items[idx];
    }

    pub fn deinit (self: *Self) void {
        for (self.shaders.items) |shader| {
            shader.deinit();
        }

        self.shaders.deinit(self.allocator);
        self.tags.deinit();
    }
};
