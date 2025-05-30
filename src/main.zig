//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const builtin = @import("builtin");

const c = @cImport({
    if (builtin.os.tag == .macos) {
        @cInclude("OpenGL/gl.h");
        @cDefine("GLFW_INCLUDE_NONE", {});
        @cInclude("GLFW/glfw3.h");
    } else {
        @cInclude("GL/gl.h");
        @cDefine("GLFW_INCLUDE_NONE", {});
        @cInclude("GLFW/glfw3.h");
    }
});


pub fn main() !void {
    _ = c.glfwInit();
    const window = c.glfwCreateWindow(800, 600, "Test", null, null);
    _ = c.glfwMakeContextCurrent(window);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glfwTerminate();
    return;
}
