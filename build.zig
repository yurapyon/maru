const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.addCSourceFile("deps/stb/stb_image.c", &[_][]const u8{"-std=c99"});

    main_tests.addIncludeDir("/usr/include");
    main_tests.addIncludeDir("deps/stb");

    main_tests.addLibPath("/usr/lib");
    main_tests.linkSystemLibrary("c");
    main_tests.linkSystemLibrary("glew");
    main_tests.linkSystemLibrary("glfw");
    main_tests.linkSystemLibrary("epoxy");

    main_tests.addPackagePath("nitori", "lib/nitori/src/main.zig");
    main_tests.addPackagePath("json", "lib/json/json.zig");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
