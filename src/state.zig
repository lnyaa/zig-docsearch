const std = @import("std");
const build_map = @import("build_map.zig");
const Node = std.zig.ast.Node;
const Tree = std.zig.ast.Tree;

const StateMap = std.StringHashMap([]u8);

/// Serialize a string into the given serializer. Uses a simple u29 length
/// prefix + the string itself.
fn serializeStr(serializer: var, string: []const u8) !void {
    try serializer.serialize(@intCast(u29, string.len));
    for (string) |byte| {
        try serializer.serialize(byte);
    }
}

/// Represents the current amount of knowledge being held by the state
/// file into memory.
pub const State = struct {
    allocator: *std.mem.Allocator,
    map: StateMap,

    pub fn init(allocator: *std.mem.Allocator) State {
        return State{
            .allocator = allocator,
            .map = StateMap.init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        self.map.deinit();
    }

    /// Deserialize a string from the stream into memory.
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
            var length = deserializer.deserialize(u29) catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };
            if (length == 0) break;

            // deserialize a KV pair and put() it
            const key = try self.deserializeStr(deserializer, length);
            var value = try self.deserializeStr(deserializer, null);

            _ = try self.map.put(key, value);
        }
    }

    pub fn serialize(self: *State, serializer: var) !void {
        var it = self.map.iterator();
        var cnt: usize = 0;

        while (it.next()) |kv| {
            std.debug.warn("serializing '{}' ({} bytes)\n", .{
                kv.key,
                kv.value.len,
            });

            try serializeStr(serializer, kv.key);
            try serializeStr(serializer, kv.value);
            cnt += 1;
        }

        // sentry value to determine end of hashmap
        // maybe we could just catch an endofstream instead, idk.
        try serializer.serialize(@as(u29, 0));

        std.debug.warn("finished {} elements\n", .{cnt});
    }

    /// From a given Node.DocComment, convert it to [][]const u8, with the
    /// doc comment tokens trimmed out.
    fn docToSlice(self: *State, tree: var, doc_opt: ?*Node.DocComment) ![][]const u8 {
        // TODO: use ArrayList
        var lines: [][]const u8 = try self.allocator.alloc([]u8, 0);

        if (doc_opt) |doc| {
            var it = doc.lines.iterator(0);

            while (it.next()) |line_idx| {
                lines = try self.allocator.realloc(lines, lines.len + 1);
                var line = tree.tokenSlice(line_idx.*);

                lines[lines.len - 1] = std.mem.trimLeft(u8, line, "/// ");
            }

            return lines;
        } else {
            return lines;
        }
    }

    /// Add a given node (not the full Node structure) into the state.
    pub fn addNode(
        self: *State,
        tree: *Tree,
        namespace: []const u8,
        node_name: []const u8,
        doc: ?*Node.DocComment,
    ) !void {
        var full_name = try build_map.appendNamespace(
            self.allocator,
            namespace,
            node_name,
        );

        std.debug.warn("node: {}\n", .{full_name});
        var lines = try self.docToSlice(tree, doc);

        for (lines) |line| {
            std.debug.warn("\tdoc: {}\n", .{line});
        }

        var lines_single = try std.mem.join(self.allocator, "\n", lines);
        _ = try self.map.put(full_name, lines_single);
    }

    pub fn readDumpAnalysis(self: *@This(), dump_analysis_data: []const u8) !void {
        var p = std.json.Parser.init(self.allocator, true);
        defer p.deinit();
        var tree = try p.parse(dump_analysis_data);
        std.debug.warn("awoo?\n", .{});
        var root = tree.root;
        root.dump();
    }
};
