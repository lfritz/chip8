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

    fn evaluate(self: *CPU, instruction: u16) !void {
        switch (decode(instruction)) {
            Instruction.load_immediate => |i| {
                self.registers[i.register] = i.value;
            },
            Instruction.add_immediate => |i| {
                self.registers[i.register] +%= i.value;
            },
            Instruction.register_set => |i| {
                self.registers[i.target] = self.registers[i.source];
            },
            Instruction.register_or => |i| {
                self.registers[i.target] = self.registers[i.target] | self.registers[i.source];
            },
            Instruction.register_and => |i| {
                self.registers[i.target] = self.registers[i.target] & self.registers[i.source];
            },
            Instruction.register_xor => |i| {
                self.registers[i.target] = self.registers[i.target] ^ self.registers[i.source];
            },
            Instruction.register_add => |i| {
                self.registers[i.target], const overflow = @addWithOverflow(
                    self.registers[i.target],
                    self.registers[i.source],
                );
                self.registers[0xf] = overflow;
            },
            Instruction.register_sub => |i| {
                self.registers[i.target], const overflow = @subWithOverflow(
                    self.registers[i.target],
                    self.registers[i.source],
                );
                self.registers[0xf] = ~overflow;
            },
            Instruction.register_shift_right => |i| {
                const source = self.registers[i.source];
                const lsb = source & 0x01;
                self.registers[i.target] = source >> 1;
                self.registers[0xf] = lsb;
            },
            Instruction.register_sub_target => |i| {
                self.registers[i.target], const overflow = @subWithOverflow(
                    self.registers[i.source],
                    self.registers[i.target],
                );
                self.registers[0xf] = ~overflow;
            },
            Instruction.register_shift_left => |i| {
                const source = self.registers[i.source];
                const msb = (source & 0x80) >> 7;
                self.registers[i.target] = source << 1;
                self.registers[0xf] = msb;
            },
            Instruction.load_address_immediate => |i| {
                self.address_register = i.address;
            },
            Instruction.add_address => |i| {
                self.address_register +%= self.registers[i.register];
            },
            Instruction.invalid => return CPUError.InvalidInstruction,
            else => unreachable,
        }
    }
};

const Computer = struct {
    cpu: CPU,

    fn init() Computer {
        return Computer{
            .cpu = CPU.init(),
        };
    }
};

test "evaluate 6xnn instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6123);
    try std.testing.expect(cpu.registers[0x1] == 0x23);
}

test "evaluate 7xnn instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6f00); // clear register F
    try cpu.evaluate(0x6123);
    try std.testing.expect(cpu.registers[0x1] == 0x23);
    try cpu.evaluate(0x7145);
    try std.testing.expect(cpu.registers[0x1] == 0x68);
    try cpu.evaluate(0x71a0);
    try std.testing.expect(cpu.registers[0x1] == 0x08); // overflow
    try std.testing.expect(cpu.registers[0xf] == 0x00); // register F is not affected
}

test "evaluate 8xy0 instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6123);
    try cpu.evaluate(0x6234);
    try cpu.evaluate(0x8120);
    try std.testing.expect(cpu.registers[0x1] == 0x34);
}

test "evaluate 8xy1 instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8121);
    try std.testing.expect(cpu.registers[0x1] == 0x77);
}

test "evaluate 8xy2 instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8122);
    try std.testing.expect(cpu.registers[0x1] == 0x11);
}

test "evaluate 8xy3 instruction" {
    var cpu = CPU.init();
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8123);
    try std.testing.expect(cpu.registers[0x1] == 0x66);
}

test "evaluate 8xy4 instruction" {
    var cpu = CPU.init();

    // add
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6242);
    try cpu.evaluate(0x8124);
    try std.testing.expect(cpu.registers[0x1] == 0xe3);
    try std.testing.expect(cpu.registers[0xf] == 0x00);

    // add with overflow
    try cpu.evaluate(0x8124);
    try std.testing.expect(cpu.registers[0x1] == 0x25);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
}

test "evaluate 8xy5 instruction" {
    var cpu = CPU.init();

    // subtraction: 0xa1 - 0x42
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6243);
    try cpu.evaluate(0x8125);
    try std.testing.expect(cpu.registers[0x1] == 0x5e);
    try std.testing.expect(cpu.registers[0xf] == 0x01);

    // subtraction with underflow: 0x43 - 0xa1
    try cpu.evaluate(0x6143);
    try cpu.evaluate(0x62a1);
    try cpu.evaluate(0x8125);
    try std.testing.expect(cpu.registers[0x1] == 0xa2);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
}

test "evaluate 8xy6 instruction" {
    var cpu = CPU.init();

    // right shift with lsb 0
    try cpu.evaluate(0x62aa);
    try cpu.evaluate(0x8126);
    try std.testing.expect(cpu.registers[0x1] == 0x55);
    try std.testing.expect(cpu.registers[0x2] == 0xaa);
    try std.testing.expect(cpu.registers[0xf] == 0x00);

    // right shift with lsb 1
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8126);
    try std.testing.expect(cpu.registers[0x1] == 0x2a);
    try std.testing.expect(cpu.registers[0x2] == 0x55);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
}

test "evaluate 8xy7 instruction" {
    var cpu = CPU.init();

    // subtraction: 0xa1 - 0x42
    try cpu.evaluate(0x6143);
    try cpu.evaluate(0x62a1);
    try cpu.evaluate(0x8127);
    try std.testing.expect(cpu.registers[0x1] == 0x5e);
    try std.testing.expect(cpu.registers[0xf] == 0x01);

    // subtraction with underflow: 0x43 - 0xa1
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6243);
    try cpu.evaluate(0x8127);
    try std.testing.expect(cpu.registers[0x1] == 0xa2);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
}

test "evaluate 8xye instruction" {
    var cpu = CPU.init();

    // left shift with msb 0
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x812e);
    try std.testing.expect(cpu.registers[0x1] == 0xaa);
    try std.testing.expect(cpu.registers[0x2] == 0x55);
    try std.testing.expect(cpu.registers[0xf] == 0x00);

    // left shift with msb 1
    try cpu.evaluate(0x62aa);
    try cpu.evaluate(0x812e);
    try std.testing.expect(cpu.registers[0x1] == 0x54);
    try std.testing.expect(cpu.registers[0x2] == 0xaa);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
}

test "evaluate annn instruction" {
    var cpu = CPU.init();

    try cpu.evaluate(0xa123);
    try std.testing.expect(cpu.address_register == 0x123);
}

test "evaluate fx1e instruction" {
    var cpu = CPU.init();

    try cpu.evaluate(0xa123);
    try cpu.evaluate(0x6abc);
    try cpu.evaluate(0xfa1e);
    try std.testing.expect(cpu.address_register == 0x1df);
}
