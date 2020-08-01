const ops = @import("instructions.zig");
const token = @import("tokens.zig");
const chars = @import("chars.zig");
const labels = @import("labels.zig");
const instr = @import("instructions.zig");
const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const assert = std.debug.assert;

const lineParseError = error { 
    firstWordNotMnemonic, 
    argumentError, 
    lineTooLong
};

fn getPattern(iterator: std.mem.TokenIterator, allocator: *std.mem.Allocator) ![]u8 {
    var iter = iterator;

    const max_pattern_len = 8;

    var ret = try allocator.alloc(u8, max_pattern_len); //the longest pattern is 7 chars long
    errdefer allocator.free(ret);

    var size: usize = 0;

    { //mnemonic
        var mnemonic = iter.next();

        if (mnemonic != null) {
            if (token.isMnemonic(mnemonic.?)) {
                std.mem.copy(u8, ret, mnemonic.?);
                size += std.mem.lenZ(mnemonic.?) + 1;
            } else {
                return lineParseError.firstWordNotMnemonic;
            }
        } else
            return lineParseError.firstWordNotMnemonic;

        assert(size > 2);

        ret[size - 1] = '_';
    }

    //args
    while (iter.next()) |arg| {
        const c: u8 = arg[0];
        const arg_len = std.mem.len(arg);

        switch (c) {
            '0' => { //hex values
                if (arg_len < 3 or arg_len > 5) //hex values should be 1 (nibble), 2 (byte) or 3 (address) characters
                    return lineParseError.argumentError;
                if (arg[1] != 'x')
                    return lineParseError.argumentError; //hex values should start with 0x

                var i: usize = 2;
                while (i < arg_len) {
                    if (!@call(.{ .modifier = .always_inline }, chars.isHexDigit, .{arg[i]})) //hex values should have lowercase digits
                        return lineParseError.argumentError;
                    i += 1;
                }

                ret[size] = switch (arg_len) {
                    3 => 'N',
                    4 => 'O',
                    5 => 'P',
                    else => unreachable,
                };
            },
            ':' => { //label as an address
                if (arg_len == 1)
                    return lineParseError.argumentError;
                
                const label_name = arg[1..];

                if (!token.isLabel(label_name))
                    return lineParseError.argumentError;

                ret[size] = 'P';
            },
            'V' => { //V0-f registers
                if (arg_len != 2)
                    return lineParseError.argumentError;
                const digit: u8 = arg[1];

                if (!@call(.{ .modifier = .always_inline }, chars.isHexDigit, .{digit}))
                    return lineParseError.argumentError; //V register id should be lowercase hex digit

                ret[size] = digit;
            },
            'I', 'F', 'B' => { //I register, F (font?) and B (BCD)
                if (arg_len > 1)
                    return lineParseError.argumentError;
                ret[size] = c;
            },
            'D', 'S' => { //Delay and Sound timer register (DT and ST)
                if (arg_len != 2)
                    return lineParseError.argumentError;
                if (arg[1] != 'T')
                    return lineParseError.argumentError;
                ret[size] = c;
            },
            '[' => { //[I]
                if (arg_len != 3)
                    return lineParseError.argumentError;
                if (arg[1] != 'I')
                    return lineParseError.argumentError;
                if (arg[2] != ']')
                    return lineParseError.argumentError;
                ret[size] = 'A';
            },
            else => {
                return lineParseError.argumentError;
            },
        }

        size += 1;

        if (size >= max_pattern_len)
            return lineParseError.lineTooLong;
    }

    ret = allocator.shrink(ret, size);

    return ret;
}

fn extractArgs(iterator: std.mem.TokenIterator, model: []const u8, allocator: *std.mem.Allocator) ![]u8 {
    var iter = iterator;

    var digits: usize = 0;
    var ret = try allocator.alloc(u8, 3);
    errdefer allocator.free(ret);

    _ = iter.next(); //skip mnemonic

    var args_part = false;

    for (model) |c| {
        if (!args_part) {
            if (c == '_')
                args_part = true;
            continue;
        } //ignore before the _ (mnemonic)

        var arg = iter.next().?; //previous steps should make sure all the args are here, no need to make sure optional is not null

        switch (c) {
            'V' => { //V register id
                if (arg[0] != 'V')
                    unreachable;
                ret[digits] = arg[1];
                digits += 1;
            },
            'N', 'O', 'P' => { //numbers
                if (arg[0] != '0')
                {
                    if (arg[0] == ':' and c == 'P') {   //as a label
                        var label_name = arg[1..];
                        var addr = labels.getLabelAddress(label_name);

                        if (addr) |address| {
                            var buf: [3]u8 = undefined;
                            _ = try std.fmt.bufPrint(buf[0..], "{x:0<3}", .{addr});
                            for (buf) |d| {
                                ret[digits] = d;
                                digits += 1;
                            }
                        } else return lineParseError.argumentError;

                    } else unreachable;
                } else {    //as an hex value
                    for (arg) |d, i| {
                        if (i < 2) continue; //ignore 0x
                        ret[digits] = d;
                        digits += 1;
                    }
                }
            },
            else => {},
        }
    }

    ret = allocator.shrink(ret, digits);

    return ret;
}

fn fmtOpCode(pattern_id: usize, arguments: []u8) !u16 {
    var buf: [4]u8 = undefined;
    const pattern = ops.codes[pattern_id];

    var i: usize = 0;
    var j: usize = 0;

    while (i < 4) : (i += 1) {
        var c: u8 = pattern[i];
        buf[i] = c;

        if (c == '_') {
            buf[i] = arguments[j];
            j += 1;
        }
    }

    var ret: [2]u8 = undefined;

    try std.fmt.hexToBytes(ret[0..], buf[0..]);

    return @bitCast(u16, ret);
}

const assemblyError = error{
    unknownPattern,
    unimplemented
};

pub fn assembleLines(line_iter: std.mem.TokenIterator, allocator: *std.mem.Allocator) ![]u8 {
    try labels.parseLabels(line_iter);
    
    var iter_cpy = line_iter;

    var allocated: usize = 64;
    var used: usize = 0;
    var buffer: []u8 = try allocator.alloc(u8, allocated);

    while (iter_cpy.next()) |line| {
        if (line[0] == '#')
            return assemblyError.unimplemented;   //TODO: compiler directives
        if (line[0] == ':')
            continue;

        var tokens = std.mem.tokenize(line, " ");

        const pattern = try getPattern(tokens, allocator);
        defer allocator.free(pattern);

        var pat_id = instr.matchPattern(pattern);

        if (pat_id) |pattern_id| {
            const args = try extractArgs(tokens, instr.ops[pattern_id], allocator);
            defer allocator.free(args);

            const bin: u16 = try fmtOpCode(pattern_id, args);

            used += @sizeOf(u16);

            std.mem.copy(u8, buffer[used-2..used], @bitCast([2]u8, bin)[0..]);

            if (used >= allocated) {
                allocated *= 2;
                buffer = try allocator.realloc(buffer, allocated);
            }

        } else
            return assemblyError.unknownPattern;
    }

    return buffer;
}