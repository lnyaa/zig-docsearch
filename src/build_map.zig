const std = @import("std");
const states = @import("state.zig");

const Node = std.zig.ast.Node;
const Tree = std.zig.ast.Tree;
const State = states.State;

fn recurseIfImport(
    state: *State,
    tree: *Tree,
    namespace: []const u8,
    decl_name: []const u8,
    init_node: *Node,
    zig_src: []const u8,
) anyerror!void {
    var builtin_call = @fieldParentPtr(Node.BuiltinCall, "base", init_node);
    var call_tok = tree.tokenSlice(builtin_call.builtin_token);

    if (std.mem.eql(u8, call_tok, "@import")) {
        var it = builtin_call.params.iterator(0);

        var arg1_opt = it.next();
        if (arg1_opt) |arg1_ptrd| {
            var arg1_node = arg1_ptrd.*;
            if (arg1_node.id != .StringLiteral) return;

            var arg1 = @fieldParentPtr(Node.StringLiteral, "base", arg1_node);
            var token = tree.tokenSlice(arg1.token);
            token = token[1 .. token.len - 1];

            var tok_it = std.mem.tokenize(token, ".");
            var name_opt = tok_it.next();

            if (name_opt) |name| {
                var buf: [1000]u8 = undefined;
                var ns = try std.fmt.bufPrint(buf[0..], "{}.{}", namespace, decl_name);
                var dirname_opt = std.fs.path.dirname(zig_src);

                if (dirname_opt) |dirname| {
                    std.debug.warn("file: '{}'\n", token);
                    try build(
                        state,
                        ns,
                        try std.fs.path.join(state.allocator, [_][]const u8{ dirname, token }),
                    );
                }
            }
        }
    }
}

/// Build the state map
pub fn build(
    state: *State,
    namespace: []const u8,
    zig_src_path: []const u8,
) anyerror!void {
    std.debug.warn("{} {}\n", namespace, zig_src_path);
    var file = try std.fs.File.openRead(zig_src_path);
    defer file.close();

    const total_bytes = try file.getEndPos();
    var data = try state.allocator.alloc(u8, total_bytes);
    _ = try file.read(data);

    var tree = try std.zig.parse(state.allocator, data);
    defer tree.deinit();

    var root = tree.root_node;

    // evaluate that tree and go through it.

    var idx: usize = 0;
    while (root.iterate(idx)) |child| : (idx += 1) {
        switch (child.id) {
            .VarDecl => blk: {
                var decl = @fieldParentPtr(Node.VarDecl, "base", child);

                var visib_tok_opt = decl.visib_token;
                if (visib_tok_opt) |_| {
                    var decl_name = tree.tokenSlice(decl.name_token);
                    var init_node = decl.init_node.?;
                    switch (init_node.id) {
                        .BuiltinCall => blk: {
                            try recurseIfImport(
                                state,
                                tree,
                                namespace,
                                decl_name,
                                init_node,
                                zig_src_path,
                            );
                        },
                        else => continue,
                    }
                }
            },

            else => continue,
        }
    }
}
