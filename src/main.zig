//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const zstbi = @import("zstbi");
const zm = @import("zmath");
const Shader = @import("./rendering/ShaderLib.zig");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");    
    @cInclude("GLFW/glfw3.h");
});

const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

// This main functions does a lot. It creates shaders, links them, opens a window, and draws a triangle.
// Probably we could split these aparts and have modules dedicated to shaders, a module for shapes, and so on.

pub fn main() !void {
    _ = c.glfwInit();
    // Without these hints the shaders wouldn't compile. They might need to be changed depending on your system and openGL version.
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    _ = c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    // I think this is for mac only.
    _ = c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    const window = c.glfwCreateWindow(WindowSize.width, WindowSize.height, "Test Window", null, null);
    _ = c.glfwMakeContextCurrent(window);

    _ = c.glfwSetFramebufferSizeCallback(window, frame_buffer_size_callback);

    // Setup allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena_allocator = arena_allocator_state.allocator();
    // This is the creation of the shader program.
    const shaderProgram: Shader = Shader.create(arena_allocator, "src/rendering/shaders/position_shader.vs", "src/rendering/shaders/triangle_shader.fs");

    // These are the twelve vertices that make up the square.
    const vertices = [12]f32{
        0.5,
        0.5,
        0.0,
        0.5,
        -0.5,
        0.0,
        -0.5,
        -0.5,
        0.0,
        -0.5,
        0.5,
        0.0,
    };
    // These are the indices for the two triangles that make up the square.
    const indices = [6]u32{
        0, 1, 3,
        1, 2, 3,
    };
    const square_positions = [_][2]f32{
        .{ 100.0, 100.0 },
        .{ 300.0, 200.0 },
        .{ 500.0, 150.0 },
        .{ 200.0, 400.0 },
        .{ 600.0, 450.0 },
    };

    // This is the vertex buffer id, the vertex array object id, and the element buffer object ID. Later we assign a vertex buffer to the vertex buffer id.
    // The vertex buffer lets us send a lot of vertex information to the GPU at once.
    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;
    var EBO: c_uint = undefined;
    c.glGenVertexArrays(1, &VAO);
    defer c.glDeleteVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);
    defer c.glDeleteBuffers(1, &VBO);
    c.glGenBuffers(1, &EBO);
    defer c.glDeleteBuffers(1, &EBO);

    // We start by binding the vertex array object.
    c.glBindVertexArray(VAO);

    // Then we bind the vertex buffer object. This is where we send the vertex data to the GPU.
    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, c.GL_STATIC_DRAW);

    // Now we bind the element buffer object. This is where we send the indices to the GPU.
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, EBO);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, c.GL_STATIC_DRAW);

    // This tells openGL how to interpret the vertex data. It defines the layout of the vertex data in the buffer.
    // These parameters are confusing. But, info on them can be found here: https://learnopengl.com/Getting-started/Hello-Triangle
    // I'll just say that the 3 is because we're using vec3
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    // Buffer to store Model and Projection matrices
    var model: [16]f32 = undefined;
    var proj: [16]f32 = undefined;

    // This is the loop that keeps the window open and draws to the screen.
    while (c.glfwWindowShouldClose(window) == 0) {

        // Input
        processInput(window);

        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Project and positioning.
        const projM = x: {
            var window_size = window.getSize();
            var width = @intToFloat(f32, window_size.width);
            var height = @intToFloat(f32, window_size.height);
            
            // Orthographic projection - maps directly to screen coordinates
            var projM = zm.orthographicRh(0.0, width, 0.0, height, 0.1, 100.0);
            break :x projM;
        };
        zm.storeMat(&proj, projM);
        shader_program.setMat4f("projection", proj);


        // Draw the squares

        for (square_position, 0..) |square_position, i| {
            // Translation based on the position
            const square_trans = zm.translation(square_position[0], square_position[1], 0.0);

            // You could add rotation and stuff onto this.
            const modelM = square_trans;

            zm.storeMat(&model, modelM);
            shader_program.setMat4f("model", model);
            
            // Draw square using indices
            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
        }

        // Draw the square
        shaderProgram.use();
        c.glBindVertexArray(VAO);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glfwTerminate();

    return;
}

fn frame_buffer_size_callback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    c.glViewport(0, 0, width, height);
}

fn processInput(window: ?*c.GLFWwindow) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, 1);
    }
}

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig-opengl_lib");
