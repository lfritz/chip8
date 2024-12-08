const std = @import("std");
const cpu = @import("cpu.zig");
const CPU = cpu.CPU;

const Computer = struct {
    allocator: std.mem.Allocator,
    cpu: CPU,
    memory: []u8,

    fn init(allocator: std.mem.Allocator) !Computer {
        const memory = try allocator.alloc(u8, 0x1000);
        return Computer{
            .allocator = allocator,
            .cpu = CPU.init(memory),
            .memory = memory,
        };
    }

    fn free(self: *Computer) void {
        self.allocator.free(self.memory);
    }
};

test "init and free Computer" {
    var computer = try Computer.init(std.testing.allocator);
    computer.free();
}
