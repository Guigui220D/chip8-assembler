const std = @import("std");
const chars = @import("chars.zig");
const hashmap = std.hash_map;

const max_label_length: usize = 16;

const program_begin: u12 = 0x200;

const hmtype = hashmap.StringHashMap(u12);
var labels: hmtype = undefined;

pub fn initLabels(allocator: *std.mem.Allocator) !void {
    labels = hmtype.init(allocator);
    try labels.put("program", program_begin);
}

pub fn deinit() void {
    labels.deinit();
}

pub fn getLabelAddress(label: []const u8) ?u12 {
    return labels.get(label);
}

const labellingError = error {
    duplicateLabel,
    wrongFormat
};

pub fn parseLabels(iterator: std.mem.TokenIterator) !void {
    var iter = iterator;

    var address: u12 = program_begin;

    while (iter.next()) |line| {
        if (line[0] != ':')
        {
            if (line[0] != '#')
                address += 2;
            continue;
        } 

        if (std.mem.len(line) == 1)
            return labellingError.wrongFormat;

        const labelName = line[1..];

        if (std.mem.len(labelName) > max_label_length)
            return labellingError.wrongFormat;

        for (labelName) |c| {
            if (!@call(.{ .modifier = .always_inline }, chars.isLetter, .{c}))
                return labellingError.wrongFormat;
        }

        if (labels.contains(labelName))
            return labellingError.duplicateLabel;

        try labels.put(labelName, address);
    }
}