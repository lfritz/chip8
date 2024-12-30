const std = @import("std");

// Screen represents the 64x32-pixel CHIP-8 screen.
pub const Screen = struct {
    rows: [0x20]u64,

    // Create a new Screen with undefined pixel values.
    pub fn init() Screen {
        return Screen{
            .rows = [_]u64{undefined} ** 0x20,
        };
    }

    // Set all pixels to false.
    pub fn clear(self: *Screen) void {
        for (&self.rows) |*row| {
            row.* = 0;
        }
    }

    // Get the current value of a pixel.
    pub fn get(self: *const Screen, x: u6, y: u6) bool {
        if (y >= 0x20)
            return false;
        return self.rows[y] & (@as(u64, 1) << (0x3f - x)) != 0;
    }

    // Draw a sprite to the screen. Each value in 'sprite' is one row of pixels; its length should
    // be between 1 and 15.
    pub fn draw(self: *Screen, x: u6, y: u6, sprite: []const u8) !bool {
        // make sure we're not trying to draw beyond the last row
        var sprite_rows = sprite;
        if (y + sprite_rows.len > 0x20)
            sprite_rows = sprite_rows[0..(0x20 - y)];

        // determine how to shift each sprite row left or right
        var shift_left: u6 = 0;
        var shift_right: u6 = 0;
        if (x < 0x38) {
            shift_left = 0x38 - x;
        } else {
            shift_right = x - 0x38;
        }

        // draw sprite rows
        var result = false;
        for (sprite_rows, y..) |v, i| {
            var mask: u64 = @as(u64, v);
            mask >>= shift_right;
            mask <<= shift_left;
            result = result or ((self.rows[i] & mask) != 0);
            self.rows[i] ^= mask;
        }
        return result;
    }
};

test "Screen.clear clears the screen" {
    var screen = Screen.init();
    screen.clear();
    for (0..0x20) |y| {
        try std.testing.expect(screen.rows[y] == 0);
    }
}

test "Screen.get returns pixel value" {
    var screen = Screen.init();
    screen.clear();
    screen.rows[3] = 0x0100000000000000; // pixel (7, 3) is on
    try std.testing.expect(screen.get(6, 3) == false);
    try std.testing.expect(screen.get(7, 2) == false);
    try std.testing.expect(screen.get(7, 3));
    try std.testing.expect(screen.get(7, 4) == false);
    try std.testing.expect(screen.get(8, 3) == false);
}

test "Screen.get returns false for out-of-bounds coordinates" {
    var screen = Screen.init();
    screen.clear();

    // screen corners, not out of bounds
    try std.testing.expect(screen.get(0x00, 0x00) == false);
    try std.testing.expect(screen.get(0x3f, 0x00) == false);
    try std.testing.expect(screen.get(0x00, 0x1f) == false);
    try std.testing.expect(screen.get(0x3f, 0x1f) == false);

    // out of bounds
    try std.testing.expect(screen.get(0x00, 0x20) == false);
    try std.testing.expect(screen.get(0x20, 0x20) == false);
    try std.testing.expect(screen.get(0x3f, 0x20) == false);
    try std.testing.expect(screen.get(0x00, 0x3f) == false);
}

test "Screen.draw draws a 1-byte sprite in the top-left corner" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{0x5a};
    const flipped = try screen.draw(0x0, 0x0, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x0, 0x0) == false);
    try std.testing.expect(screen.get(0x1, 0x0));
    try std.testing.expect(screen.get(0x2, 0x0) == false);
    try std.testing.expect(screen.get(0x3, 0x0));
    try std.testing.expect(screen.get(0x4, 0x0));
    try std.testing.expect(screen.get(0x5, 0x0) == false);
    try std.testing.expect(screen.get(0x6, 0x0));
    try std.testing.expect(screen.get(0x7, 0x0) == false);
}

test "Screen.draw returns true if a pixel was flipped from on to off" {
    var screen = Screen.init();
    screen.clear();

    {
        // draw one pixel at (7, 0)
        const sprite = [_]u8{0x01};
        const flipped = try screen.draw(0x0, 0x0, &sprite);
        try std.testing.expect(!flipped);
        try std.testing.expect(screen.get(0x7, 0x0));
    }
    {
        // draw empty sprite; should do nothing
        const sprite = [_]u8{0x00};
        const flipped = try screen.draw(0x0, 0x0, &sprite);
        try std.testing.expect(!flipped);
        try std.testing.expect(screen.get(0x7, 0x0));
    }
    {
        // flip the pixel at (7, 0)
        const sprite = [_]u8{0x10};
        const flipped = try screen.draw(0x4, 0x0, &sprite);
        try std.testing.expect(flipped);
        try std.testing.expect(screen.get(0x7, 0x0) == false);
    }
}

