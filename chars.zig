pub fn isHexDigit(char: u8) bool {
    return (char >= '0' and char <= '9') or (char >= 'a' and char <= 'f');
}

pub fn isUppercaseLetter(char: u8) bool {
    return char >= 'A' and char <= 'Z';
}

