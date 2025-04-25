const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "vulkan_window",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (target.result.os.tag == .macos) {
        // Add include paths
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/glfw/include" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/vulkan-loader/include" });
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/vulkan-headers/include" });

        // Add library paths
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/glfw/lib" });
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/vulkan-loader/lib" });

        // Link libraries
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    } else if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("glfw");
        exe.linkSystemLibrary("vulkan");
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the application");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
}
