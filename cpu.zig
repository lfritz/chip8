const std = @import("std");
const instructions = @import("instructions.zig");
const decode = instructions.decode;
const Instruction = instructions.Instruction;

pub const CPUError = error{
    InvalidInstruction,
};

pub const CPU = struct {
    registers: [16]u8,
    address_register: u12,
    program_counter: u12,
    memory: []u8,

    pub fn init(memory: []u8) CPU {
        return CPU{
            .registers = [_]u8{undefined} ** 16,
            .address_register = 0,
            .program_counter = 0x200,
            .memory = memory,
        };
    }

    fn evaluate(self: *CPU, instruction: u16) !void {
        switch (decode(instruction)) {
            Instruction.jump => |i| {
                self.program_counter = i.address;
            },
            Instruction.skip_if_equal_immediate => |i| {
                if (self.registers[i.register] == i.value) {
                    self.program_counter += 1;
                }
            },
            Instruction.skip_if_not_equal_immediate => |i| {
                if (self.registers[i.register] != i.value) {
                    self.program_counter += 1;
                }
            },
            Instruction.skip_if_equal => |i| {
                if (self.registers[i.register[0]] == self.registers[i.register[1]]) {
                    self.program_counter += 1;
                }
            },
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
                self.registers[i.target] |= self.registers[i.source];
            },
            Instruction.register_and => |i| {
                self.registers[i.target] &= self.registers[i.source];
            },
            Instruction.register_xor => |i| {
                self.registers[i.target] ^= self.registers[i.source];
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
            Instruction.skip_if_not_equal => |i| {
                if (self.registers[i.register[0]] != self.registers[i.register[1]]) {
                    self.program_counter += 1;
                }
            },
            Instruction.load_address_immediate => |i| {
                self.address_register = i.address;
            },
            Instruction.add_address => |i| {
                self.address_register +%= self.registers[i.register];
            },
            Instruction.bcd => |i| {
                const value = self.registers[i.register];
                self.memory[self.address_register + 0] = value / 100;
                self.memory[self.address_register + 1] = (value % 100) / 10;
                self.memory[self.address_register + 2] = value % 10;
            },
            Instruction.store => |i| {
                for (self.registers, 0..) |value, index| {
                    if (index > i.up_to_register)
                        break;
                    self.memory[self.address_register] = value;
                    self.address_register += 1;
                }
            },
            Instruction.load => |i| {
                for (&self.registers, 0..) |*register, index| {
                    if (index > i.up_to_register)
                        break;
                    register.* = self.memory[self.address_register];
                    self.address_register += 1;
                }
            },
            Instruction.invalid => return CPUError.InvalidInstruction,
            else => unreachable,
        }
    }
};

test "evaluate 1nnn instruction" {
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x1abc);
    try std.testing.expect(cpu.program_counter == 0xabc);
}

test "evaluate 3nnn instruction" {
    var cpu = CPU.init(&.{});

    // no skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x3112);
    try std.testing.expect(cpu.program_counter == 0xabc);

    // skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x3111);
    try std.testing.expect(cpu.program_counter == 0xabd);
}

test "evaluate 4nnn instruction" {
    var cpu = CPU.init(&.{});

    // skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x4112);
    try std.testing.expect(cpu.program_counter == 0xabd);

    // no skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x4111);
    try std.testing.expect(cpu.program_counter == 0xabc);
}

test "evaluate 5nnn instruction" {
    var cpu = CPU.init(&.{});

    // no skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6212);
    try cpu.evaluate(0x5120);
    try std.testing.expect(cpu.program_counter == 0xabc);

    // skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6211);
    try cpu.evaluate(0x5120);
    try std.testing.expect(cpu.program_counter == 0xabd);
}

test "evaluate 6xnn instruction" {
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x6123);
    try std.testing.expect(cpu.registers[0x1] == 0x23);
}

test "evaluate 7xnn instruction" {
    var cpu = CPU.init(&.{});
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
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x6123);
    try cpu.evaluate(0x6234);
    try cpu.evaluate(0x8120);
    try std.testing.expect(cpu.registers[0x1] == 0x34);
}

