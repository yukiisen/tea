const std = @import("std");

const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const gl_loader = zopengl;
const w = @import("deps/glfw3.zig").w;
const z = @import("zmath");

const FrameBuffer = @import("framebuffer.zig").FrameBuffer;
const RenderBuffer = @import("framebuffer.zig").RenderBuffer;
const Texture2D = @import("assets.zig").Texture2D;
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;

/// A wrapper over GLFW's Window object
pub const Window = struct {
    const Self = @This();

    window: *w.GLFWwindow,
    mode: WindowMode = .Windowed,
    vsync: bool = false,
    width: i32,
    height: i32,

    /// creates a GLFW window with the specified attributes.
    /// Additional windows will share the same resources with the first created window.
    /// TODO: add proper error handling
    /// TODO: allow the user to separate window contexts.
    pub fn init (width: i32, height: i32, title: []const u8) !Self {
        if (w.glfwInit() == w.GLFW_FALSE) return error.FuckGLFWBroken;

        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MAJOR, 3);
        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MINOR, 3);
        w.glfwWindowHint(w.GLFW_OPENGL_PROFILE, w.GLFW_OPENGL_CORE_PROFILE);

        const context = w.glfwGetCurrentContext(); // get the current window so we can attach to it (or null if this is first)
        const window = w.glfwCreateWindow(width, height, title.ptr, null, context) 
            orelse return error.FuckWindowBroken;
        
        _ = w.glfwSetFramebufferSizeCallback(window, winresize);

        if (context == null) w.glfwMakeContextCurrent(window); // first window is used as current context

        return .{
            .window = window,
            .width = width,
            .height = height
        };
    }

    /// used to set the window struct as a UserPointer.
    /// it's automatically called during setup, don't touch.
    /// this is separated from the init function because it needs a pointer to self (Window) which will likely change whenever you move the struct around.
    /// TODO: find a safer way to implement this.
    pub fn prepare (self: *Self) void {
        w.glfwSetWindowUserPointer(self.window, self);
    }

    /// window resize global callback.
    fn winresize(window: ?*w.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
        const s: ?*Self = @ptrCast(@alignCast(w.glfwGetWindowUserPointer(window))); 
        // don't crash if prepare was not called
        if (s) |self| { 
            self.*.width = width;
            self.*.height = height;
        }
        gl.viewport(0, 0, width, height);
    }
    
    pub fn deinit(self: *Self) void {
        w.glfwDestroyWindow(self.window);
        w.glfwTerminate();
    }

    pub fn close(self: Self) void {
        w.glfwSetWindowShouldClose(self.window, 1);
    }

    /// returns the close flag of the window
    pub fn shouldClose(self: Self) bool {
        return w.glfwWindowShouldClose(self.window) != 0;
    }

    /// Changes the CurrentContext to this window.
    pub fn setMainContext (self: Self) void {
        w.glfwMakeContextCurrent(self.window);
    }

    /// Changes window mode between FullScreen/Windowed
    /// Asserts that a monitor exists
    pub fn setWindowMode (self: *Self, mode: WindowMode) void {
        if (self.mode == mode) return;
        const monitor = w.glfwGetPrimaryMonitor().?;
        const width, const height = self.getSize();

        switch (mode) {
            .Windowed => w.glfwSetWindowMonitor(self.window, null, 0, 0, width, height, 0), // separate window and monitor
            .Borderless => {
                const video_mode = w.glfwGetVideoMode(monitor).?.*; // use monitor dimentions
                w.glfwSetWindowMonitor(self.window, monitor, 0, 0, video_mode.width, video_mode.height, video_mode.refreshRate);
                self.width = video_mode.width;
                self.height = video_mode.height;
            },
            .FullScreen => w.glfwSetWindowMonitor(self.window, monitor, 0, 0, width, height, 60), // make monitor follow window
        }

        self.mode = mode;
    }

    pub fn setTitle(self: Self, title: []const u8) void {
        w.glfwSetWindowTitle(self.window, title.ptr);
    }

    pub fn getSize (self: Self) @Tuple(&.{ i32, i32 }) {
        var width: i32 = 0;
        var height: i32 = 0;
        w.glfwGetFramebufferSize(self.window, &width, &height);

        return .{ width, height };
    }

    /// updates the window content from the FrameBuffer and polls new events.
    pub fn swapBuffers(self: Self) void {
        w.glfwSwapBuffers(self.window);
        w.glfwPollEvents();
    }

    pub fn setVSync(self: *Self, value: bool) void {
        self.vsync = value;
        w.glfwSwapInterval(@intFromBool(value));
    }

    pub fn bindFrameBuffer(_: Self) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
    }
};

