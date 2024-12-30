// The CHIP-8 emulator. Loads a binary CHIP-8 program from a file passed on the command-line.
//
// See README.md for how to build and run the emulator.

const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const computer = @import("computer.zig");
const screen = @import("screen.zig");

const hex_keys = [_]c_int{
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
    // settings -- change values here to change the emulator's behavior
    const speedup = 8;
    const zoom = 5;
    const border = 0;
    const color = ray.ORANGE;
    const bgcolor = ray.BLACK;

    // set constants and initialize variables
    const width = 0x40;
    const height = 0x20;
    const pixel_width = -border + (1 << zoom) - border;
    var sound = false;

    // set up Computer
    const allocator: std.mem.Allocator = std.heap.c_allocator;
    var c = try computer.Computer.init(allocator, @intCast(std.time.timestamp()));
    defer c.free();

    // parse arguments
    const args = std.os.argv[1..];
    if (args.len == 1) {
        const dir = std.fs.cwd();
        const path = std.mem.sliceTo(args[0], 0);
        const file = try dir.openFile(path, .{});
        defer file.close();
        _ = try file.reader().readAll(c.memory[0x200..]);
    } else {
        const writer = std.io.getStdErr().writer();
        try writer.print("Usage: {s} FILENAME\n", .{std.os.argv[0]});
        std.process.exit(1);
    }

    // set up raylib
    ray.InitWindow(width << zoom, height << zoom, title(sound));
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        // check hex keys to see which are pressed
        var keys: u16 = 0;
        for (hex_keys, 0..) |k, i| {
            if (ray.IsKeyDown(k)) {
                keys |= (@as(u16, 1) << @intCast(i));
                break;
            }
        }

        // check arrow keys
        if (ray.IsKeyDown(ray.KEY_UP)) {
            keys |= (@as(u16, 1) << @intCast(2));
        }
        if (ray.IsKeyDown(ray.KEY_DOWN)) {
            keys |= (@as(u16, 1) << @intCast(8));
        }
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            keys |= (@as(u16, 1) << @intCast(4));
        }
        if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            keys |= (@as(u16, 1) << @intCast(6));
        }

        // evaluate instructions
        for (0..speedup) |_| {
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
                }
            };
        }

        // update window title to show/not show sound symbol
        if (c.sound() != sound) {
            sound = !sound;
            ray.SetWindowTitle(title(sound));
        }

        // draw screen
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(bgcolor);
        for (0..height) |row| {
            for (0..width) |col| {
                const x: u6 = @intCast(col);
                const y: u6 = @intCast(row);
                if (c.screen.get(x, y)) {
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
