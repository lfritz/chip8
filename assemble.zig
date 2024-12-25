const std = @import("std");

pub fn main() !void {
    const args = std.os.argv[1..];
    if (args.len != 2) {
        const writer = std.io.getStdErr().writer();
        try writer.print("Usage: {s} INPUT OUTPUT\n", .{std.os.argv[0]});
        try writer.print("Read hexadecimal CHIP-8 program and write binary\n", .{});
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

    var nybble: ?u8 = null;
    while (true) {
        const byte = reader.readByte() catch |err| {
            if (err == error.EndOfStream) {
                break;
            }
            return err;
        };
        const h = parseHex(byte) catch {
            continue;
        };
        if (nybble == null) {
            nybble = h;
        } else {
            const value = (nybble.? << 4) | h;
            nybble = null;
            try writer.writeByte(value);
        }
    }
    if (nybble != null)
        return ParseError.UnexpectedEnd;
}

pub const ParseError = error{
    InvalidCharacter,
    UnexpectedEnd,
};

fn parseHex(c: u8) !u4 {
    if (c >= '0' and c <= '9')
        return @intCast(c - '0');
    if (c >= 'a' and c <= 'f')
        return @intCast(c - 'a' + 0xa);
    return ParseError.InvalidCharacter;
}

test "parseHex parses hex digits" {
    try std.testing.expectEqual(0x0, try parseHex('0'));
    try std.testing.expectEqual(0x5, try parseHex('5'));
    try std.testing.expectEqual(0x9, try parseHex('9'));
    try std.testing.expectEqual(0x1, try parseHex('1'));
    try std.testing.expectEqual(0xc, try parseHex('c'));
    try std.testing.expectEqual(0xf, try parseHex('f'));
}
