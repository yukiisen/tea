const std = @import("std");
const z = @import("zmath");

const engine = @import("../engine/root.zig");
const Window = engine.Window;
const Vec = @import("utils.zig").Vec;

/// A camera object, it can be used as 3D or 2D camera depending on the configuration
pub const Camera = struct {
    const Self = @This();

    /// screen bounds: width, height, near, far
    bounds: z.Vec,
    position: z.Vec,
    /// direction in which the camera is looking
    direction: z.Vec,
    /// arbitrary up vector
    up: z.Vec,
    fov: f32,
    projection: CameraProjection,

    /// check `Camera.calculateMatrices`
    view: z.Mat = z.identity(),
    /// check `Camera.calculateMatrices`
    proj: z.Mat = z.identity(),
    /// check `Camera.calculateMatrices`
    matrix: z.Mat = z.identity(),

    pub fn init2D(window: *Window, pos: Vec) Self {
        var cam: Self = .{
            .bounds = .{ window.width, window.height, 0.1, 100 },
            .position = pos.value,
            .direction = z.Vec{ 0, 0, -1, 0 },
            .up = z.Vec{ 0, 1, 0, 0 },
            .fov = 0,
            .projection = .Orthogonal
        };

        cam.calculateMatrices();

        return cam;
    }

    pub fn init3D(window: *Window, pos: Vec) Self {
        var cam: Self = .{
            .bounds = .{ window.width, window.height, 0.1, 100 },
            .position = pos.value,
            .direction = z.Vec{ 0, 0, -1, 0 },
            .up = z.Vec{ 0, 1, 0, 0 },
            .fov = 45,
            .projection = .Perspective
        };

        cam.calculateMatrices();

        return cam;
    }

    pub fn setBounds(self: *Self, window: *const Window) void {
        self.bounds[0] = window.width;
        self.bounds[1] = window.height;
        self.calculateMatrices();
    }

    pub fn calculateMatrices(self: *Self) void {
        self.view = self.getViewMatrix();
        self.proj = self.getProjectionMatrix();

        self.matrix = z.mul(self.proj, self.view);
    }

    pub fn moveTo(self: *Self, pos: Vec) void {
        self.position = pos.value;
        self.calculateMatrices();
    }

    pub fn moveBy(self: *Self, pos: Vec) void {
        self.position += pos.value;
        self.calculateMatrices();
    }

    pub inline fn getViewMatrix (self: Self) z.Mat {
        return z.lookAtRh(self.position, self.position + self.direction, self.up);
    }

    pub inline fn getProjectionMatrix (self: Self) z.Mat {
        return switch (self.projection) {
            .Orthogonal => z.orthographicRh(self.bounds[0], self.bounds[1], self.bounds[2], self.bounds[3]),
            .Perspective => z.perspectiveFovRhGl(std.math.degreesToRadians(self.fov), self.bounds[0] / self.bounds[1], self.bounds[2], self.bounds[3]),
        };
    }
};

pub const CameraProjection = enum {
    Orthogonal,
    Perspective,
};
