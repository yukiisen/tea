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
    target: z.Vec,
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

    pub fn Default2D(window: *Window, pos: Vec) Self {
        var cam: Self = .{
            .bounds = .{ @as(f32, @floatFromInt(window.width)), @as(f32, @floatFromInt(window.height)), 0.1, 1 },
            .position = pos.value,
            .target = pos.value - z.Vec{ 0, 0, 1, 0 },
            .up = z.Vec{ 0, 1, 0, 0 },
            .fov = 0,
            .projection = .Orthogonal
        };

        cam.calculateMatrices();

        return cam;
    }

    pub fn Default3D(window: *Window, pos: Vec) Self {
        var cam: Self = .{
            .bounds = .{ @as(f32, @floatFromInt(window.width)), @as(f32, @floatFromInt(window.height)), 0.1, 1 },
            .position = pos.value,
            .target = pos.value - z.Vec{ 0, 0, 1, 0 },
            .up = z.Vec{ 0, 1, 0, 0 },
            .fov = 45,
            .projection = .Perspective
        };

        cam.calculateMatrices();

        return cam;
    }

    pub fn calculateMatrices(self: *Self) void {
        self.view = self.getViewMatrix();
        self.proj = self.getProjectionMatrix();

        self.matrix = z.mul(self.proj, self.view);
    }

    pub fn moveTo(self: *Self, pos: Vec) void {
        self.position = pos.value;
        self.target = pos.value + self.getDirection();
    }

    pub inline fn getDirection(self: *Self) z.Vec {
        return (self.target - self.position);
    }

    pub inline fn getViewMatrix (self: Self) z.Mat {
        return z.lookAtRh(self.position, self.target, self.up);
    }

    pub inline fn getProjectionMatrix (self: Self) z.Mat {
        if (self.projection == .Orthogonal)
            return z.orthographicRh(self.bounds[0], self.bounds[1], self.bounds[2], self.bounds[3])
        else 
            return z.perspectiveFovRhGl(std.math.degreesToRadians(self.fov), self.bounds[0] / self.bounds[1], self.bounds[2], self.bounds[3]);
    }
};

pub const CameraProjection = enum {
    Orthogonal,
    Perspective,
};
