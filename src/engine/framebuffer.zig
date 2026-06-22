const std = @import("std");

const gl = @import("zopengl").bindings;

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

        gl.genFramebuffers(1, &id);
        gl.bindFramebuffer(gl.FRAMEBUFFER, id);
        defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depth.id);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, color.id, 0);

        const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

        if (status != gl.FRAMEBUFFER_COMPLETE) return error.FuckFailedToCreateFrameBuffer;

        return .{ .id = id, .depth_buffer = depth, .color_buffer = color };
    }

    pub fn bind(self: Self) void {
        gl.bindFramebuffer(gl.FRAMEBUFFER, self.id);
    }

    pub fn deinit(self: Self) void {
        self.depth_buffer.deinit();
        self.color_buffer.deinit();
        gl.deleteFramebuffers(1, &self.id);
    }
};

/// This is used by FrameBuffers internally for depth/stencil buffers 
/// Not a part of the High-Level API
/// use with caution
pub const RenderBuffer = struct {
    const Self = @This();
    id: u32,
    
    pub fn init(width: i32, height: i32) Self {
        var id: u32 = undefined;

        gl.genRenderbuffers(1, &id);
        gl.bindRenderbuffer(gl.RENDERBUFFER, id);
        defer gl.bindRenderbuffer(gl.RENDERBUFFER, 0);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, width, height);

        return .{ .id = id };
    }

    pub fn bind (self: Self) void {
        gl.bindRenderbuffer(gl.RENDERBUFFER, self.id);
    }

    pub fn deinit(self: Self) void {
        gl.deleteRenderbuffers(1, &self.id);
    }
};

pub const RenderBufferType = enum (i32) {
    DepthBuffer = gl.DEPTH_COMPONENT,
    ColorBuffer = gl.RGBA8,
    /// unused for now because I don't need it!!
    StencilBuffer = unreachable,
};
