const std = @import("std");
const instructions = @import("instructions.zig");
const decode = instructions.decode;
const Instruction = instructions.Instruction;
const Screen = @import("screen.zig").Screen;

const program_start = 0x200;
const font_bytes = 0x50;
const font = [font_bytes]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};
const font_start = program_start - font_bytes;

pub const CPUError = error{
    InvalidInstruction,
    StackOverflow,
    StackUnderflow,
};

pub const CPU = struct {
    registers: [0x10]u8,
    stack: [0x10]u12,
    stack_index: u8,
    address_register: u12,
    program_counter: u12,
    memory: []u8,
    screen: *Screen,
    random: std.Random,

    pub fn init(memory: []u8, screen: *Screen) CPU {
        var prng = std.Random.DefaultPrng.init(0);
        for (font, 0..) |value, index| {
            memory[font_start + index] = value;
        }
        return CPU{
            .registers = [_]u8{undefined} ** 0x10,
            .stack = [_]u12{undefined} ** 0x10,
            .stack_index = 0,
            .address_register = 0,
            .program_counter = program_start,
            .memory = memory,
            .screen = screen,
            .random = prng.random(),
        };
    }

    fn evaluate(self: *CPU, instruction: u16) !void {
        switch (decode(instruction)) {
            Instruction.clear_screen => {
                self.screen.clear();
            },
            Instruction.return_from_subroutine => {
                if (self.stack_index < 0x1)
                    return CPUError.StackUnderflow;
                self.stack_index -= 1;
                self.program_counter = self.stack[self.stack_index];
                return;
            },
            Instruction.jump => |i| {
                self.program_counter = i.address;
                return;
            },
            Instruction.call_subroutine => |i| {
                if (self.stack_index > 0xf)
                    return CPUError.StackOverflow;
                self.stack[self.stack_index] = self.program_counter + 1;
                self.stack_index += 1;
                self.program_counter = i.address;
                return;
            },
            Instruction.skip_if_equal_immediate => |i| {
                if (self.registers[i.register] == i.value) {
                    self.program_counter += 2;
                    return;
                }
            },
            Instruction.skip_if_not_equal_immediate => |i| {
                if (self.registers[i.register] != i.value) {
                    self.program_counter += 2;
                    return;
                }
            },
            Instruction.skip_if_equal => |i| {
                if (self.registers[i.register[0]] == self.registers[i.register[1]]) {
                    self.program_counter += 2;
                    return;
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
                    self.program_counter += 2;
                    return;
                }
            },
            Instruction.load_address_immediate => |i| {
                self.address_register = i.address;
            },
            Instruction.computed_jump => |i| {
                self.address_register = i.address +% self.registers[0];
            },
            Instruction.rand => |i| {
                self.registers[i.register] = self.random.int(u8) & i.bitmask;
            },
            Instruction.sprite => |i| {
                const x = self.registers[i.register_x];
                const y = self.registers[i.register_y];
                const from = self.address_register;
                const to = from + i.size;
                const flipped = self.screen.draw(@intCast(x), @intCast(y), self.memory[from..to]);
                if (flipped) {
                    self.registers[0xf] = 0x01;
                } else {
                    self.registers[0xf] = 0x00;
                }
            },
            Instruction.skip_if_key_pressed => {
                unreachable; // TODO implement skip if key pressed
            },
            Instruction.skip_if_key_not_pressed => {
                unreachable; // TODO implement skip if key not pressed
            },
            Instruction.get_delay_timer => {
                unreachable; // TODO implement get delay timer
            },
            Instruction.wait_for_key => {
                unreachable; // TODO implement wait for key
            },
            Instruction.set_delay_timer => {
                unreachable; // TODO implement set delay timer
            },
            Instruction.set_sound_timer => {
                unreachable; // TODO implement set sound timer
            },
            Instruction.add_address => |i| {
                self.address_register +%= self.registers[i.register];
            },
            Instruction.select_sprite => |i| {
                const digit = self.registers[i.register];
                const address = font_start + 5 * @as(u12, digit);
                self.address_register = address;
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
        }
        self.program_counter += 1;
    }
};

test "evaluate 00e0 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);
    screen.rows[0] = 0xffffffffffffffff;
    try cpu.evaluate(0x00e0);
    try std.testing.expect(screen.rows[0] == 0);
    try std.testing.expect(cpu.program_counter == 0x201);
}

test "evaluate 1nnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);
    try cpu.evaluate(0x1abc);
    try std.testing.expect(cpu.program_counter == 0xabc);
}

