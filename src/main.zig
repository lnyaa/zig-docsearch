const std = @import("std");
const states = @import("state.zig");
const build_map = @import("build_map.zig");
const searches = @import("search.zig");
const htmlgen = @import("htmlgen.zig");

const State = states.State;
const OutError = std.fs.File.ReadError;
const InError = std.fs.File.WriteError;

fn loadState(state_path: []const u8, state: *State) !void {
    var path = try std.fs.path.resolve(
        state.allocator,
        &[_][]const u8{state_path},
    );

    var state_file = try std.fs.cwd().openFile(path, .{ .read = true, .write = false });
    defer state_file.close();
    var in = state_file.inStream();
    var deserial = std.io.Deserializer(.Big, .Bit, @TypeOf(in)).init(in);

    try deserial.deserializeInto(state);
}

fn doSearch(state: *State, search_term: []u8) !void {
    try searches.doSearch(state, search_term);
}

fn doBuild(state_path: []const u8, state: *State, zig_std_path: []u8) !void {
    try build_map.build(state, "std", zig_std_path);
    std.debug.warn("build finished, {} total defs\n", .{state.map.size});

    const resolved_path = try std.fs.path.resolve(state.allocator, &[_][]const u8{state_path});

    var state_file = try (std.fs.cwd().openFile(resolved_path, .{
        .write = true,
    }) catch |err| blk: {
        if (err != error.FileNotFound) break :blk err;
        break :blk std.fs.cwd().createFile(resolved_path, .{});
    });

    defer state_file.close();

    var out = state_file.outStream();
    var serial = std.io.Serializer(.Big, .Bit, @TypeOf(out)).init(out);

    try state.serialize(&serial);
    std.debug.warn("serialization OK\n", .{});
}

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;
    var state = State.init(allocator);
    defer state.deinit();

    var args_it = std.process.args();
    if (!args_it.skip()) @panic("expected self arg");

    const state_path = try (args_it.next(allocator) orelse @panic("expected state.bin file path"));
    const action = try (args_it.next(allocator) orelse @panic("expected action arg"));

    if (std.mem.eql(u8, action, "build")) {
        @panic("functionality removed");
    } else if (std.mem.eql(u8, action, "search")) {
        const search_term = try (args_it.next(allocator) orelse @panic("expected search term arg"));

        //try loadState(state_path, &state);
        try doSearch(&state, search_term);
    } else if (std.mem.eql(u8, action, "htmlgen")) {
        const out_path = try (args_it.next(allocator) orelse @panic("expected out path arg"));

        //try loadState(state_path, &state);
        try htmlgen.genHtml(&state, out_path);
    } else {
        @panic("invalid action");
    }
}
