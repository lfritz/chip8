const std = @import("std");

const CPUError = error{
    InvalidInstruction,
};

const CPU = struct {
    registers: [16]u8,

    fn init() CPU {
        return CPU{
            .registers = [_]u8{undefined} ** 16,
        };
    }
};

const Computer = struct {
    cpu: CPU,

    fn init() Computer {
        return Computer{
            .cpu = CPU.init(),
        };
    }

    fn evaluate(self: *Computer, instruction: u16) !void {
        const nybbles = splitInstruction(instruction);
        switch (nybbles[0]) {
            0x6 => {
                self.cpu.registers[nybbles[1]] = @intCast(instruction & 0x00ff);
            },
            else => {
                return CPUError.InvalidInstruction;
            },
        }
    }
};

fn splitInstruction(instruction: u16) [4]u4 {
    return [_]u4{
        @intCast((instruction & 0xf000) >> 0xc),
        @intCast((instruction & 0x0f00) >> 0x8),
        @intCast((instruction & 0x00f0) >> 0x4),
        @intCast((instruction & 0x000f) >> 0x0),
    };
}

test "splitInstruction splits instruction into nybbles" {
    const got = splitInstruction(0xabcd);
    try std.testing.expect(got[0] == 0xa);
    try std.testing.expect(got[1] == 0xb);
    try std.testing.expect(got[2] == 0xc);
    try std.testing.expect(got[3] == 0xd);
}

test "evaluate 6XNN instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6123);
    try std.testing.expect(computer.cpu.registers[1] == 0x23);
}
