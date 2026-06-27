const std = @import("std");

pub const EntityId = u32;
pub const ComponentType = u64;

/// Type-erased component: each entry stores a vtable-like deinitFn for cleanup.
pub const Component = struct {
    type_id: ComponentType,
    data: *anyopaque,
    deinitFn: *const fn (data: *anyopaque, allocator: std.mem.Allocator) void,
};

/// A node in the scene graph: has a name, optional parent, children, and components.
pub const Entity = struct {
    id: EntityId,
    name: []const u8,
    active: bool = true,
    parent: ?EntityId = null,
    children: std.ArrayList(EntityId),
    components: std.AutoHashMap(ComponentType, Component),
};

/// Hierarchical entity-component system.
/// Entities form a tree; components attach data + behaviour to them.
pub const SceneGraph = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    entities: std.AutoHashMap(EntityId, Entity),
    next_id: EntityId,
    root_entities: std.ArrayList(EntityId),

    loop_cache: std.ArrayList(*Entity),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .entities = .init(allocator),
            .next_id = 1,
            .root_entities = .empty,
            .loop_cache = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.entities.valueIterator();
        while (it.next()) |entity| {
            self.allocator.free(entity.name);
            var comps = entity.components.valueIterator();
            while (comps.next()) |comp| {
                comp.deinitFn(comp.data, self.allocator);
            }
            entity.components.deinit();
            entity.children.deinit(self.allocator);
        }
        self.entities.deinit();
        self.root_entities.deinit(self.allocator);
        self.loop_cache.deinit(self.allocator);
    }

    /// Spawn a new root entity. Returns its unique ID.
    pub fn createEntity(self: *Self, name: []const u8) !EntityId {
        const id = self.next_id;
        self.next_id += 1;
        const entity_name = try self.allocator.dupe(u8, name);

        try self.entities.put(id, .{
            .id = id,
            .name = entity_name,
            .children = .empty,
            .components = .init(self.allocator),
        });

        try self.root_entities.append(self.allocator, id);
        return id;
    }

    /// Recursively destroy entity, its children, and all components.
    pub fn destroyEntity(self: *Self, id: EntityId) void {
        const entity = self.getEntity(id) orelse return;

        while (entity.children.items.len > 0) {
            self.destroyEntity(entity.children.items[entity.children.items.len - 1]);
        }

        if (entity.parent) |parent_id| {
            if (self.entities.getPtr(parent_id)) |parent| {
                removeFromList(&parent.children, id);
            }
        } else {
            removeFromList(&self.root_entities, id);
        }

        var comps = entity.components.valueIterator();
        while (comps.next()) |comp| {
            comp.deinitFn(comp.data, self.allocator);
        }

        entity.components.deinit();
        entity.children.deinit(self.allocator);
        self.allocator.free(entity.name);
        self.entities.remove(id);
    }

    pub fn enableEntity(self: *Self, eid: EntityId) void {
        const entity = self.getEntity(eid) orelse return;
        entity.active = true;
    }

    pub fn disableEntity(self: *Self, eid: EntityId) void {
        const entity = self.getEntity(eid) orelse return;
        entity.active = false;
    }

    pub fn getEntity(self: Self, id: EntityId) ?*Entity {
        return self.entities.getPtr(id);
    }

    /// Attach a component to an entity. T's type name is hashed to produce the ComponentType key.
    pub fn addComponent(self: *Self, entity_id: EntityId, comptime T: type, component_data: T) !void {
        const entity = self.entities.getPtr(entity_id) orelse return error.EntityNotFound;
        const type_id = componentTypeId(T);
        const ptr = try self.allocator.create(T);
        ptr.* = component_data;

        try entity.components.put(type_id, .{
            .type_id = type_id,
            .data = ptr,
            .deinitFn = struct {
                fn deinit(d: *anyopaque, allocator: std.mem.Allocator) void {
                    const typed: *T = @ptrCast(@alignCast(d));
                    if (@hasDecl(T, "deinit")) typed.deinit(allocator);
                    allocator.destroy(typed);
                }
            }.deinit,
        });
    }

    /// Read a component by type. Returns null if entity or component doesn't exist.
    pub fn getComponent(self: Self, entity_id: EntityId, comptime T: type) ?*T {
        const type_id = componentTypeId(T);
        const entity = self.getEntity(entity_id) orelse return null;
        const comp = entity.components.get(type_id) orelse return null;

        return @ptrCast(@alignCast(comp.data));
    }

    /// Detach and deinitialize a component from an entity.
    pub fn removeComponent(self: *Self, entity_id: EntityId, comptime T: type) void {
        const type_id = componentTypeId(T);
        const entity = self.entities.getPtr(entity_id) orelse return;

        if (entity.components.fetchRemove(type_id)) |kv| {
            kv.value.deinitFn(kv.value.data, self.allocator);
        }
    }

    /// Reparent an entity under another.
    pub fn setParent(self: *Self, entity_id: EntityId, parent_id: EntityId) !void {
        if (entity_id == parent_id) return error.WTFisThis;

        const entity = self.getEntity(entity_id) orelse return error.EntityNotFound;

        if (entity.parent) |old_parent| {
            if (self.getEntity(old_parent)) |p| {
                removeFromList(&p.children, entity_id);
            }
        } else {
            removeFromList(&self.root_entities, entity_id);
        }

        entity.parent = parent_id;

        if (self.getEntity(parent_id)) |parent| {
            try parent.children.append(self.allocator, entity_id);
        }
    }

    /// Slow linear scan — not cached.
    pub fn findByName(self: Self, name: []const u8) ?EntityId {
        var it = self.entities.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.name, name)) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }

    /// Run `callback` on all entities with T components.
    pub fn runSystem(self: *Self, comptime T: []const type, callback: fn(*anyopaque, EntityId, @Tuple(T)) anyerror!void, ctx: *anyopaque) !void {
        const t_info = @typeInfo(@Tuple(T)).@"struct";

        self.loop_cache.clearRetainingCapacity();

        for (self.root_entities.items) |id| {
            try self.loop_cache.append(self.allocator, self.getEntity(id).?);
        }

        var i: usize = 0;
        while (self.loop_cache.items.len > i) : (i += 1) {
            const entity = self.loop_cache.items[i];
            if (!entity.active) continue;

            if (matchEntity(entity, t_info.fields)) {
                var components: @Tuple(T) = undefined;

                inline for (t_info.fields) |field| {
                    const component = componentTypeId(@typeInfo(field.type).pointer.child);
                    @field(components, field.name) = @ptrCast(@alignCast(entity.components.get(component).?.data));
                }

                try @call(.auto, callback, .{ ctx, entity.id, components });
            }

            for (entity.children.items) |cid| {
                try self.loop_cache.append(self.allocator, self.getEntity(cid).?);
            }
        }
    }

    fn matchEntity(entity: *Entity, fields: []const std.builtin.Type.StructField) bool {
        inline for (fields) |field| {
            const component = componentTypeId(@typeInfo(field.type).pointer.child);
            if (entity.components.get(component) == null) return false;
        }

        return true;
    }

    /// Stable identifier for any Zig type: wyhash of @typeName.
    fn componentTypeId(comptime T: type) ComponentType {
        return comptime std.hash.Wyhash.hash(0, @typeName(T));
    }
};

/// Remove `id` from a list by swapping with the last element (order not preserved).
fn removeFromList(list: *std.ArrayList(EntityId), id: EntityId) void {
    var i: usize = list.items.len;
    while (i > 0) {
        i -= 1;
        if (list.items[i] == id) {
            _ = list.swapRemove(i);
            return;
        }
    }
}
