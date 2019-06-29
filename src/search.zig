const std = @import("std");
const states = @import("state.zig");

const State = states.State;

const ScoreMap = std.AutoHashMap([]const u8, f32);

fn doCount(haystack: []u8, needle: []u8) usize {
    var count: usize = 0;

    var idx: usize = 0;
    while (true) {
        var newidx_opt = std.mem.indexOfPos(u8, haystack, idx, needle);
        if (newidx_opt) |newidx| {
            if (newidx == idx) {
                idx += 1;
            } else {
                idx = newidx;
            }
        } else {
            break;
        }
    }

    return count;
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    var idx = std.mem.indexOf(u8, haystack, needle);
    return idx != null;
}

fn toLower(allocator: *std.mem.Allocator, data: []const u8) ![]u8 {
    var out = try allocator.alloc(u8, data.len);

    for (data) |byte, idx| {
        out[idx] = std.ascii.toLower(byte);
    }

    return out;
}

fn compareFunc(kv1: ScoreMap.KV, kv2: ScoreMap.KV) bool {
    var kv1_score = (kv1.value + @intToFloat(f32, kv1.key.len));
    var kv2_score = (kv2.value + @intToFloat(f32, kv2.key.len));
    return kv1_score < kv2_score;
}

pub fn doSearch(state: *State, unprep_term: []u8) !void {
    // first step is lowercasing the given search term
    var res = ScoreMap.init(state.allocator);
    defer res.deinit();

    var kvs = std.ArrayList(ScoreMap.KV).init(state.allocator);
    defer kvs.deinit();

    var search_term = try toLower(state.allocator, unprep_term);
    defer state.allocator.free(search_term);

    // port of https://github.com/lnyaa/elixir-docsearch/blob/master/server.py#L17
    var it = state.map.iterator();
    while (it.next()) |kv| {
        var score: f32 = 0.0;

        var count = doCount(kv.value, search_term);
        score = @intToFloat(f32, count) / f32(50);

        var key_lower = try toLower(state.allocator, kv.key);
        defer state.allocator.free(key_lower);

        var idx_opt = std.mem.indexOf(u8, key_lower, search_term);
        if (idx_opt) |idx| {
            score += std.math.min(
                @intToFloat(f32, key_lower.len) / @intToFloat(f32, idx),
                10,
            );
        }

        score = std.math.min(score, 1);
        score = std.math.floor(score * 100) / 100;

        if (score > 0.05) {
            var kv_score = try res.getOrPutValue(kv.key, score);
            try kvs.append(kv_score.*);
        }
    }

    var kvs_slice = kvs.toSlice();
    std.sort.sort(ScoreMap.KV, kvs_slice, compareFunc);

    var stdout_file = try std.io.getStdOut();
    const stdout = &stdout_file.outStream().stream;

    if (kvs_slice.len > 15) kvs_slice = kvs_slice[0..14];
    for (kvs_slice) |kv| {
        try stdout.print("{}\n", kv.key);
    }
}
