const ops = @import("instructions.zig");
const tokens = @import("tokens.zig");
const chars = @import("chars.zig");
const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const assert = std.debug.assert;

const lineParseError = error {
    firstWordNotMnemonic,
    argumentError,
    lineTooLong
};

pub fn getPattern(iterator: std.mem.TokenIterator, allocator: *std.mem.Allocator) ![]u8 {
    var iter = iterator;

    const maxPatternLen = 8;

    var ret = try allocator.alloc(u8, maxPatternLen); //the longest pattern is 7 chars long
    errdefer allocator.free(ret);

    var size: usize = 0;

    {   //mnemonic
        var mnemonic = iter.next();

        if (mnemonic != null) {
            if (tokens.isMnemonic(mnemonic.?)) {
                std.mem.copy(u8, ret, mnemonic.?);
                size += std.mem.lenZ(mnemonic.?) + 1;
            } else {
                return lineParseError.firstWordNotMnemonic;
            }
        }
        else
           return lineParseError.firstWordNotMnemonic; 

        assert(size > 2);

        ret[size - 1] = '_';
    }

    //args

    var arg = iter.next();

    while (arg != null) {
        const c: u8 = arg.?[0];
        const argLen = std.mem.len(arg.?);

        switch (c) {
            '0' => {    //hex values
                if (argLen < 3 or argLen > 5)   //hex values should be 1 (nibble), 2 (byte) or 3 (address) characters
                    return lineParseError.argumentError;
                if (arg.?[1] != 'x')
                    return lineParseError.argumentError;    //hex values should start with 0x
                
                var i: usize = 2;
                while (i < argLen) {
                    if (!@call(.{ .modifier = .always_inline }, chars.isHexDigit, .{arg.?[i]})) //hex values should have lowercase digits
                        return lineParseError.argumentError;
                    i += 1;
                }

                ret[size] = switch (argLen) {
                    3 => 'N',
                    4 => 'O',
                    5 => 'P',
                    else => unreachable
                };
            },
            'V' => {    //V0-f registers
                if (argLen != 2)
                    return lineParseError.argumentError;
                const digit: u8 = arg.?[1];

                if (!@call(.{ .modifier = .always_inline }, chars.isHexDigit, .{digit}))
                    return lineParseError.argumentError;    //V register id should be lowercase hex digit
                
                ret[size] = digit;
            },
            'I', 'F', 'B' => {    //I register, F (font?) and B (BCD)
                if (argLen > 1)
                    return lineParseError.argumentError;
                ret[size] = c;
            },
            'D', 'S' => {    //Delay and Sound timer register (DT and ST)
                if (argLen != 2)
                    return lineParseError.argumentError;
                if (arg.?[1] != 'T')
                    return lineParseError.argumentError;
                ret[size] = c;
            },
            '[' => {    //[I]
                if (argLen != 3)
                    return lineParseError.argumentError;
                if (arg.?[1] != 'I')
                    return lineParseError.argumentError;
                if (arg.?[2] != ']')
                    return lineParseError.argumentError;
                ret[size] = 'A';
            },
            else => {
                return lineParseError.argumentError;
            }
        }

        size += 1;

        if (size >= maxPatternLen)
            return lineParseError.lineTooLong;

        arg = iter.next();
    }
    
    ret = allocator.shrink(ret, size);

    return ret;
}

pub fn extractArgs(iterator: std.mem.TokenIterator, model: []const u8, allocator: *std.mem.Allocator) ![]u8 {
    var iter = iterator;

    var digits: usize = 0;
    var ret = try allocator.alloc(u8, 3);
    errdefer allocator.free(ret);

    _ = iter.next();    //skip mnemonic

    var argsPart = false;

    for (model) |c| {
        if (!argsPart)
        {
            if (c == '_')
                argsPart = true;
            continue;
        }   //ignore before the _ (mnemonic)

        var arg = iter.next().?;  //previous steps should make sure all the args are here, no need to make sure optional is not null
        
        switch (c) {
            'V' => {    //V register id
                if (arg[0] != 'V')  
                    unreachable;
                ret[digits] = arg[1];
                digits += 1;
            },
            'N', 'O', 'P' => {    //Nibble
                if (arg[0] != '0')  
                    unreachable;

                var i: usize = 2;

                while (i < std.mem.len(arg)) {
                    ret[digits] = arg[i];
                    digits += 1;
                    i += 1;
                }
            },
            else => {}
        }
    }

    ret = allocator.shrink(ret, digits);

    return ret;
}

pub fn fmtOpCode(patternId: usize, arguments: []u8) !u16 {
    var buf: [4]u8 = undefined;
    const pattern = ops.codes[patternId];

    var i: usize = 0;
    var j: usize = 0;

    while (i < 4) {
        var c: u8 = pattern[i];
        buf[i] = c;

        if (c == '_') {
            buf[i] = arguments[j];
            j += 1;
        }

        i += 1;
    }
    
    var ret: [2]u8 = undefined;

    try std.fmt.hexToBytes(ret[0..], buf[0..]);

    return @bitCast(u16, ret);
}

const test_allocator = std.heap.page_allocator;

//getPattern tests
test "getPattern mnemonic only" 
{ 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("AB", " "), test_allocator), "AB_")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("EEEE", " "), test_allocator), "EEEE_")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("AE ", " "), test_allocator), "AE_")); 
}

test "getPattern firstWordNotMnemonic error" { 
    expectError(lineParseError.firstWordNotMnemonic, getPattern(std.mem.tokenize("aa", " "), test_allocator));
    expectError(lineParseError.firstWordNotMnemonic, getPattern(std.mem.tokenize("O", " "), test_allocator));
    expectError(lineParseError.firstWordNotMnemonic, getPattern(std.mem.tokenize("OOOOO", " "), test_allocator));
} 

test "getPattern hex argument" 
{ 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("BYTE 0x3f", " "), test_allocator), "BYTE_O")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("ADDR 0x100", " "), test_allocator), "ADDR_P")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("NIBL 0xb", " "), test_allocator), "NIBL_N")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("NOP 0x0 0x00 0x000", " "), test_allocator), "NOP_NOP")); 

    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("AA 0x0000", " "), test_allocator));
    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("AA 0x", " "), test_allocator));
    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("AA 0xg", " "), test_allocator));
}

test "getPattern register arguments" 
{ 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("DT DT", " "), test_allocator), "DT_D")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("ST ST", " "), test_allocator), "ST_S")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("III I", " "), test_allocator), "III_I")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("ARR [I]", " "), test_allocator), "ARR_A")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("FF F", " "), test_allocator), "FF_F")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("BB B", " "), test_allocator), "BB_B")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("VV V0", " "), test_allocator), "VV_0")); 
    expect(std.mem.eql(u8, try getPattern(std.mem.tokenize("VC Vc", " "), test_allocator), "VC_c")); 

    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("AH [", " "), test_allocator));
    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("DT D", " "), test_allocator));
    expectError(lineParseError.argumentError, getPattern(std.mem.tokenize("ST S", " "), test_allocator));
}

test "getPattern lineTooLong error" 
{ 
    expectError(lineParseError.lineTooLong, getPattern(std.mem.tokenize("AAAA I I I I", " "), test_allocator));
}



