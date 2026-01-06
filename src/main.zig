const std = @import("std");
const sekai = @import("sekai");

const HentaiMap = struct {
    hentai: u32
};

const HentaiMap2 = struct {
    hentai: u32
};

pub fn main() !void { 
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    var allocator = gpa.allocator();

    var app = sekai.Sekai.init(&allocator);
    defer app.deinit();

    // try app.addResource(HentaiMap, .{ .hentai = 2 });
    // try app.addResource(HentaiMap2, .{ .hentai = 2*3 });
    // const hentai = app.fgetResource(HentaiMap2);

    // try app.spawn(.{ HentaiMap { .hentai = 1 }, HentaiMap2 { .hentai = 2 } });

    var t = app.query(struct { HentaiMap2, HentaiMap });

    const p = t.next();
    _ = p;

    // @compileLog(@typeName(@TypeOf(p.@"0")));

    // std.debug.print("hentai = {any}\n", .{hentai.hentai});
}
