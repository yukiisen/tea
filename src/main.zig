const std = @import("std");
const sekai = @import("sekai");
const osu = @import("osu.zig");

const z = @import("zmath");

pub fn main() !void { 
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer std.debug.print("No leaks: {any}\n", .{gpa.deinit() == .ok});
    const allocator = gpa.allocator();

    var bmp = try osu.loadBeatMapFromFile(std.Io.Threaded.global_single_threaded.io(), allocator, "/home/yuki/tmp/mania/t+pazolite - QZKago Requiem (keksikosu) [APOL'S ANOTHER].osu");
    // var bmp = try osu.loadBeatMapFromFile(std.Io.Threaded.global_single_threaded.io(), allocator, "/home/yuki/tmp/docci/Nakiri Ayame - Docchi Docchi no Uta (RiP46) [Hard].osu");

    defer bmp.deinit(allocator);
    std.debug.print("{s}\n", .{ bmp.events.items[0].Background.filename });
}
