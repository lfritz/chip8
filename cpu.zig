const std = @import("std");
const instructions = @import("instructions.zig");
const decode = instructions.decode;
const Instruction = instructions.Instruction;

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
        switch (decode(instruction)) {
            Instruction.load_immediate => |i| {
                self.cpu.registers[i.register] = i.value;
            },
            Instruction.add_immediate => |i| {
                self.cpu.registers[i.register] +%= i.value;
            },
            Instruction.register_set => |i| {
                self.cpu.registers[i.target] = self.cpu.registers[i.source];
            },
            Instruction.register_or => |i| {
                self.cpu.registers[i.target] = self.cpu.registers[i.target] | self.cpu.registers[i.source];
            },
            Instruction.register_and => |i| {
                self.cpu.registers[i.target] = self.cpu.registers[i.target] & self.cpu.registers[i.source];
            },
            Instruction.register_xor => |i| {
                self.cpu.registers[i.target] = self.cpu.registers[i.target] ^ self.cpu.registers[i.source];
            },
            Instruction.invalid => return CPUError.InvalidInstruction,
            else => unreachable,
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

test "evaluate 6xnn instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6123);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x23);
}

test "evaluate 7xnn instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6f00); // clear register F
    try computer.evaluate(0x6123);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x23);
    try computer.evaluate(0x7145);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x68);
    try computer.evaluate(0x71a0);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x08); // overflow
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00); // register F is not affected
}

test "evaluate 8xy0 instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6123);
    try computer.evaluate(0x6234);
    try computer.evaluate(0x8120);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x34);
}

test "evaluate 8xy1 instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6133);
    try computer.evaluate(0x6255);
    try computer.evaluate(0x8121);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x77);
}

test "evaluate 8xy2 instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6133);
    try computer.evaluate(0x6255);
    try computer.evaluate(0x8122);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x11);
}

test "evaluate 8xy3 instruction" {
    var computer = Computer.init();
    try computer.evaluate(0x6133);
    try computer.evaluate(0x6255);
    try computer.evaluate(0x8123);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x66);
}
