const std = @import("std");

fn eqlu8(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn hashu8(key: []const u8) u32 {
    var hasher = std.hash.Wyhash.init(0);
    for (key) |value| {
        std.hash.autoHash(&hasher, value);
    }

    return @truncate(u32, hasher.final());
}

pub fn StringKeyHashMap(comptime V: type) type {
    return std.HashMap([]const u8, V, hashu8, eqlu8);
}
