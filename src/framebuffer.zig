const std = @import("std");

const c = @import("deps/glad.zig");
const w = @import("deps/glfw3.zig");

const Texture2D = @import("assets.zig").Texture2D;

/// A rendering target, may output to a RenderBuffer or a Texture
/// TODO: allow selecting buffer types explicitly
pub const FrameBuffer = struct {
    const Self = @This();
    id: u32,
    /// we only use a depth buffer for now
    depth_buffer: RenderBuffer,
    color_buffer: Texture2D,

    pub fn init(depth: RenderBuffer, color: Texture2D) !Self {
        var id: u32 = undefined;

        c.glGenFramebuffers(1, &id);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, id);
        defer c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);

        c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depth.id);
        c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, color.id, 0);

        const status = c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER);

        if (status != c.GL_FRAMEBUFFER_COMPLETE) return error.FuckFailedToCreateFrameBuffer;


        return .{ .id = id, .depth = depth, .color = color };
    }

    pub fn bind(self: Self) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.id);
    }

    pub fn deinit(self: Self) void {
        c.glDeleteFramebuffers(1, &self.id);
    }
};

/// This is used by FrameBuffers internally for depth/stencil buffers 
/// Not a part of the High-Level API
/// use with caution
pub const RenderBuffer = struct {
    const Self = @This();
    id: u32,
    
    pub fn init(width: u32, height: u32) Self {
        var id: u32 = undefined;

        c.glGenRenderbuffers(1, &id);
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, id);
        defer c.glBindRenderbuffer(c.GL_RENDERBUFFER, 0);
        c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT, width, height);


        return .{ .id = id };
    }

    pub fn bind (self: Self) void {
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, self.id);
    }

    pub fn deinit(self: Self) void {
        c.glDeleteRenderbuffers(1, &self.id);
    }

};

pub const RenderBufferType = enum (i32) {
    DepthBuffer = c.GL_DEPTH_COMPONENT,
    ColorBuffer = c.GL_RGBA8,
    /// unused for now because I don't need it!!
    StencilBuffer = unreachable,
};
