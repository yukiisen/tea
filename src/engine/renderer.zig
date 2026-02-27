const std = @import("std");

const c = @import("deps/glad.zig");
const w = @import("deps/glfw3.zig");
const z = @import("zmath");

const FrameBuffer = @import("framebuffer.zig").FrameBuffer;
const RenderBuffer = @import("framebuffer.zig").RenderBuffer;
const Texture2D = @import("assets.zig").Texture2D;
const Shader = @import("shader.zig").Shader;
const Mesh = @import("components.zig").Mesh;

// resources
/// A window object is an extension over `FrameBuffer`.
/// It's a wrapper over GLFW's Window object
/// This struct is safe to copy around.
pub const Window = struct {
    const Self = @This();

    window: *w.GLFWwindow,
    mode: WindowMode = .Windowed,
    width: i32,
    height: i32,

    /// creates a GLFW window with the specified attributes.
    /// Additional windows will share the same resources with the first created window.
    /// TODO: add proper error handling
    /// TODO: allow the user to separate window contexts.
    pub fn init (width: i32, height: i32, title: []const u8) !Self {
        if (w.glfwInit() == w.GLFW_FALSE) return error.FuckWindowBroke;

        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MAJOR, 3);
        w.glfwWindowHint(w.GLFW_CONTEXT_VERSION_MINOR, 3);
        w.glfwWindowHint(w.GLFW_OPENGL_PROFILE, w.GLFW_OPENGL_CORE_PROFILE);

        const context = w.glfwGetCurrentContext();
        const window = w.glfwCreateWindow(width, height, title.ptr, null, context).?; // assert for now
        
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
        c.glViewport(0, 0, width, height);
    }
    
    pub fn deinit(self: *Self) void {
        w.glfwDestroyWindow(self.window);
        w.glfwTerminate();
    }

    pub fn close(self: Self) void {
        w.glfwSetWindowShouldClose(self.window, 1);
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
                const video_mode = w.glfwGetVideoMode(monitor).?; // use monitor dimentions
                w.glfwSetWindowMonitor(self.window, monitor, 0, 0, video_mode.*.width, video_mode.*.height, video_mode.*.refreshRate);
                self.width = video_mode.*.width;
                self.height = video_mode.*.height;
            },
            .FullScreen => w.glfwSetWindowMonitor(self.window, monitor, 0, 0, width, height, 60), // make monitor follow window
        }

        self.*.mode = mode;
    }

    pub fn setTitle(self: Self, title: []const u8) void {
        w.glfwSetWindowTitle(self.window, title.ptr);
    }

    pub fn getSize (self: Self) @Vector(2, i32) {
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

    pub fn useFrameBuffer(_: Self) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    /// returns the close flag of the window
    pub fn shouldClose(self: Self) bool {
        return w.glfwWindowShouldClose(self.window) != 0;
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
        if (c.gladLoadGLLoader(@ptrCast(&w.glfwGetProcAddress)) == c.GL_FALSE) {
            return error.FuckGLBurned;
        }

        c.glEnable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_BLEND);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_FRAMEBUFFER_SRGB);

        return .{ .framebuffers = .empty, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.framebuffers.items) |fb| fb.deinit();
        self.framebuffers.deinit(self.allocator);
    }

    pub fn disableDepthTest (_: Self) void {
        c.glDisable(c.GL_DEPTH_TEST);
    }

    pub fn enableDepthTest (_: Self) void {
        c.glEnable(c.GL_DEPTH_TEST);
    }

    pub fn disableStencilTest (_: Self) void {
        c.glDisable(c.GL_STENCIL_TEST);
    }

    pub fn enableStencilTest (_: Self) void {
        c.glEnable(c.GL_STENCIL_TEST);
    }

    pub fn disableBlending (_: Self) void {
        c.glDisable(c.GL_BLEND);
    }

    pub fn enableBlending (_: Self) void {
        c.glEnable(c.GL_BLEND);
    }

    pub fn useShader(_: Self, shader: *const Shader) void {
        c.glUseProgram(shader.id);
    }

    pub fn clearFrame(_: Self, color: [4]f32) void {
        c.glClearColor(color[0], color[1], color[2], color[3]);
        const mask = c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT;
        c.glClear(@intCast(mask));
    }

    pub fn drawMesh(self: Self, mesh: *const Mesh, shader: *Shader) void {
        self.useShader(shader);
        mesh.bind();

        if (mesh.indexed) c.glDrawElements(c.GL_TRIANGLES, mesh.count, c.GL_UNSIGNED_INT, null)
        else c.glDrawArrays(c.GL_TRIANGLES, 0, mesh.count);
    }

    /// creates a framebuffer with the same size as `window`.
    /// The resulting framebuffer will then be saved into the renderer's framebuffers array.
    pub fn createFramebuffer(self: *Self, size: [2]u32) !FrameBuffer {
        const depth = RenderBuffer.init(size[0], size[1]);
        const color = Texture2D.init(null, .{ 
            .width = size[0], 
            .height = size[1], 
            .nChannels = 3, 
            .pixelated = false 
        });

        depth.bind();
        color.bind();

        const framebuffer = try FrameBuffer.init(depth, color);

        // framebuffers don't store any state so it's safe to copy them around.
        try self.framebuffers.append(self.allocator, framebuffer);

        return framebuffer;
    }
};

/// A camera object, it can be used as 3D or 2D camera depending on the configuration
pub const Camera = struct {
    const Self = @This();

    /// width, height, near, far
    bounds: z.Vec,
    position: z.Vec,
    target: z.Vec,
    up: z.Vec,
    fov: f32,
    projection: CameraProjection,

    pub inline fn getViewMatrix (self: Self) z.Mat {
        return z.lookAtRh(self.position, self.target, self.up);
    }

    pub inline fn getProjectionMatrix (self: Self) z.Mat {
        return 
        if (self.projection == .Orthognal)
            z.orthographicRh(self.bounds[0], self.bounds[1], self.bounds[2], self.bounds[3])
        else 
            z.perspectiveFovRhGl(self.fov * std.math.pi, self.bounds[0] / self.bounds[1], self.bounds[2], self.bounds[3]);
    }

    pub inline fn getMatrix (self: Self) z.Mat {
        return z.mul(self.getViewMatrix(), self.getProjectionMatrix());
    }
};

pub const CameraProjection = enum {
    Orthognal,
    Perspective,
};