test "evaluate 2nnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // do 16 subroutine calls
    for (0..16) |_| {
        try cpu.evaluate(0x2abc);
        try std.testing.expect(cpu.program_counter == 0xabc);
    }

    // the next subroutine call should be a stack overflow
    try std.testing.expectError(CPUError.StackOverflow, cpu.evaluate(0x2abc));

    // do 15 subroutine returns
    for (0..15) |_| {
        try cpu.evaluate(0x00ee);
        try std.testing.expect(cpu.program_counter == 0xabd);
    }

    // one final subroutine return
    try cpu.evaluate(0x00ee);
    try std.testing.expect(cpu.program_counter == 0x201);

    // the next subroutine return should be a stack underflow
    try std.testing.expectError(CPUError.StackUnderflow, cpu.evaluate(0x00ee));
}

test "evaluate 3nnn instruction, no skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x3112);
    try std.testing.expect(cpu.program_counter == 0x202);
}

test "evaluate 3nnn instruction, skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x3111);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 4nnn instruction, skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x4112);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 4nnn instruction, no skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x4111);
    try std.testing.expect(cpu.program_counter == 0x202);
}

test "evaluate 5nnn instruction, no skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6212);
    try cpu.evaluate(0x5120);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 5nnn instruction, skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6211);
    try cpu.evaluate(0x5120);
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 6xnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6123);
    try std.testing.expect(cpu.registers[0x1] == 0x23);
    try std.testing.expect(cpu.program_counter == 0x201);
}

test "evaluate 7xnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6f00); // clear register F
    try cpu.evaluate(0x6123);
    try std.testing.expect(cpu.registers[0x1] == 0x23);
    try cpu.evaluate(0x7145);
    try std.testing.expect(cpu.registers[0x1] == 0x68);
    try cpu.evaluate(0x71a0);
    try std.testing.expect(cpu.registers[0x1] == 0x08); // overflow
    try std.testing.expect(cpu.registers[0xf] == 0x00); // register F is not affected
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 8xy0 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6123);
    try cpu.evaluate(0x6234);
    try cpu.evaluate(0x8120);
    try std.testing.expect(cpu.registers[0x1] == 0x34);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 8xy1 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8121);
    try std.testing.expect(cpu.registers[0x1] == 0x77);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 8xy2 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8122);
    try std.testing.expect(cpu.registers[0x1] == 0x11);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 8xy3 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6133);
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8123);
    try std.testing.expect(cpu.registers[0x1] == 0x66);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate 8xy4 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // add
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6242);
    try cpu.evaluate(0x8124);
    try std.testing.expect(cpu.registers[0x1] == 0xe3);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
    try std.testing.expect(cpu.program_counter == 0x203);

    // add with overflow
    try cpu.evaluate(0x8124);
    try std.testing.expect(cpu.registers[0x1] == 0x25);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 8xy5 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // subtraction: 0xa1 - 0x43
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6243);
    try cpu.evaluate(0x8125);
    try std.testing.expect(cpu.registers[0x1] == 0x5e);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
    try std.testing.expect(cpu.program_counter == 0x203);

    // subtraction with underflow: 0x43 - 0xa1
    try cpu.evaluate(0x6143);
    try cpu.evaluate(0x62a1);
    try cpu.evaluate(0x8125);
    try std.testing.expect(cpu.registers[0x1] == 0xa2);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
    try std.testing.expect(cpu.program_counter == 0x206);
}

test "evaluate 8xy6 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // right shift with lsb 0
    try cpu.evaluate(0x62aa);
    try cpu.evaluate(0x8126);
    try std.testing.expect(cpu.registers[0x1] == 0x55);
    try std.testing.expect(cpu.registers[0x2] == 0xaa);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
    try std.testing.expect(cpu.program_counter == 0x202);

    // right shift with lsb 1
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x8126);
    try std.testing.expect(cpu.registers[0x1] == 0x2a);
    try std.testing.expect(cpu.registers[0x2] == 0x55);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 8xy7 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // subtraction: 0xa1 - 0x42
    try cpu.evaluate(0x6143);
    try cpu.evaluate(0x62a1);
    try cpu.evaluate(0x8127);
    try std.testing.expect(cpu.registers[0x1] == 0x5e);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
    try std.testing.expect(cpu.program_counter == 0x203);

    // subtraction with underflow: 0x43 - 0xa1
    try cpu.evaluate(0x61a1);
    try cpu.evaluate(0x6243);
    try cpu.evaluate(0x8127);
    try std.testing.expect(cpu.registers[0x1] == 0xa2);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
    try std.testing.expect(cpu.program_counter == 0x206);
}

