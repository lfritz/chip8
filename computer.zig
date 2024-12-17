const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Screen = @import("screen.zig").Screen;

pub const Computer = struct {
    allocator: std.mem.Allocator,
    cpu: CPU,
    memory: []u8,
    screen: Screen,

    pub fn init(allocator: std.mem.Allocator) !Computer {
        const memory = try allocator.alloc(u8, 0x1000);
        var screen = Screen.init();
        return Computer{
            .allocator = allocator,
            .cpu = CPU.init(memory, &screen),
            .memory = memory,
            .screen = screen,
        };
    }

    pub fn free(self: *Computer) void {
        self.allocator.free(self.memory);
    }
};

test "init and free Computer" {
    var computer = try Computer.init(std.testing.allocator);
    computer.free();
}