test "Screen.draw draws a 1-byte sprite" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{0x5a};
    const flipped = try screen.draw(0xa, 0xb, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0xa, 0xb) == false);
    try std.testing.expect(screen.get(0xb, 0xb));
    try std.testing.expect(screen.get(0xc, 0xb) == false);
    try std.testing.expect(screen.get(0xd, 0xb));
    try std.testing.expect(screen.get(0xe, 0xb));
    try std.testing.expect(screen.get(0xf, 0xb) == false);
    try std.testing.expect(screen.get(0x10, 0xb));
    try std.testing.expect(screen.get(0x11, 0xb) == false);
}

test "Screen.draw draws a 4-byte sprite" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{ 0x01, 0x07, 0x3f, 0xff };
    const flipped = try screen.draw(0x20, 0x10, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x26, 0x10) == false);
    try std.testing.expect(screen.get(0x27, 0x10));
    try std.testing.expect(screen.get(0x24, 0x11) == false);
    try std.testing.expect(screen.get(0x25, 0x11));
    try std.testing.expect(screen.get(0x21, 0x12) == false);
    try std.testing.expect(screen.get(0x22, 0x12));
    try std.testing.expect(screen.get(0x20, 0x13));
}

test "Screen.draw draws a 16-byte sprite" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{
        0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01,
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
    };
    const flipped = try screen.draw(0x38, 0x10, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x38, 0x10));
    try std.testing.expect(screen.get(0x39, 0x10) == false);

    try std.testing.expect(screen.get(0x3e, 0x18) == false);
    try std.testing.expect(screen.get(0x3f, 0x18));

    try std.testing.expect(screen.get(0x38, 0x1f));
    try std.testing.expect(screen.get(0x39, 0x1f) == false);
}

test "Screen.draw handles drawing off screen" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{ 0xff, 0xff, 0xff, 0xff }; // 8x4 sprite

    const flipped = try screen.draw(0x00, 0x20, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x00, 0x1f) == false);
}

test "Screen.draw handles drawing partially off screen (horizontal)" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{ 0xff, 0xff, 0xff, 0xff }; // 8x4 sprite
    const flipped = try screen.draw(0x39, 0x00, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x38, 0x00) == false);
    try std.testing.expect(screen.get(0x38, 0x01) == false);
    try std.testing.expect(screen.get(0x38, 0x02) == false);
    try std.testing.expect(screen.get(0x38, 0x03) == false);
    try std.testing.expect(screen.get(0x39, 0x00));
    try std.testing.expect(screen.get(0x39, 0x01));
    try std.testing.expect(screen.get(0x39, 0x02));
    try std.testing.expect(screen.get(0x39, 0x03));
    try std.testing.expect(screen.get(0x39, 0x04) == false);
}

test "Screen.draw handles drawing partially off screen (vertical)" {
    var screen = Screen.init();
    screen.clear();

    const sprite = [_]u8{ 0xff, 0xff, 0xff, 0xff }; // 8x4 sprite
    const flipped = try screen.draw(0x00, 0x1f, &sprite);
    try std.testing.expect(!flipped);

    try std.testing.expect(screen.get(0x00, 0x1e) == false);
    try std.testing.expect(screen.get(0x01, 0x1e) == false);
    try std.testing.expect(screen.get(0x02, 0x1e) == false);
    try std.testing.expect(screen.get(0x03, 0x1e) == false);
    try std.testing.expect(screen.get(0x04, 0x1e) == false);
    try std.testing.expect(screen.get(0x05, 0x1e) == false);
    try std.testing.expect(screen.get(0x06, 0x1e) == false);
    try std.testing.expect(screen.get(0x07, 0x1e) == false);

    try std.testing.expect(screen.get(0x00, 0x1f));
    try std.testing.expect(screen.get(0x01, 0x1f));
    try std.testing.expect(screen.get(0x02, 0x1f));
    try std.testing.expect(screen.get(0x03, 0x1f));
    try std.testing.expect(screen.get(0x04, 0x1f));
    try std.testing.expect(screen.get(0x05, 0x1f));
    try std.testing.expect(screen.get(0x06, 0x1f));
    try std.testing.expect(screen.get(0x07, 0x1f));

    try std.testing.expect(screen.get(0x08, 0x1f) == false);
}