test "evaluate 8xye instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // left shift with msb 0
    try cpu.evaluate(0x6255);
    try cpu.evaluate(0x812e);
    try std.testing.expect(cpu.registers[0x1] == 0xaa);
    try std.testing.expect(cpu.registers[0x2] == 0x55);
    try std.testing.expect(cpu.registers[0xf] == 0x00);
    try std.testing.expect(cpu.program_counter == 0x202);

    // left shift with msb 1
    try cpu.evaluate(0x62aa);
    try cpu.evaluate(0x812e);
    try std.testing.expect(cpu.registers[0x1] == 0x54);
    try std.testing.expect(cpu.registers[0x2] == 0xaa);
    try std.testing.expect(cpu.registers[0xf] == 0x01);
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 9nnn instruction, skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6212);
    try cpu.evaluate(0x9120);
    try std.testing.expect(cpu.program_counter == 0x204);
}

test "evaluate 9nnn instruction, no skip" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6111);
    try cpu.evaluate(0x6211);
    try cpu.evaluate(0x9120);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate annn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0xa123);
    try std.testing.expect(cpu.address_register == 0x123);
    try std.testing.expect(cpu.program_counter == 0x201);
}

test "evaluate bnnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6023);
    try cpu.evaluate(0xb234);
    try std.testing.expect(cpu.address_register == 0x257);
    try std.testing.expect(cpu.program_counter == 0x202);
}

test "evaluate cxnn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // this only tests that the bitmask works
    cpu.registers[0xa] = 0x00;
    try cpu.evaluate(0xca0f);
    try std.testing.expect(cpu.registers[0xa] & 0xf0 == 0x00);
    try std.testing.expect(cpu.program_counter == 0x201);
}

test "evaluate dxyn instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // define a 1-byte sprite
    memory[0x800] = 0x5a;
    cpu.address_register = 0x800;

    // draw the sprite in the bottom-right corner of the screen
    cpu.registers[0xa] = 0x38;
    cpu.registers[0xb] = 0x1f;
    try cpu.evaluate(0xdab1);

    try std.testing.expect(screen.rows[0x1f] == 0x000000000000005a);
}

test "evaluate fx1e instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0xa123);
    try cpu.evaluate(0x6abc);
    try cpu.evaluate(0xfa1e);
    try std.testing.expect(cpu.address_register == 0x1df);
    try std.testing.expect(cpu.program_counter == 0x203);
}

test "evaluate fx29 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    try cpu.evaluate(0x6a04);
    try cpu.evaluate(0xfa29);
    try std.testing.expect(cpu.address_register == 0x1c4);
    try std.testing.expect(cpu.program_counter == 0x202);
}

test "evaluate fx33 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    memory[0xa00] = 0x00;
    memory[0xa01] = 0x00;
    memory[0xa02] = 0x00;
    cpu.address_register = 0xa00;
    cpu.registers[1] = 234;
    try cpu.evaluate(0xf133);

    try std.testing.expectEqual(0x2, memory[0xa00]);
    try std.testing.expectEqual(0x3, memory[0xa01]);
    try std.testing.expectEqual(0x4, memory[0xa02]);
    try std.testing.expect(cpu.program_counter == 0x201);
}

test "evaluate fx55 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // store 16 zeros
    cpu.address_register = 0xa00;
    cpu.registers = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    try cpu.evaluate(0xff55);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, memory[0xa00..0xa10]);
    try std.testing.expectEqual(0xa10, cpu.address_register);
    try std.testing.expect(cpu.program_counter == 0x201);

    // store registers 0 to 5
    cpu.address_register = 0xa00;
    cpu.registers = .{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff };
    try cpu.evaluate(0xf555);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, memory[0xa00..0xa10]);
    try std.testing.expectEqual(0xa06, cpu.address_register);
    try std.testing.expect(cpu.program_counter == 0x202);
}

test "evaluate fx65 instruction" {
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, 0x1000);
    defer allocator.free(memory);
    var screen = Screen.init();
    var cpu = CPU.init(memory, &screen);

    // load 16 zeros
    for (0xa00..0xa10) |i|
        memory[i] = 0x00;
    cpu.address_register = 0xa00;
    try cpu.evaluate(0xff65);
    try std.testing.expectEqual([16]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, cpu.registers);
    try std.testing.expectEqual(0xa10, cpu.address_register);
    try std.testing.expect(cpu.program_counter == 0x201);

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
    try std.testing.expect(cpu.program_counter == 0x202);
}