pub const WindowMode = enum {
    Windowed,
    Borderless,
    FullScreen
};

/// A renderer is responsible of managing framebuffers and rendering commands
/// All GPU communication except data loading should be abstracted here for easier encapsulation
/// This struct is safe to copy around.
pub const Renderer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    framebuffers: std.ArrayList(FrameBuffer),

    /// Init OpenGL and load all relevant functions
    /// This will burn if you create it before creating at least one window
    pub fn init(allocator: std.mem.Allocator) !Self {
        const loader: zopengl.LoaderFn = @ptrCast(&w.glfwGetProcAddress);
        try gl_loader.loadCoreProfile(loader, 4, 2);

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.enable(gl.CULL_FACE);
        gl.enable(gl.FRAMEBUFFER_SRGB);

        return .{ .framebuffers = .empty, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.framebuffers.items) |fb| fb.deinit();
        self.framebuffers.deinit(self.allocator);
    }

    pub fn setDepthTest (_: Self, value: bool) void {
        if (value) gl.enable(gl.DEPTH_TEST)
        else gl.disable(gl.DEPTH_TEST);
    }

    pub fn setStencilTest (_: Self, value: bool) void {
        if (!value) gl.disable(gl.STENCIL_TEST)
        else gl.enable(gl.STENCIL_TEST);
    }

    pub fn setBlending (_: Self, value: bool) void {
        if (!value) gl.disable(gl.BLEND)
        else gl.enable(gl.BLEND);
    }

    pub fn useShader(_: Self, shader: *const Shader) void {
        gl.useProgram(shader.id);
    }

    pub fn clearFrame(_: Self, color: @Vector(4, f32)) void {
        gl.clearColor(color[0], color[1], color[2], color[3]);
        const mask = gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT | gl.DEPTH_BUFFER_BIT;
        gl.clear(@intCast(mask));
    }

    pub fn drawMesh(self: Self, mesh: *const Mesh, shader: *const Shader, mode: DrawMode) void {
        self.useShader(shader);
        mesh.bind();

        if (mesh.indexed) gl.drawElements(@intFromEnum(mode), mesh.count, gl.UNSIGNED_INT, null)
        else gl.drawArrays(@intFromEnum(mode), 0, mesh.count);
    }

    /// creates a framebuffer with the same size as `window`.
    /// The resulting framebuffer will then be saved into the renderer's framebuffers array.
    pub fn createFramebuffer(self: *Self, size: [2]i32) !FrameBuffer {
        const depth = RenderBuffer.init(size[0], size[1]);
        errdefer depth.deinit();

        const color = Texture2D.init(.{ 
            .data = @as([*c]u8, null),
            .width = size[0], 
            .height = size[1], 
            .num_components = 3, 
            // unused keys.
            .bytes_per_component = 0,
            .bytes_per_row = 0,
            .is_hdr = false,
        }, false);
        errdefer color.deinit();

        depth.bind();
        color.bind();

        const framebuffer = try FrameBuffer.init(depth, color);

        // framebuffers don't store any state so it's safe to copy them around.
        try self.framebuffers.append(self.allocator, framebuffer);

        return framebuffer;
    }
};

pub const DrawMode = enum (c_uint) {
    Points = @as(c_uint, 0x0000),
    Lines = @as(c_uint, 0x0001),
    LineLoop = @as(c_uint, 0x0002),
    LineStrip = @as(c_uint, 0x0003),
    Triangles = @as(c_uint, 0x0004),
    TriangleStrip = @as(c_uint, 0x0005),
    TriangleFan = @as(c_uint, 0x0006),
};

