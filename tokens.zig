const chars = @import("chars.zig");
const std = @import("std");

pub fn isMnemonic(token: []const u8) bool {
    const size = std.mem.lenZ(token);

    if (size < 2 or size > 4) //all mnemonics are 2 to 4 chars
        return false;

    for (token) |c| {
        if (!@call(.{ .modifier = .always_inline }, chars.isUppercaseLetter, .{c}))
            return false;
    }

    return true;
}
