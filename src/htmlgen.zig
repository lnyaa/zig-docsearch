const std = @import("std");

const states = @import("state.zig");
const State = states.State;

pub fn genHtml(state: *State, out_path: []const u8) !void {
    var file = try std.fs.File.openWrite(out_path);
    defer file.close();

    var out = file.outStream();
    var stream = &out.stream;

    try stream.print("<html>\n");
    try stream.print("<\\html>\n");

    std.debug.warn("OK\n");
}
