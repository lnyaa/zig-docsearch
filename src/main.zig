const std = @import("std");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();

    var allocator = &arena.allocator;

    var args_it = std.process.args();
    if (!args_it.skip()) @panic("expected self arg");

    const action = try (args_it.next(allocator) orelse @panic("expected action arg"));

    if (std.mem.eql(u8, action, "build")) {
        const zig_std_path = try (args_it.next(allocator) orelse @panic("expected zig stdlib path arg"));
    } else if (std.mem.eql(u8, action, "search")) {
        const search_term = try (args_it.next(allocator) orelse @panic("expected search term arg"));
    } else {
        @panic("invalid action");
    }
}
