const std = @import("std");

const Instruction = union(enum) {
    clear_screen,
    return_from_subroutine,
    jump: struct {
        address: u12,
    },
    call_subroutine: struct {
        address: u12,
    },
    skip_if_equal_immediate: struct {
        register: u4,
        value: u8,
    },
    skip_if_not_equal_immediate: struct {
        register: u4,
        value: u8,
    },
    skip_if_equal: struct {
        register: [2]u4,
    },
    load_immediate: struct {
        register: u4,
        value: u8,
    },
    add_immediate: struct {
        register: u4,
        value: u8,
    },
    register_is: struct {
        target: u4,
        source: u4,
    },
    register_or: struct {
        target: u4,
        source: u4,
    },
    register_and: struct {
        target: u4,
        source: u4,
    },
    register_xor: struct {
        target: u4,
        source: u4,
    },
    register_add: struct {
        target: u4,
        source: u4,
    },
    register_sub: struct {
        target: u4,
        source: u4,
    },
    register_right_shift: struct {
        target: u4,
        by: u4,
    },
    register_is_negative: struct {
        target: u4,
        source: u4,
    },
    register_left_shift: struct {
        target: u4,
        by: u4,
    },
    skip_if_not_equal: struct {
        register: [2]u4,
    },
    load_address_immediate: struct {
        address: u12,
    },
    computed_jump: struct {
        address: u12,
    },
    rand: struct {
        register: u4,
        bitmask: u8,
    },
    sprite: struct {
        register_x: u4,
        register_y: u4,
        size: u4,
    },
    skip_if_key_pressed: struct {
        register: u4,
    },
    skip_if_key_not_pressed: struct {
        register: u4,
    },
    get_delay_timer: struct {
        register: u4,
    },
    set_delay_timer: struct {
        register: u4,
    },
    set_sound_timer: struct {
        register: u4,
    },
    add_address: struct {
        register: u4,
    },
    select_sprite: struct {
        register: u4,
    },
    bcd: struct {
        register: u4,
    },
    store: struct {
        up_to_register: u4,
    },
    load: struct {
        up_to_register: u4,
    },
    invalid,
};

fn decode(instruction: u16) Instruction {
    const b1: u8 = @intCast(instruction & 0x00ff);
    const n0: u4 = @intCast(instruction >> 12);
    const n1: u4 = @intCast((instruction >> 8) & 0x000f);
    const address: u12 = @intCast(instruction & 0x0fff);
    return switch (n0) {
        0x0 => switch (instruction) {
            0x00e0 => Instruction.clear_screen,
            0x00ee => Instruction.return_from_subroutine,
            else => Instruction.invalid,
        },
        0x1 => Instruction{ .jump = .{ .address = address } },
        0x2 => Instruction{ .call_subroutine = .{ .address = address } },
        0x3 => Instruction{ .skip_if_equal_immediate = .{
            .register = n1,
            .value = b1,
        } },
        0x4 => Instruction{ .skip_if_not_equal_immediate = .{
            .register = n1,
            .value = b1,
        } },
        // TODO
        else => Instruction.invalid,
    };
}

test "decode recognizes invalid instructions" {
    const invalid = [_]u16{
        0x0000,
        0x0100,
        0x00ef,
        0xe000,
        0xe09f,
        0xe0a0,
        0xf000,
        0xf016,
        0xffff,
    };
    for (invalid) |instruction| {
        const got = decode(instruction);
        try std.testing.expectEqual(Instruction.invalid, got);
    }
}

test "decode decodes valid instructions" {
    var got: Instruction = decode(0x00e0);
    var want: Instruction = Instruction.clear_screen;
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x00ee);
    want = Instruction.return_from_subroutine;
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x1abc);
    want = Instruction{ .jump = .{ .address = 0xabc } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x2abc);
    want = Instruction{ .call_subroutine = .{ .address = 0xabc } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x3abc);
    want = Instruction{ .skip_if_equal_immediate = .{
        .register = 0xa,
        .value = 0xbc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x4abc);
    want = Instruction{ .skip_if_not_equal_immediate = .{
        .register = 0xa,
        .value = 0xbc,
    } };
    try std.testing.expectEqualDeep(want, got);

    // TODO
}
