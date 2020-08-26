const chars = @import("chars.zig");
const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

pub const ops = [_][]const u8{
    "CLS_",
    "RET_",
    "SYS_P",
    "JP_P",
    "CALL_P",
    "SE_VO",
    "SNE_VO",
    "SE_VV",
    "LD_VO",
    "ADD_VO",
    "LD_VV",
    "OR_VV",
    "AND_VV",
    "XOR_VV",
    "ADD_VV",
    "SUB_VV",
    "SHR_V",
    "SUBN_VV",
    "SHL_V",
    "SNE_VV",
    "LD_IP",
    "JP_0P",
    "RND_VO",
    "DRW_VVN",
    "SKP_V",
    "SKNP_V",
    "LD_VD",
    "LD_VK",
    "LD_DV",
    "LD_SV",
    "ADD_IV",
    "LD_FV",
    "LD_BV",
    "LD_AV",
    "LD_VA",
};

pub const codes = [_][]const u8{
    "00e0",
    "00ee",
    "0___",
    "1___",
    "2___",
    "3___",
    "4___",
    "5__0",
    "6___",
    "7___",
    "8__0",
    "8__1",
    "8__2",
    "8__3",
    "8__4",
    "8__5",
    "8_06",
    "8__7",
    "8_0e",
    "9__0",
    "a___",
    "b___",
    "c___",
    "d___",
    "e_9e",
    "e_a1",
    "f_07",
    "f_0a",
    "f_15",
    "f_18",
    "f_1e",
    "f_29",
    "f_33",
    "f_55",
    "f_65",
};

pub fn matchPattern(pattern: []const u8) ?usize {
    var result: usize = 0;

    checks: for (ops) |op| {
        var i: u8 = 0;

        if (std.mem.len(op) != std.mem.len(pattern)) {
            result += 1;
            continue :checks;
        }

        while (i != std.mem.len(op)) {
            if (op[i] == pattern[i] or (@call(.{ .modifier = .always_inline }, chars.isHexDigit, .{pattern[i]}) and op[i] == 'V')) {
                i += 1;
            } else {
                result += 1;
                continue :checks;
            }
        }

        return result;
    }

    return null;
}