const std = @import("std");
const print = @import("std").debug.print;
const asmbl = @import("assembler.zig");
const instr = @import("instructions.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    const line = "JP V0 0xaef";

    print("Line: '{}'\n", .{line});

    var tokens = std.mem.tokenize(line, " ");

    const pattern = try asmbl.getPattern(tokens, allocator);
    defer allocator.free(pattern);

    print("Pattern: '{}'\n", .{pattern});

    var patId = instr.matchPattern(pattern);

    if (patId != null) {
        print("Pattern id: '{}'\n", .{patId.?});

        const args = try asmbl.extractArgs(tokens, instr.ops[patId.?], allocator);
        defer allocator.free(args);

        print("Arguments: (hex) '{}'.\n", .{args});

        const bin: u16 = try asmbl.fmtOpCode(patId.?, args);

        print("Final binary: (hex, probably little endian) 0x{x}.\n", .{bin});
    } else
        print("No patterns matched '{}' (line: '{}')\n", .{ line, pattern });
}
