const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .wasm32,
            // .os_tag = .wasi,
            .os_tag = .freestanding,
        }
    });

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("vendor/qrcodegen.h"),
        .target = target,
        .optimize = optimize,
    });
    const qrcodegen_mod = translate_c.createModule();
    // qrcodegen_mod.link_libc = true; // FIXME Remove because not needed

    const mod = b.addModule("core", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "qrcodegen",
                .module = qrcodegen_mod,
            },
        },
    });

    const wasm_exe = b.addExecutable(.{
        .name = "core",
        .root_module = mod,
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;

    b.installArtifact(wasm_exe);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = wasm_exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
