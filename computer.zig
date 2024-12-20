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
        var computer = Computer{
            .allocator = allocator,
            .cpu = CPU.init(memory, &screen),
            .memory = memory,
            .screen = screen, // TODO this makes a copy of 'screen'
        };
    }

    pub fn free(self: *Computer) void {
        self.allocator.free(self.memory);
    }

    pub fn tick(self: *Computer) !void {
        try self.cpu.tick();
    }
};

test "init and free Computer" {
    var computer = try Computer.init(std.testing.allocator);
    computer.free();
}
