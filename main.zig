const std = @import("std");
const print = @import("std").debug.print;
const asmbl = @import("assembler.zig");
const instr = @import("instructions.zig");

const allocator = std.heap.page_allocator;

const assemblyError = error{unknownPattern};

pub fn main() !void {
    var dir = std.fs.cwd();
    dir.deleteFile("a.c8") catch {};

    var out = try dir.createFile("a.c8", .{});

    const testProgram = @embedFile("test-programs/blink.asm");

    var bufLen = std.mem.replacementSize(u8, testProgram, "\x0D\x0A", "\n");

    var buffer = try allocator.alloc(u8, bufLen);
    defer allocator.free(buffer);

    _ = std.mem.replace(u8, testProgram, "\x0D\x0A", "\n", buffer);

    var lines = std.mem.tokenize(buffer[0..], "\n");

    var line = lines.next();

    while (line != null) : (line = lines.next()) {
        print("Line: '{}'.\n", .{line.?});
        var tokens = std.mem.tokenize(line.?, " ");

        const pattern = try asmbl.getPattern(tokens, allocator);
        defer allocator.free(pattern);

        print("Pattern: '{}'\n", .{pattern});

        var patId = instr.matchPattern(pattern);

        print("Pattern id: '{}'\n", .{patId.?});

        if (patId == null)
            return assemblyError.unknownPattern;

        const args = try asmbl.extractArgs(tokens, instr.ops[patId.?], allocator);
        defer allocator.free(args);

        const bin: u16 = try asmbl.fmtOpCode(patId.?, args);

        _ = try out.write(@bitCast([2]u8, bin)[0..]);

        print("0x{x:0<4}\n", .{bin});
    }
}
