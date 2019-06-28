const std = @import("std");
const states = @import("state.zig");

const State = states.State;

pub fn build(state: *State, zig_std_path: []const u8, folder_path: []const u8) anyerror!void {
    var dir = try std.fs.Dir.open(state.allocator, folder_path);
    defer dir.close();

    while (try dir.next()) |entry| {
        var path = try std.fs.path.join(
            state.allocator,
            [_][]const u8{ folder_path, entry.name },
        );

        switch (entry.kind) {
            .File => blk: {
                // TODO skip if it doesn't end with .zig, just in case
                try state.addFile(entry.name, path);
            },
            .Directory => blk: {
                // recursively go into the next path
                try build(state, zig_std_path, path);
            },
            else => continue,
        }
    }
}
