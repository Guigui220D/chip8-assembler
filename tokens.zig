const chars = @import("chars.zig");
const std = @import("std");

const max_label_length: usize = 16;

pub fn isMnemonic(token: []const u8) bool {
    const size = std.mem.len(token);

    if (size < 2 or size > 4) //all mnemonics are 2 to 4 chars
        return false;

    for (token) |c| {
        if (!@call(.{ .modifier = .always_inline }, chars.isUppercaseLetter, .{c}))
            return false;
    }

    return true;
}

pub fn isLabel(token: []const u8) bool {
    const size = std.mem.len(token);

    if (size == 0 or size > max_label_length)
        return false;

    for (token) |c| {
        if (!@call(.{ .modifier = .always_inline }, chars.isAlphanumeric, .{c}))
            return false;
    }

    return true;
}
