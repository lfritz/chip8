const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "chip8",
        .root_source_file = b.path("main.zig"),
        .target = b.host,
    });
    exe.linkSystemLibrary("raylib");
    exe.linkLibC();
    b.installArtifact(exe);
}
