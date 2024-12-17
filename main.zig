// build with `zig build-exe main.zig -lc -lraylib`
const ray = @cImport({
    @cInclude("raylib.h");
});
const screen = @import("screen.zig");
const std = @import("std");

pub fn main() void {
    const zoom = 5;
    const width = 0x40;
    const height = 0x20;
    const border = 2;
    const pixel_width = -border + (1 << zoom) - border;

    const color = ray.ORANGE;
    const bgcolor = ray.BLACK;

    const screen_width = width << zoom;
    const screen_height = height << zoom;

    // draw an arrow in the top-left corner
    var scr = screen.Screen.init();
    const sprite = [_]u8{
        0b00001000,
        0b00011100,
        0b00111110,
        0b01111111,
        0b00011100,
        0b00011100,
        0b00011100,
        0b00011100,
        0b00011100,
    };
    _ = scr.draw(0, 1, &sprite);

    ray.InitWindow(screen_width, screen_height, "CHIP-8");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(bgcolor);
        for (0..height) |row| {
            for (0..width) |col| {
                const x: u6 = @intCast(col);
                const y: u6 = @intCast(row);
                if (scr.get(x, y)) {
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
