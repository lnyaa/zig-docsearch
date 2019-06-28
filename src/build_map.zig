const std = @import("std");
const states = @import("state.zig");

const State = states.State;

pub fn build(state: *State, zig_std_path: []const u8) !void {
    var dir = try std.fs.Dir.open(state.allocator, zig_std_path);
    defer dir.close();

    while (try dir.next()) |entry| {
        switch (entry.kind) {
            .File => blk: {
                var path = try std.fs.path.join(
                    state.allocator,
                    [_][]const u8{ zig_std_path, entry.name },
                );

                // TODO skip if it doesn't end with .zig, just in case

                std.debug.warn("file: '{}'\n", path);

                var file = try std.fs.File.openRead(path);
                defer file.close();

                const total_bytes = try file.getEndPos();
                var data = try state.allocator.alloc(u8, total_bytes);
                const bytes_read = try file.read(data);

                // safety of life check
                std.testing.expectEqual(bytes_read, total_bytes);
            },
            else => continue,
        }
    }
}
