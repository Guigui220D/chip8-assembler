const std = @import("std");
const chars = @import("chars.zig");
const token = @import("tokens.zig");
const hashmap = std.hash_map;

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

        const label_name = line[1..];

        if (!token.isLabel(label_name))
            return labellingError.wrongFormat;

        if (labels.contains(label_name))
            return labellingError.duplicateLabel;

        try labels.put(label_name, address);
    }
}