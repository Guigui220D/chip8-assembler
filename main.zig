const std = @import("std");
const asmbl = @import("assembler.zig");
const label = @import("labels.zig");

const allocator = std.heap.page_allocator;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var dir = std.fs.cwd();
    var args = std.process.args();
    _ = args.skip();

    //Arguments parsing
    var source: []u8 = undefined;
    if (args.next(allocator)) |src| {
        source = try src;
    } else {
        try stdout.print("You need to specify the file to assemble in the program arguments.\n", .{});
        return;
    }
    defer allocator.free(source);

    //Opening the file
    try stdout.print("Opening source file '{}'...\n", .{source});

    var src_file: ?std.fs.File = undefined;

    if (std.fs.path.isAbsolute(source)) {
        src_file = std.fs.openFileAbsolute(source, .{}) catch null;
    } else {
        src_file = std.fs.Dir.openFile(dir, source, .{}) catch null;
    }

    if (src_file) |source_file| {
        //File is open, do the thing
        defer source_file.close();

        try stdout.print("Creating output file '{}'...\n", .{"a.c8"});

        dir.deleteFile("a.c8") catch {};
        var out = try dir.createFile("a.c8", .{});

        try stdout.print("Formatting source...\n", .{});

        var loaded_program: []u8 = undefined;
        {
            var loaded = try source_file.readAllAlloc(allocator, (try source_file.stat()).size, std.math.maxInt(usize));
            defer allocator.free(loaded);

            //Replace CRLF with LF
            var buf_len = std.mem.replacementSize(u8, loaded, "\x0D\n", "\n");
            loaded_program = try allocator.alloc(u8, buf_len);

            _ = std.mem.replace(u8, loaded, "\x0D\n", "\n", loaded_program);
        }
        defer allocator.free(loaded_program);

        //Separate lines
        var lines = std.mem.tokenize(loaded_program[0..], "\n");

        try label.initLabels(allocator);
        defer label.deinit();

        try stdout.print("Assembly...\n", .{});

        var binary = try asmbl.assembleLines(lines, allocator);
        defer allocator.free(binary);

        _ = try out.write(binary);

        try stdout.print("Done!\n", .{});

    } else {
        try stdout.print("Source file could not be opened.\n", .{});
        return;
    }
}
