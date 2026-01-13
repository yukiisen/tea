const std = @import("std");

const ComponentID = struct {
    id: []const u8,
    offset: u32,
};

const ArcheType = struct {
    const Self = @This();
    /// typeid + offset in blob
    components: []ComponentID,
    stride: u32,

    /// blob of component data that is used
    data: std.ArrayList(u8),

    /// TODO: sort component names for faster querying
    pub fn init(allocator: *std.mem.Allocator, comptime T: type) !Self {
        const info = @typeInfo(T);
        // validate stuff
        if (info != .@"struct") @compileError("An archetype must be created with a struct type initializer");

        var components = try allocator.alloc(ComponentID, info.@"struct".fields.len);

        var offset: u32 = 0;
        inline for (info.@"struct".fields, 0..) |field, i| {
            components[i].id = @typeName(field.type);
            components[i].offset = offset;

            offset += @sizeOf(field.type);
        }

        return .{
            .components = components,
            .stride = @sizeOf(T),
            .data = std.ArrayList(u8).empty
        };
    }

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
        allocator.free(self.components);
        self.data.deinit(allocator.*);
    }
};

/// Different events that can be attached to a system to change its triggering time
pub const WorldEvent = enum {
    Setup,
    LineStart,
    LineEnd,
    Update,
    Render,
    Destroy,
};

const SystemHandler = *const fn(*Sekai) void;

/// internal struct for a system
/// this contains essensial data for a function to be executed in the event loop
const System = struct {
    handler: SystemHandler,
    event: WorldEvent,
    line_id: u32
};

/// create a tuple from T that holds pointers instead of values
fn PointerStruct (comptime T: type) type {
    return comptime blk: {
        const t_info = @typeInfo(T);
        if (t_info != .@"struct") @compileError("Attempt to initialize an iterator with a non-struct type");

        const info = t_info.@"struct";

        var types: [info.fields.len]type = undefined;

        for (info.fields, 0..) |f, i| {
            types[i] = *f.type;
        }

        break :blk @Tuple(&types);
    };
}

const CHUNKLEN = 24;

const IterateInfo = struct {
    offsets: [CHUNKLEN]u32,
    stride: u32,
    data: []u8,
};

/// an Iterator's job is to abstract looping through component data that exists on different archetypes (different memory locations)
/// the iterator stores pointers instead of actual data, so any mutation of Sekai (spawning/despawning any components) will lead to illegal behavior and should be avoided
pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        /// index in archetypes array
        t_idx: usize = 0,
        /// per ArcheType index
        idx: usize = 0, 
        /// archetypes array length, changing this would lead to undefind behavior
        a_len: usize = 0, 
        /// each member here contains info for a separate ArcheType.
        archetypes: [CHUNKLEN]IterateInfo = undefined,
        
        /// Access next element in the iterator
        /// Asserts that T is a tuple struct
        pub fn next(self: *Self) ?T {
            if (self.t_idx == self.a_len) return null; // iterator is finished

            const info = @typeInfo(T).@"struct"; // we assert that this is a struct
            const archetype = &self.archetypes[self.t_idx];
            var ret: T = undefined;

            inline for (info.fields, 0..) |f, i| {
                // we access the field using the comptime name and cast the pointer index to the proper type.
                // TODO: find out why this is very unsafe.
                @field(ret, f.name) = @ptrCast(@alignCast(archetype.data.ptr + archetype.stride * self.idx + archetype.offsets[i]));
            }

            self.*.idx += 1;
            
            if (archetype.data.len / archetype.stride <= self.idx) {
                self.*.idx = 0;
                self.*.t_idx += 1;
            }

            return ret;
        }

        /// Moves the iterator back to zero.
        pub fn rollback (self: *Self) void {
            self.*.idx = 0;
            self.*.t_idx = 0;
        }
    };
}

