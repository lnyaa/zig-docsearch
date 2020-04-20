const std = @import("std");
const states = @import("state.zig");
const build_map = @import("build_map.zig");
const searches = @import("search.zig");
const htmlgen = @import("htmlgen.zig");

const State = states.State;
const OutError = std.fs.File.ReadError;
const InError = std.fs.File.WriteError;

const MAX_SIZE = 30 * 1024 * 1024;

fn loadState(state_path: []const u8, state: *State) !void {
    var state_file = try std.fs.cwd().openFile(state_path, .{ .read = true, .write = false });
    defer state_file.close();
    var in = state_file.inStream();

    const data = try in.readAllAlloc(state.allocator, MAX_SIZE);
    try state.readDumpAnalysis(data);
}

fn doSearch(state: *State, search_term: []u8) !void {
    try searches.doSearch(state, search_term);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = &arena.allocator;

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

        try loadState(state_path, &state);
        try doSearch(&state, search_term);
    } else if (std.mem.eql(u8, action, "htmlgen")) {
        const out_path = try (args_it.next(allocator) orelse @panic("expected out path arg"));

        //try loadState(state_path, &state);
        try htmlgen.genHtml(&state, out_path);
    } else {
        @panic("invalid action");
    }
}
