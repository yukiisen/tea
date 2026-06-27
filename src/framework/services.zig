const std = @import("std");

const ServiceId = u64;

fn getServiceId(comptime T: type) ServiceId {
    return comptime std.hash.Wyhash.hash(0, @typeName(T));
}

pub const Service = struct {
    const Self = @This();

    ptr: *anyopaque,
    deinitfn: *const fn(*anyopaque, std.mem.Allocator) void,

    /// services registered using this areautomatically deinitialized and freed via the deinit method.
    pub fn init(ptr: anytype, comptime managed: bool) Self {
        const service = std.meta.Child(@TypeOf(ptr));

        return .{
            .ptr = ptr,
            .deinitfn = struct {
                fn f(p: *anyopaque, allocator: std.mem.Allocator) void {
                    const instance: *service = @ptrCast(@alignCast(p));
                    if (@hasDecl(service, "deinit")) instance.deinit();

                    if (managed) allocator.destroy(instance);
                }
            }.f,
        };
    }

    pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
        self.deinitfn(self.ptr, gpa);
    }
};

pub const ServiceManager = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    store: std.AutoHashMap(ServiceId, Service),

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{
            .gpa = gpa,
            .store = .init(gpa),
        };
    }

    /// TODO: handle clobbers
    pub fn register(self: *Self, service: anytype) !void {
        const T = @TypeOf(service);
        const info = @typeInfo(T);

        if (info == .pointer) return self.store.put(getServiceId(std.meta.Child(T)), .init(service, false));

        const instance = try self.gpa.create(T);
        instance.* = service;

        try self.store.put(getServiceId(T), .init(instance, true));
    }

    pub fn get(self: *const Self, comptime T: type) ?*T {
        const service = self.store.get(getServiceId(T)) orelse return null;
        return @ptrCast(@alignCast(service.ptr));
    }

    pub fn remove(self: *Self, comptime T: type) void {
        const service = self.store.get(getServiceId(T)) orelse return;
        service.deinit(self.gpa);
        _ = self.store.remove(getServiceId(T));
    }

    pub fn deinit(self: *Self) void {
        var it = self.store.valueIterator();

        while (it.next()) |service| {
            service.deinit(self.gpa);
        }

        self.store.deinit();
    }
};
