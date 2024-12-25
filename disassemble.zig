const std = @import("std");

pub fn main() !void {
    const args = std.os.argv[1..];
    if (args.len != 2) {
        const writer = std.io.getStdErr().writer();
        try writer.print("Usage: {s} INPUT OUTPUT\n", .{std.os.argv[0]});
        try writer.print("Read binary CHIP-8 program and write as hex numbers\n", .{});
        std.process.exit(1);
    }

    const source_path = std.mem.sliceTo(args[0], 0);
    const target_path = std.mem.sliceTo(args[1], 0);

    const dir = std.fs.cwd();
    const source_file = try dir.openFile(source_path, .{});
    defer source_file.close();
    const target_file = try dir.createFile(target_path, .{});
    defer target_file.close();
    const reader = source_file.reader();
    const writer = target_file.writer();

    var count: usize = 0;
    while (true) {
        if (count != 0) {
            if (count % 16 == 0) {
                try writer.print("\n", .{});
            } else {
                try writer.print(" ", .{});
            }
        }
        const hi = reader.readByte() catch |err| {
            if (err == error.EndOfStream) {
                break;
            }
            return err;
        };
        const lo = try reader.readByte();
        try writer.print("{x:02}{x:02}", .{ hi, lo });
        count += 1;
    }
    try writer.print("\n", .{});
}
