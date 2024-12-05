const std = @import("std");

pub const Instruction = union(enum) {
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
    register_set: struct {
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
    register_shift_right: struct {
        target: u4,
        by: u4,
    },
    register_sub_target: struct {
        target: u4,
        source: u4,
    },
    register_shift_left: struct {
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
    wait_for_key: struct {
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

pub fn decode(instruction: u16) Instruction {
    const n0: u4 = @intCast(instruction >> 12);
    const n1: u4 = @intCast((instruction >> 8) & 0x000f);
    const n2: u4 = @intCast((instruction >> 4) & 0x000f);
    const n3: u4 = @intCast(instruction & 0x000f);
    const b1: u8 = @intCast(instruction & 0x00ff);
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
        0x5 => switch (n3) {
            0x0 => Instruction{ .skip_if_equal = .{
                .register = [_]u4{ n1, n2 },
            } },
            else => Instruction.invalid,
        },
        0x6 => Instruction{ .load_immediate = .{
            .register = n1,
            .value = b1,
        } },
        0x7 => Instruction{ .add_immediate = .{
            .register = n1,
            .value = b1,
        } },
        0x8 => switch (n3) {
            0x0 => Instruction{ .register_set = .{
                .target = n1,
                .source = n2,
            } },
            0x1 => Instruction{ .register_or = .{
                .target = n1,
                .source = n2,
            } },
            0x2 => Instruction{ .register_and = .{
                .target = n1,
                .source = n2,
            } },
            0x3 => Instruction{ .register_xor = .{
                .target = n1,
                .source = n2,
            } },
            0x4 => Instruction{ .register_add = .{
                .target = n1,
                .source = n2,
            } },
            0x5 => Instruction{ .register_sub = .{
                .target = n1,
                .source = n2,
            } },
            0x6 => Instruction{ .register_shift_right = .{
                .target = n1,
                .by = n2,
            } },
            0x7 => Instruction{ .register_sub_target = .{
                .target = n1,
                .source = n2,
            } },
            0xe => Instruction{ .register_shift_left = .{
                .target = n1,
                .by = n2,
            } },
            else => Instruction.invalid,
        },
        0x9 => switch (n3) {
            0x0 => Instruction{ .skip_if_not_equal = .{
                .register = [_]u4{ n1, n2 },
            } },
            else => Instruction.invalid,
        },
        0xa => Instruction{ .load_address_immediate = .{
            .address = address,
        } },
        0xb => Instruction{ .computed_jump = .{
            .address = address,
        } },
        0xc => Instruction{ .rand = .{
            .register = n1,
            .bitmask = b1,
        } },
        0xd => Instruction{ .sprite = .{
            .register_x = n1,
            .register_y = n2,
            .size = n3,
        } },
        0xe => switch (b1) {
            0x9e => Instruction{ .skip_if_key_pressed = .{
                .register = n1,
            } },
            0xa1 => Instruction{ .skip_if_key_not_pressed = .{
                .register = n1,
            } },
            else => Instruction.invalid,
        },
        0xf => switch (b1) {
            0x07 => Instruction{ .get_delay_timer = .{
                .register = n1,
            } },
            0x0a => Instruction{ .wait_for_key = .{
                .register = n1,
            } },
            0x15 => Instruction{ .set_delay_timer = .{
                .register = n1,
            } },
            0x18 => Instruction{ .set_sound_timer = .{
                .register = n1,
            } },
            0x1e => Instruction{ .add_address = .{
                .register = n1,
            } },
            0x29 => Instruction{ .select_sprite = .{
                .register = n1,
            } },
            0x33 => Instruction{ .bcd = .{
                .register = n1,
            } },
            0x55 => Instruction{ .store = .{
                .up_to_register = n1,
            } },
            0x65 => Instruction{ .load = .{
                .up_to_register = n1,
            } },
            else => Instruction.invalid,
        },
    };
}

test "decode recognizes invalid instructions" {
    const invalid = [_]u16{
        0x0000,
        0x0100,
        0x00ef,
        0x5ab1,
        0xe000,
        0x8008,
        0x9001,
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

    got = decode(0x5ab0);
    want = Instruction{ .skip_if_equal = .{
        .register = [_]u4{ 0xa, 0xb },
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x6abc);
    want = Instruction{ .load_immediate = .{
        .register = 0xa,
        .value = 0xbc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x7abc);
    want = Instruction{ .add_immediate = .{
        .register = 0xa,
        .value = 0xbc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab0);
    want = Instruction{ .register_set = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab1);
    want = Instruction{ .register_or = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab2);
    want = Instruction{ .register_and = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab3);
    want = Instruction{ .register_xor = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab4);
    want = Instruction{ .register_add = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab5);
    want = Instruction{ .register_sub = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab6);
    want = Instruction{ .register_shift_right = .{
        .target = 0xa,
        .by = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8ab7);
    want = Instruction{ .register_sub_target = .{
        .target = 0xa,
        .source = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x8abe);
    want = Instruction{ .register_shift_left = .{
        .target = 0xa,
        .by = 0xb,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0x9ab0);
    want = Instruction{ .skip_if_not_equal = .{
        .register = [_]u4{ 0xa, 0xb },
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xaabc);
    want = Instruction{ .load_address_immediate = .{
        .address = 0xabc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xbabc);
    want = Instruction{ .computed_jump = .{
        .address = 0xabc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xca1f);
    want = Instruction{ .rand = .{
        .register = 0xa,
        .bitmask = 0x1f,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xdabc);
    want = Instruction{ .sprite = .{
        .register_x = 0xa,
        .register_y = 0xb,
        .size = 0xc,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xea9e);
    want = Instruction{ .skip_if_key_pressed = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xeaa1);
    want = Instruction{ .skip_if_key_not_pressed = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa07);
    want = Instruction{ .get_delay_timer = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa0a);
    want = Instruction{ .wait_for_key = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa15);
    want = Instruction{ .set_delay_timer = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa18);
    want = Instruction{ .set_sound_timer = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa1e);
    want = Instruction{ .add_address = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa29);
    want = Instruction{ .select_sprite = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa33);
    want = Instruction{ .bcd = .{
        .register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa55);
    want = Instruction{ .store = .{
        .up_to_register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);

    got = decode(0xfa65);
    want = Instruction{ .load = .{
        .up_to_register = 0xa,
    } };
    try std.testing.expectEqualDeep(want, got);
}
