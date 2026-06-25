const std = @import("std");
const gl = @import("zopengl").bindings;

pub fn glError(err: gl.Enum) !void {
    return switch (err) {
        gl.NO_ERROR => {},
        gl.INVALID_ENUM => error.InvalidEnum,
        gl.INVALID_VALUE => error.InvalidValue,
        gl.INVALID_OPERATION => error.InvalidOperation,
        gl.OUT_OF_MEMORY => error.OutOfMemory,
        gl.STACK_OVERFLOW => error.StackOverflow,
        gl.STACK_UNDERFLOW => error.StackUnderflow,
        gl.INVALID_FRAMEBUFFER_OPERATION => error.InvalidFramebufferOperation,
        else => {} 
    };
}
