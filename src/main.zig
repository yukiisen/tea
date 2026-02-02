const std = @import("std");
const sekai = @import("sekai");
const osu = @import("osu.zig");

const z = @import("zmath");

pub fn main() !void { 
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.print("No leaks: {any}\n", .{gpa.deinit() == .ok});
    const allocator = gpa.allocator();

    const bmp = try osu.loadBeatMapFromFile(std.Io.Threaded.global_single_threaded.io(), allocator, "/home/yuki/tmp/mania/t+pazolite - QZKago Requiem (keksikosu) [APOL'S ANOTHER].osu");


    allocator.free(bmp.buffer);
}
