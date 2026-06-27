const zm = @import("zmath");

/// zmath Vec wrapper so callers write `Vec.vec2(x, y)` instead of zmath's `.{x, y, 0, 1}`.
pub const Vec = struct {
    const Self = @This();
    value: zm.Vec,

    pub const origin: Self = .vec(0);

    /// splats the value
    pub fn vec(v: f32) Self {
        return .{ .value = @splat(v) };
    }

    /// returns .{ x, y, 0, 1 }
    pub fn vec2(x: f32, y: f32) Self {
        return .{ .value = .{ x, y, 0, 1 }};
    }

    /// returns .{ x, y, z, 1 }
    pub fn vec3(x: f32, y: f32, z: f32) Self {
        return .{ .value = .{ x, y, z, 1 }};
    }

    pub fn vec4(x: f32, y: f32, z: f32, w: f32) Self {
        return .{ .value = .{ x, y, z, w }};
    }

    pub fn fromVal(value: zm.Vec) Self {
        return .{ .value = value };
    }
};