/// The main building block for the ECS
/// Holds all data inside while exposing useful methods to deal with it.
pub const Sekai = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    running: bool = false,

    /// all systems shall be stored here for execution
    systems: std.ArrayList(System) = .empty,
    active_line: u32 = 0,
    /// Stores archetypes for fast queries
    archetypes: std.ArrayList(ArcheType) = .empty,

    /// all bytes from the created resources should live here.
    resources: std.ArrayList(u8) = .empty,

    /// offsets in the `resources` array to which the value should be read from
    /// Maps @typeName to offset
    resource_map: std.StringHashMap(usize),

    pub fn init (allocator: *std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
            .resource_map = std.StringHashMap(usize).init(allocator.*),
        };
    }

    pub fn deinit (self: *Self) void {
        self.systems.deinit(self.allocator.*);
        for (self.archetypes.items) |*archetype| archetype.*.deinit(self.allocator);
        self.archetypes.deinit(self.allocator.*);
        self.resources.deinit(self.allocator.*);
        self.resource_map.deinit();
    }

    /// Start the event loop.
    /// to break the event loop you should set the running flag to false.
    /// TODO: This requires some more optimization since it's slow rn.
    pub fn run(self: *Self) !void {
        self.running = true;
        for (self.systems.items) |system| {
            if (
                system.event == .Setup and
                (system.line_id == self.active_line or system.line_id == 0)
            ) system.handler(self);
        }

        while (self.running) {
            for (self.systems.items) |system| {
                if (
                    system.event == .Update and
                    (system.line_id == self.active_line or system.line_id == 0)
                ) system.handler(self);
            }

            for (self.systems.items) |system| {
                if (
                    system.event == .Render and
                    (system.line_id == self.active_line or system.line_id == 0)
                ) system.handler(self);
            }
        }

        for (self.systems.items) |system| {
            if (
                system.event == .Destroy and
                (system.line_id == self.active_line or system.line_id == 0)
            ) system.handler(self);
        }
    }

    /// Get an Iterator over entities with the components specified in tuple T
    /// if T's number of elements is more than 24 this fundtion will likely segfault at runtime or lead to undefined behavior.
    /// if such problem occurs, increase the CHUNKLEN variable to a higher value
    /// **asserts** that iterator bounds are limited to CHUNKLEN
    pub fn query (self: Self, comptime T: type) Iterator(PointerStruct(T)) {
        const info = @typeInfo(T).@"struct";
        const fields = info.fields;
        var iterator: Iterator(PointerStruct(T)) = .{}; // this will hold all the data for us.
        
        outer: for (self.archetypes.items) |archetype| {
            var iter_info: IterateInfo = .{
                .stride = archetype.stride,
                .data = archetype.data.items,
                .offsets = undefined,
            };

            inline for (fields, 0..) |f, i| {
                if (getFieldOffset(f, archetype.components)) |offset| {
                    std.debug.assert(i < CHUNKLEN);
                    iter_info.offsets[i] = offset;
                } 
                else continue :outer; // if field doen't exist, continue searching
            }

            std.debug.assert(iterator.a_len < CHUNKLEN);
            iterator.archetypes[iterator.a_len] = iter_info;
            iterator.a_len += 1;
        }

        return iterator;
    }

    /// returns the offset of a field in the archetype data blob.
    inline fn getFieldOffset (f: std.builtin.Type.StructField, offsets: []ComponentID) ?u32 {
        for (offsets) |o|  {
            if (std.mem.eql(u8, @typeName(f.type), o.id)) {
                return o.offset;
            }
        }

        return null;
    }

    /// Spawns an entity with the specified component tuple/struct.
    /// This is not doing any assertions as far as I know... maybe..
    pub fn spawn (self: *Self, components: anytype) !void {
        const info = @typeInfo(@TypeOf(components));
        if (info != .@"struct") @compileError("Spawn requires a struct with entity components");

        const fields = comptime info.@"struct".fields;
        
        // search for a fitting archetype or create one
        // this shitty thing could be easilly optimized if I knew how to sort slices
        var archetype: *ArcheType = outer: for (self.archetypes.items) |*archetype| {
                if (archetype.components.len != fields.len) continue;
            
                inline for (fields) |field| {
                    const match: bool = for (archetype.components) |component| {
                        if (std.mem.eql(u8, @typeName(field.type), component.id)) break true; // if field exists in archetype, move to next field
                    } else false;
                    
                    if (!match) continue :outer;
                }

                break archetype;
            } else blk: {
                const t = try ArcheType.init(self.allocator, @TypeOf(components));
                try self.archetypes.append(self.allocator.*, t);
                break :blk &self.archetypes.items[self.archetypes.items.len - 1];
            };

        const bytes: []const u8 = std.mem.asBytes(&components);

        // insert component bytes into the archetype in the right order
        // this needs more work but it should compile and run like this without burning
        try archetype.data.appendNTimes(self.allocator.*, @as(u8, 9), archetype.stride);

        var byte_offset: u32 = 0; // offset inside bytes.

        inline for (fields) |field| {
            const offset = getFieldOffset(field, archetype.components).?; // calculate offset in which the component should be placed
            var cidx: i32 = @intCast(archetype.data.items.len);
            cidx -= @intCast(archetype.stride);
            cidx += @intCast(offset); 
            const idx: usize = @intCast(std.mem.max(i32, &.{ cidx, 0 })); // find the index in the array

            @memcpy(archetype.data.items[idx..idx + @sizeOf(field.type)], bytes[byte_offset..byte_offset + @sizeOf(field.type)]); // copy data ranges
            byte_offset += @sizeOf(field.type);
        }
    }

    /// Adds a system (function) to the event loop which will be triggered when `event` occurs
    /// Systems are executed based on the order they were added.
    pub fn addSystem (self: *Self, system: SystemHandler, event: WorldEvent) !void {
        try self.systems.append(self.allocator.*, .{
            .handler = system,
            .event = event,
            .line_id = self.active_line
        });
    }

    /// *Resources are queried by type so adding multiple resources of the same is pointless*
    /// Use arrays or containers instead to store multiple data inside a resource, it's likely better
    pub fn addResource (self: *Self, comptime T: type, res: T) !void {
        try self.resource_map.put(@typeName(T), self.resources.items.len); // save offset
        const bytes = std.mem.asBytes(&res);
        try self.resources.appendSlice(self.allocator.*, bytes);
    }

    /// *Resources are queried by type so adding multiple resources of the same is pointless*
    /// Returns an optional value of the resource of type T.
    pub fn getResource (self: *Self, T: type) ?*T {
        const offset = self.resource_map.get(@typeName(T)) orelse return null;
        return @ptrCast(@alignCast(self.resources.items.ptr + offset)); // um.. this worked somehow..
    }
    
    /// Unmaps a resource pointer from the index
    /// This function does NOT delete resource data from the pool since deleting anything would require lots of reordering as well as changing other offsets
    /// Resources aren't made to be removed too often so this shouldn't be used unless you have a good reason to.
    pub fn removeResource (self: *Self, T: type) void {
        self.resource_map.remove(@typeName(T));
    }
};
