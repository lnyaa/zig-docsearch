const std = @import("std");
const states = @import("state.zig");

const Node = std.zig.ast.Node;
const Tree = std.zig.ast.Tree;
const State = states.State;

pub fn appendNamespace(
    allocator: *std.mem.Allocator,
    namespace: []const u8,
    element: []const u8,
) ![]const u8 {
    return try std.mem.join(allocator, ".", [_][]const u8{ namespace, element });
}

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

    var ns = try appendNamespace(state.allocator, namespace, decl_name);
    var dirname = std.fs.path.dirname(zig_src).?;

    var basename = std.fs.path.basename(zig_src);
    var name_it = std.mem.tokenize(basename, ".");
    var name = name_it.next().?;

    var path = try std.fs.path.join(
        state.allocator,
        [_][]const u8{ dirname, token },
    );

    // the fallback to {dirname, name, token} exists since @import() calls
    // can point to the relative path of the current file plus the file's name
    // itself. take for example std.valgrind,
    // that is currently at std/valgrind.zig.

    // it contains @import("callgrind.zig"), but it isn't at std/callgrind.zig,
    // but at std/valgrind/callgrind.zig

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

fn processStruct(
    state: *State,
    tree: *Tree,
    namespace: []const u8,
    fields_and_decls: *Node.Root.DeclList,
) !void {
    // we are inside a struct, so we must iterate through its definitions.
    var it = fields_and_decls.iterator(0);

    while (it.next()) |node_ptr| {
        var node = node_ptr.*;

        switch (node.id) {
            .ContainerField => blk: {
                var field = @fieldParentPtr(Node.ContainerField, "base", node);
                var field_name = tree.tokenSlice(field.name_token);
                try state.addNode(tree, namespace, field_name, field.doc_comments);
            },

            .FnProto => blk: {
                var proto = @fieldParentPtr(Node.FnProto, "base", node);
                var fn_name = tree.tokenSlice(proto.name_token.?);
                try state.addNode(tree, namespace, fn_name, proto.doc_comments);
            },

            else => continue,
        }
    }
}

/// Build the state map, given the current state, the namespace of the current
/// file, e.g "std.os", and the current source path. this function shall be
/// called first with the path to the root std.zig file, usually found at
/// $LIB/zig/std/std.zig.
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
    // the Tree is traversed in a simple manner:
    // - if we find a public function, add it to the state
    // - if we find a public var declaration on top level, we check the right
    //   hand side for an @import, if that's the case, we recurse into its
    //   definitions.

    var idx: usize = 0;
    while (root.iterate(idx)) |child| : (idx += 1) {
        switch (child.id) {
            .FnProto => blk: {
                var proto = @fieldParentPtr(Node.FnProto, "base", child);

                _ = proto.visib_token orelse continue;

                var fn_name = tree.tokenSlice(proto.name_token.?);
                try state.addNode(tree, namespace, fn_name, proto.doc_comments);
            },

            .VarDecl => blk: {
                var decl = @fieldParentPtr(Node.VarDecl, "base", child);

                _ = decl.visib_token orelse continue;

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

                    .ContainerDecl => blk: {
                        var con_decl = @fieldParentPtr(Node.ContainerDecl, "base", init_node);
                        var kind_token = tree.tokenSlice(con_decl.kind_token);

                        try state.addNode(tree, namespace, decl_name, decl.doc_comments);

                        if (std.mem.eql(u8, kind_token, "struct")) {
                            try processStruct(
                                state,
                                tree,
                                try appendNamespace(state.allocator, namespace, decl_name),
                                &con_decl.fields_and_decls,
                            );
                        } else {
                            try state.addNode(tree, namespace, decl_name, decl.doc_comments);
                        }
                    },

                    else => try state.addNode(tree, namespace, decl_name, decl.doc_comments),
                }
            },

            else => continue,
        }
    }
}
