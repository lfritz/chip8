const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const computer = @import("computer.zig");
const screen = @import("screen.zig");

pub const ParseError = error{
    InvalidCharacter,
    UnexpectedEnd,
};

fn loadBinary(reader: std.fs.File.Reader, memory: []u8) !void {
    _ = try reader.readAll(memory);
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

    const args = std.os.argv[1..];
    if (args.len == 1) {
        const dir = std.fs.cwd();
        const path = std.mem.sliceTo(args[0], 0);
        const file = try dir.openFile(path, .{});
        defer file.close();
        try loadBinary(file.reader(), c.memory[0x200..]);
    } else {
        const writer = std.io.getStdErr().writer();
        try writer.print("Usage: {s} FILENAME\n", .{std.os.argv[0]});
        std.process.exit(1);
    }

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
            switch (err) {
                computer.Error.InvalidInstruction => {
                    const addr = c.program_counter;
                    const i = c.loadInstruction();
                    ray.TraceLog(ray.LOG_ERROR, "invalid instruction at %03x: %04x", @as(c_int, addr), @as(c_int, i));
                    return err;
                },
                computer.Error.StackOverflow => {
                    ray.TraceLog(ray.LOG_ERROR, "stack overflow");
                    return err;
                },
                computer.Error.StackUnderflow => {
                    ray.TraceLog(ray.LOG_ERROR, "stack underflow");
                    return err;
                },
                computer.Error.InvalidKey => {
                    ray.TraceLog(ray.LOG_ERROR, "invalid key");
                    return err;
                },
                screen.ScreenError.OutOfBounds => {
                    ray.TraceLog(ray.LOG_ERROR, "screen coordinate out of bounds");
                    return err;
                },
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
