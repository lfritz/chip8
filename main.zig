// build with `zig build-exe main.zig -lc -lraylib`
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const computer = @import("computer.zig");

const program =
    \\ 600c f029 6100 6200 d125
    \\ 600a f029 6105 d125
    \\ 600f f029 610a d125
    \\ 600e f029 610f d125
    \\ 0000
;

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

fn loadProgram(code: []const u8, memory: []u8) !void {
    var nybble: ?u8 = null;
    var index: usize = 0;
    for (code) |c| {
        const h = parseHex(c) catch {
            continue;
        };
        if (nybble == null) {
            nybble = h;
        } else {
            const value = (nybble.? << 4) | h;
            nybble = null;
            memory[index] = value;
            index += 1;
        }
    }
    if (nybble != null)
        return ParseError.UnexpectedEnd;
}

test "loadProgram loads valid program" {
    var memory = [_]u8{0x00} ** 0xa;
    try loadProgram("600c f029 6100 6200 d125", &memory);
    try std.testing.expect(memory[0] == 0x60);
    try std.testing.expect(memory[1] == 0x0c);
    try std.testing.expect(memory[2] == 0xf0);
    try std.testing.expect(memory[3] == 0x29);
    try std.testing.expect(memory[4] == 0x61);
    try std.testing.expect(memory[5] == 0x00);
    try std.testing.expect(memory[6] == 0x62);
    try std.testing.expect(memory[7] == 0x00);
    try std.testing.expect(memory[8] == 0xd1);
    try std.testing.expect(memory[9] == 0x25);
}

pub fn main() !void {
    const zoom = 5;
    const width = 0x40;
    const height = 0x20;
    const border = 2;
    const pixel_width = -border + (1 << zoom) - border;

    const color = ray.ORANGE;
    const bgcolor = ray.BLACK;

    const screen_width = width << zoom;
    const screen_height = height << zoom;

    const allocator: std.mem.Allocator = std.heap.c_allocator;
    var c = try computer.Computer.init(allocator);
    defer c.free();

    try loadProgram(program, c.memory[0x200..]);

    ray.InitWindow(screen_width, screen_height, "CHIP-8");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        c.tick() catch |err| {
            if (err == computer.CPUError.InvalidInstruction) {
                const addr = c.program_counter;
                const i = c.loadInstruction();
                ray.TraceLog(ray.LOG_ERROR, "invalid instruction at %03x: %04x", @as(c_int, addr), @as(c_int, i));
                return err;
            }
        };

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(bgcolor);
        for (0..height) |row| {
            for (0..width) |col| {
                const x: u6 = @intCast(col);
                const y: u6 = @intCast(row);
                if (try c.screen.get(x, y)) {
                    const cx: c_int = @intCast(col);
                    const cy: c_int = @intCast(row);
                    ray.DrawRectangle(
                        (cx << zoom) + border,
                        (cy << zoom) + border,
                        pixel_width,
                        pixel_width,
                        color,
                    );
                }
            }
        }
    }
}
