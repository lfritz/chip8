const std = @import("std");
const instructions = @import("instructions.zig");
const decode = instructions.decode;
const Instruction = instructions.Instruction;

const CPUError = error{
    InvalidInstruction,
};

const CPU = struct {
    registers: [16]u8,
    address_register: u12,

    fn init() CPU {
        return CPU{
            .registers = [_]u8{undefined} ** 16,
            .address_register = 0,
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
            Instruction.register_add => |i| {
                self.cpu.registers[i.target], const overflow = @addWithOverflow(
                    self.cpu.registers[i.target],
                    self.cpu.registers[i.source],
                );
                self.cpu.registers[0xf] = overflow;
            },
            Instruction.register_sub => |i| {
                self.cpu.registers[i.target], const overflow = @subWithOverflow(
                    self.cpu.registers[i.target],
                    self.cpu.registers[i.source],
                );
                self.cpu.registers[0xf] = ~overflow;
            },
            Instruction.register_shift_right => |i| {
                const source = self.cpu.registers[i.source];
                const lsb = source & 0x01;
                self.cpu.registers[i.target] = source >> 1;
                self.cpu.registers[0xf] = lsb;
            },
            Instruction.register_sub_target => |i| {
                self.cpu.registers[i.target], const overflow = @subWithOverflow(
                    self.cpu.registers[i.source],
                    self.cpu.registers[i.target],
                );
                self.cpu.registers[0xf] = ~overflow;
            },
            Instruction.register_shift_left => |i| {
                const source = self.cpu.registers[i.source];
                const msb = (source & 0x80) >> 7;
                self.cpu.registers[i.target] = source << 1;
                self.cpu.registers[0xf] = msb;
            },
            Instruction.load_address_immediate => |i| {
                self.cpu.address_register = i.address;
            },
            Instruction.add_address => |i| {
                self.cpu.address_register +%= self.cpu.registers[i.register];
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

test "evaluate 8xy4 instruction" {
    var computer = Computer.init();

    // add
    try computer.evaluate(0x61a1);
    try computer.evaluate(0x6242);
    try computer.evaluate(0x8124);
    try std.testing.expect(computer.cpu.registers[0x1] == 0xe3);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00);

    // add with overflow
    try computer.evaluate(0x8124);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x25);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x01);
}

test "evaluate 8xy5 instruction" {
    var computer = Computer.init();

    // subtraction: 0xa1 - 0x42
    try computer.evaluate(0x61a1);
    try computer.evaluate(0x6243);
    try computer.evaluate(0x8125);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x5e);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x01);

    // subtraction with underflow: 0x43 - 0xa1
    try computer.evaluate(0x6143);
    try computer.evaluate(0x62a1);
    try computer.evaluate(0x8125);
    try std.testing.expect(computer.cpu.registers[0x1] == 0xa2);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00);
}

test "evaluate 8xy6 instruction" {
    var computer = Computer.init();

    // right shift with lsb 0
    try computer.evaluate(0x62aa);
    try computer.evaluate(0x8126);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x55);
    try std.testing.expect(computer.cpu.registers[0x2] == 0xaa);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00);

    // right shift with lsb 1
    try computer.evaluate(0x6255);
    try computer.evaluate(0x8126);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x2a);
    try std.testing.expect(computer.cpu.registers[0x2] == 0x55);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x01);
}

test "evaluate 8xy7 instruction" {
    var computer = Computer.init();

    // subtraction: 0xa1 - 0x42
    try computer.evaluate(0x6143);
    try computer.evaluate(0x62a1);
    try computer.evaluate(0x8127);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x5e);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x01);

    // subtraction with underflow: 0x43 - 0xa1
    try computer.evaluate(0x61a1);
    try computer.evaluate(0x6243);
    try computer.evaluate(0x8127);
    try std.testing.expect(computer.cpu.registers[0x1] == 0xa2);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00);
}

test "evaluate 8xye instruction" {
    var computer = Computer.init();

    // left shift with msb 0
    try computer.evaluate(0x6255);
    try computer.evaluate(0x812e);
    try std.testing.expect(computer.cpu.registers[0x1] == 0xaa);
    try std.testing.expect(computer.cpu.registers[0x2] == 0x55);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x00);

    // left shift with msb 1
    try computer.evaluate(0x62aa);
    try computer.evaluate(0x812e);
    try std.testing.expect(computer.cpu.registers[0x1] == 0x54);
    try std.testing.expect(computer.cpu.registers[0x2] == 0xaa);
    try std.testing.expect(computer.cpu.registers[0xf] == 0x01);
}

test "evaluate annn instruction" {
    var computer = Computer.init();

    try computer.evaluate(0xa123);
    try std.testing.expect(computer.cpu.address_register == 0x123);
}

test "evaluate fx1e instruction" {
    var computer = Computer.init();

    try computer.evaluate(0xa123);
    try computer.evaluate(0x6abc);
    try computer.evaluate(0xfa1e);
    try std.testing.expect(computer.cpu.address_register == 0x1df);
}
