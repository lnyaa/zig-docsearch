const std = @import("std");
const Node = std.zig.ast.Node;

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

    fn addNode(self: *State, path: []const u8) void {}

    fn docToSlice(self: *State, tree: var, doc_opt: ?*Node.DocComment) ![][]const u8 {
        if (doc_opt) |doc| {
            var it = doc.lines.iterator(0);
            var lines: [][]const u8 = try self.allocator.alloc([]u8, 0);

            while (it.next()) |line_idx| {
                lines = try self.allocator.realloc(lines, lines.len + 1);
                var line = tree.tokenSlice(line_idx.*);
                lines[lines.len - 1] = std.mem.trimLeft(u8, line, "/// ");
            }

            return lines;
        } else {
            return [_][]u8{};
        }
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

        var tree = try std.zig.parse(self.allocator, data);
        var root = tree.root_node;
        defer tree.deinit();

        var idx: usize = 0;

        // fun fact, the easier case is handling a raw FnProto, this wasn't
        // obvious at first.
        while (root.iterate(idx)) |child| : (idx += 1) {
            switch (child.id) {
                .FnProto => blk: {
                    var proto = @fieldParentPtr(Node.FnProto, "base", child);

                    var visib_tok_opt = proto.visib_token;
                    if (visib_tok_opt) |visib_tok| {
                        var fn_name = tree.tokenSlice(proto.name_token.?);

                        var lines = try self.docToSlice(tree, proto.doc_comments);
                        for (lines) |line| {
                            std.debug.warn("\tdoc: '{}'\n", line);
                        }

                        var buf: [1024]u8 = undefined;
                        var fn_key = try std.fmt.bufPrint(buf[0..], "{}", fn_name);
                        var finished_lines = try std.mem.join(self.allocator, "\n", lines);

                        std.debug.warn(
                            "pub fn, key='{}'\n\tdoc: '{}'\n",
                            fn_key,
                            finished_lines,
                        );

                        _ = try self.map.put(fn_key, finished_lines);
                    }
                },

                .VarDecl => blk: {
                    var decl = @fieldParentPtr(Node.VarDecl, "base", child);

                    var visib_tok_opt = decl.visib_token;
                    if (visib_tok_opt) |visib_tok| {
                        std.debug.warn(
                            "pub var, name='{}'\n",
                            tree.tokenSlice(decl.name_token),
                        );

                        var lines = try self.docToSlice(tree, decl.doc_comments);
                        for (lines) |line| {
                            std.debug.warn("\tdoc: '{}'\n", line);
                        }

                        // check if from there the rhs is a struct or not,
                        // and if it is, recursively go through its members
                        // and add them to the state.map.
                        var suffix = @fieldParentPtr(Node.SuffixOp, "base", decl.init_node.?);
                        switch (suffix.op) {
                            .StructInitializer => |struct_list| blk: {
                                std.debug.warn("!VAR IS STRUCT\n");
                            },
                            else => std.debug.warn("var not struct\n"),
                        }
                    }
                },

                else => continue,
            }
        }

        std.debug.warn("OK\n");

        _ = try self.map.put(rel_path, data);
    }
};
