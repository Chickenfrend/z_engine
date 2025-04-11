const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

fn errorCallback(error_code: c_int, description: [*c]const u8) callconv(.C) void {
    std.debug.print("GLFW Error ({}): {s}\n", .{error_code, description});
}

pub fn main() !void {
    _ = c.glfwSetErrorCallback(errorCallback);
    
    if (c.glfwInit() == 0) {
        std.debug.print("Failed to initialize GLFW\n", .{});
        return error.GLFWInitFailed;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_VISIBLE, c.GLFW_TRUE);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);

    const window = c.glfwCreateWindow(800, 600, "Vulkan Window", null, null) orelse {
        std.debug.print("Failed to create window\n", .{});
        return error.WindowCreationFailed;
    };
    defer c.glfwDestroyWindow(window);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();
        std.time.sleep(16_000_000); // ~60fps delay
    }
}