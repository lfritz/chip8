// build with `zig build-exe main.zig -lc -lraylib`
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn main() void {
    const zoom = 4;
    const width = 0x40;
    const height = 0x20;

    const color = ray.ORANGE;
    const bgcolor = ray.BLACK;

    const screenWidth = width << zoom;
    const screenHeight = height << zoom;

    ray.InitWindow(screenWidth, screenHeight, "CHIP-8");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        // draw the corner pixels
        ray.ClearBackground(bgcolor);
        ray.DrawRectangle(0, 0, 0x10, 0x10, color);
        ray.DrawRectangle(0x3f << zoom, 0, 0x10, 0x10, color);
        ray.DrawRectangle(0, 0x1f << zoom, 0x10, 0x10, color);
        ray.DrawRectangle(0x3f << zoom, 0x1f << zoom, 0x10, 0x10, color);
    }
}
