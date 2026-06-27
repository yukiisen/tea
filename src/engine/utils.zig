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


pub inline fn loadFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);

    const stat = try file.stat(io);
    const buf = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(buf);

    _ = try file.readPositionalAll(io, buf, 0); // this should return fragstat.size but I won't check it right now.

    return buf;
}
