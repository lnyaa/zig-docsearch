const std = @import("std");
const states = @import("state.zig");

const Node = std.zig.ast.Node;
const Tree = std.zig.ast.Tree;
const State = states.State;

/// Check if the right hand side of the declaration is an @import, and if it is
/// recurse build() into that file, with an updated namespace, etc.
fn recurseIfImport(
    state: *State,
    tree: *Tree,
    namespace: []const u8,
    decl: *Node.VarDecl,
    init_node: *Node,
    zig_src: []const u8,
) anyerror!void {
    var builtin_call = @fieldParentPtr(Node.BuiltinCall, "base", init_node);
    var call_tok = tree.tokenSlice(builtin_call.builtin_token);
    var decl_name = tree.tokenSlice(decl.name_token);

    // if the builtin call isnt @import, but its something else, e.g
    // @intCast() or smth else, we add it as a node.
    if (!std.mem.eql(u8, call_tok, "@import")) {
        try state.addNode(tree, namespace, decl_name, decl.doc_comments);
        return;
    }

    var it = builtin_call.params.iterator(0);
    var arg1_ptrd = it.next().?;

    // the builtin_call.params has *Node, and SegmentedList returns
    // **Node... weird.
    var arg1_node = arg1_ptrd.*;
    if (arg1_node.id != .StringLiteral) return;

    // here we properly extract the main argument of @import and do our
    // big think moments until we reach proper arguments for build().
    var arg1 = @fieldParentPtr(Node.StringLiteral, "base", arg1_node);
    var token = tree.tokenSlice(arg1.token);
    token = token[1 .. token.len - 1];

    var buf: [1000]u8 = undefined;
    var ns = try std.fmt.bufPrint(buf[0..], "{}.{}", namespace, decl_name);
    var dirname = std.fs.path.dirname(zig_src).?;

    var basename = std.fs.path.basename(zig_src);
    var name_it = std.mem.tokenize(basename, ".");
    var name = name_it.next().?;

    // the main example of the reason of this behavior is the std.valgrind
    // library. it just has something like @import("callgrind.zig") where
    // callgrind.zig is in std/valgrind/callgrind.zig, not std/callgrind.zig.

    var path = try std.fs.path.join(
        state.allocator,
        [_][]const u8{ dirname, token },
    );

    std.fs.File.access(path) catch |err| {
        if (err == error.FileNotFound) {
            path = try std.fs.path.join(
                state.allocator,
                [_][]const u8{ dirname, name, token },
            );
        } else {
            return err;
        }
    };

    try build(state, ns, path);
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
            .FnProto => blk: {
                var proto = @fieldParentPtr(Node.FnProto, "base", child);

                if (proto.visib_token) |_| {
                    var fn_name = tree.tokenSlice(proto.name_token.?);
                    try state.addNode(tree, namespace, fn_name, proto.doc_comments);
                }
            },

            .VarDecl => blk: {
                var decl = @fieldParentPtr(Node.VarDecl, "base", child);

                var visib_tok_opt = decl.visib_token;
                if (visib_tok_opt) |_| {
                    var init_node = decl.init_node.?;
                    var decl_name = tree.tokenSlice(decl.name_token);

                    switch (init_node.id) {
                        .BuiltinCall => try recurseIfImport(
                            state,
                            tree,
                            namespace,
                            decl,
                            init_node,
                            zig_src_path,
                        ),

                        // TODO recurse over the definitions there IF its
                        // a struct definition.
                        .SuffixOp => {},
                        else => try state.addNode(tree, namespace, decl_name, decl.doc_comments),
                    }
                }
            },

            else => continue,
        }
    }
}