test "evaluate 8xy1 instruction" {
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8121);
    try std.testing.expect(cpu.registers[0x1] == 0x77);
}

test "evaluate 8xy2 instruction" {
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8122);
    try std.testing.expect(cpu.registers[0x1] == 0x11);
}

test "evaluate 8xy3 instruction" {
    var cpu = CPU.init(&.{});
    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8123);
    try std.testing.expect(cpu.registers[0x1] == 0x66);
}

test "evaluate 8xy4 instruction" {
    var cpu = CPU.init(&.{});

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
    var cpu = CPU.init(&.{});

    // subtraction: 0xa1 - 0x43
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
    var cpu = CPU.init(&.{});

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
    var cpu = CPU.init(&.{});

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
    var cpu = CPU.init(&.{});

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

test "evaluate 9nnn instruction" {
    var cpu = CPU.init(&.{});

    // skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6212);
    try cpu.evaluate(0x9120);
    try std.testing.expect(cpu.program_counter == 0xabd);

    // no skip
    try cpu.evaluate(0x1abc);
    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6211);
    try cpu.evaluate(0x9120);
    try std.testing.expect(cpu.program_counter == 0xabc);
}

test "evaluate annn instruction" {
    var cpu = CPU.init(&.{});

    try cpu.evaluate(0xa123);
    try std.testing.expect(cpu.address_register == 0x123);
}

test "evaluate fx1e instruction" {
    var cpu = CPU.init(&.{});

    try cpu.evaluate(0xa123);
    try cpu.evaluate(0x6abc);
    try cpu.evaluate(0xfa1e);
    try std.testing.expect(cpu.address_register == 0x1df);
}

test "evaluate fx33 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var cpu = CPU.init(memory);

    memory[0xa00] = 0x00;
    memory[0xa01] = 0x00;
    memory[0xa02] = 0x00;
    cpu.address_register = 0xa00;
    cpu.registers[1] = 234;
    try cpu.evaluate(0xf133);

    try std.testing.expectEqual(0x2, memory[0xa00]);
    try std.testing.expectEqual(0x3, memory[0xa01]);
    try std.testing.expectEqual(0x4, memory[0xa02]);
}

test "evaluate fx55 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var cpu = CPU.init(memory);

    // store 16 zeros
    cpu.address_register = 0xa00;
    cpu.registers = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    try cpu.evaluate(0xff55);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, memory[0xa00..0xa10]);
    try std.testing.expectEqual(0xa10, cpu.address_register);

    // store registers 0 to 5
    cpu.address_register = 0xa00;
    cpu.registers = .{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff };
    try cpu.evaluate(0xf555);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, memory[0xa00..0xa10]);
    try std.testing.expectEqual(0xa06, cpu.address_register);
}

test "evaluate fx65 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var cpu = CPU.init(memory);

    // load 16 zeros
    for (0xa00..0xa10) |i|
        memory[i] = 0x00;
    cpu.address_register = 0xa00;
    try cpu.evaluate(0xff65);
    try std.testing.expectEqual([16]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, cpu.registers);
    try std.testing.expectEqual(0xa10, cpu.address_register);

    // load registers 0 to 5
    memory[0xa00] = 0x00;
    memory[0xa01] = 0x11;
    memory[0xa02] = 0x22;
    memory[0xa03] = 0x33;
    memory[0xa04] = 0x44;
    memory[0xa05] = 0x55;
    memory[0xa06] = 0x66;
    memory[0xa07] = 0x77;
    memory[0xa08] = 0x88;
    memory[0xa09] = 0x99;
    memory[0xa0a] = 0xaa;
    memory[0xa0b] = 0xbb;
    memory[0xa0c] = 0xcc;
    memory[0xa0d] = 0xdd;
    memory[0xa0e] = 0xee;
    memory[0xa0f] = 0xff;
    cpu.address_register = 0xa00;
    try cpu.evaluate(0xf565);
    try std.testing.expectEqual([16]u8{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, cpu.registers);
    try std.testing.expectEqual(0xa06, cpu.address_register);
}
