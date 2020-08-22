const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("maru", "src/main.zig");
    lib.setBuildMode(mode);
    lib.addLibPath("/usr/lib");
    lib.addIncludeDir("/usr/include");
    lib.linkSystemLibrary("c");
    lib.linkSystemLibrary("epoxy");
    lib.linkSystemLibrary("glfw");
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.addLibPath("/usr/lib");
    main_tests.addIncludeDir("/usr/include");
    main_tests.linkSystemLibrary("c");
    main_tests.linkSystemLibrary("epoxy");
    main_tests.linkSystemLibrary("glfw");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
