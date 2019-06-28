const std = @import("std");

pub const State = struct {
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) State {
        return State{ .allocator = allocator };
    }

    pub fn deserialize(self: *State, deserializer: var) !void {}

    pub fn serialize(self: *State, serialize: var) !void {}
};
