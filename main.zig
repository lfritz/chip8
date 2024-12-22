// build with `zig build-exe main.zig -lc -lraylib`
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const computer = @import("computer.zig");

const program =
    \\ 613c 6200
    \\ f00a 3001 120e
    \\ f118 1204
    \\ f218 1204
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

const all_keys = [_]c_int{
    ray.KEY_ZERO,
    ray.KEY_ONE,
    ray.KEY_TWO,
    ray.KEY_THREE,
    ray.KEY_FOUR,
    ray.KEY_FIVE,
    ray.KEY_SIX,
    ray.KEY_SEVEN,
    ray.KEY_EIGHT,
    ray.KEY_NINE,
    ray.KEY_A,
    ray.KEY_B,
    ray.KEY_C,
    ray.KEY_D,
    ray.KEY_E,
    ray.KEY_F,
};

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
    var c = try computer.Computer.init(allocator, @intCast(std.time.timestamp()));
    defer c.free();

    var sound = false;

    try loadProgram(program, c.memory[0x200..]);

    ray.InitWindow(screen_width, screen_height, title(sound));
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        var keys: u16 = 0;
        for (all_keys, 0..) |k, i| {
            if (ray.IsKeyDown(k)) {
                keys |= (@as(u16, 1) << @intCast(i));
                break;
            }
        }

        c.tick(keys) catch |err| {
            if (err == computer.Error.InvalidInstruction) {
                const addr = c.program_counter;
                const i = c.loadInstruction();
                ray.TraceLog(ray.LOG_ERROR, "invalid instruction at %03x: %04x", @as(c_int, addr), @as(c_int, i));
                return err;
            }
        };

        if (c.sound() != sound) {
            sound = !sound;
            ray.SetWindowTitle(title(sound));
        }

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

fn title(sound: bool) [*:0]const u8 {
    if (sound) {
        return "🔔 CHIP-8 🔔";
    }
    return "CHIP-8";
}
