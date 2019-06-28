const std = @import("std");

pub const StateMap = std.AutoHashMap([]const u8, []u8);

fn serializeStr(serializer: var, string: []const u8) !void {
    try serializer.serialize(@intCast(u29, string.len));
    for (string) |byte| {
        try serializer.serialize(byte);
    }
}

pub const State = struct {
    allocator: *std.mem.Allocator,
    map: StateMap,

    pub fn init(allocator: *std.mem.Allocator) State {
        return State{
            .allocator = allocator,
            .map = StateMap.init(allocator),
        };
    }

    fn deserializeStr(
        self: *State,
        deserializer: var,
        length_opt: ?u29,
    ) ![]u8 {
        var i: usize = 0;
        var res: []u8 = undefined;
        var length: u29 = undefined;

        if (length_opt) |length_actual| {
            length = length_actual;
            res = try self.allocator.alloc(u8, length);
        } else {
            length = try deserializer.deserialize(u29);
            res = try self.allocator.alloc(u8, length);
        }

        while (i < length) : (i += 1) {
            var byte = try deserializer.deserialize(u8);
            res[i] = byte;
        }

        return res;
    }

    pub fn deserialize(self: *State, deserializer: var) !void {
        while (true) {
            var length = try deserializer.deserialize(u29);
            if (length == 0) break;

            // deserialize a KV pair and put() it
            const key = try self.deserializeStr(deserializer, length);
            var value = try self.deserializeStr(deserializer, null);

            _ = try self.map.put(key, value);
        }
    }

    pub fn serialize(self: *State, serializer: var) !void {
        var it = self.map.iterator();

        while (it.next()) |kv| {
            std.debug.warn(
                "serializing '{}' ({} bytes)\n",
                kv.key,
                kv.value.len,
            );

            try serializeStr(serializer, kv.key);
            try serializeStr(serializer, kv.value);
        }

        // sentry value to determine end of hashmap
        // maybe we could just catch an endofstream instead, idk.
        try serializer.serialize(u29(0));
    }

    /// Add a file from the zig standard library into the state.
    pub fn addFile(self: *State, rel_path: []const u8, full_path: []const u8) !void {
        std.debug.warn("adding file: '{}'..", rel_path);
        var file = try std.fs.File.openRead(full_path);
        defer file.close();

        const total_bytes = try file.getEndPos();
        std.debug.warn("({} bytes)..", total_bytes);

        if (total_bytes > (800 * 1024)) {
            std.debug.warn("SKIP (too much)\n");
            return;
        }

        var data = try self.allocator.alloc(u8, total_bytes);
        const bytes_read = try file.read(data);

        // safety of life check
        std.testing.expectEqual(bytes_read, total_bytes);

        std.debug.warn("OK\n");

        _ = try self.map.put(rel_path, data);
    }
};
