const std = @import("std");

const states = @import("state.zig");
const State = states.State;

const style = @embedFile("style.css");

pub fn genHtml(state: *State, out_path: []const u8) !void {
    var file = try std.fs.File.openWrite(out_path);
    defer file.close();

    var out = file.outStream();
    var stream = &out.stream;

    try stream.print("<!doctype html>\n<html>\n");
    try stream.print("<head>\n<meta chatset=\"utf-8\">\n<title>zig docs</title>\n");
    try stream.print("<style type=\"text/css\">\n");
    try stream.print("{}\n", style);
    try stream.print("</style>\n");
    try stream.print("</head>\n");
    try stream.print("</html>\n");

    std.debug.warn("OK\n");
}
