pub fn isHexDigit(char: u8) bool {
    return (char >= '0' and char <= '9') or (char >= 'a' and char <= 'f');
}

pub fn isUppercaseLetter(char: u8) bool {
    return char >= 'A' and char <= 'Z';
}

pub fn isLowercaseLetter(char: u8) bool {
    return char >= 'a' and char <= 'z';
}

pub fn isLetter(char: u8) bool {
    return @call(.{ .modifier = .always_inline }, isLowercaseLetter, .{char}) or @call(.{ .modifier = .always_inline }, isUppercaseLetter, .{char});
}
