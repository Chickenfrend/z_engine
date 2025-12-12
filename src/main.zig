//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const zm = @import("zm");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");
    @cInclude("GLFW/glfw3.h");
});

const state = @import("./ecs/state.zig");
const Shader = @import("./rendering/ShaderLib.zig");
const Square = @import("./rendering/Square.zig");
const Renderer = @import("./rendering/Render.zig");

// This main functions does a lot. It creates shaders, links them, opens a window, and draws a triangle.
// Probably we could split these aparts and have modules dedicated to shaders, a module for shapes, and so on.
pub fn setupWindow() ?*c.GLFWwindow {
    _ = c.glfwInit();
    // Without these hints the shaders wouldn't compile. They might need to be changed depending on your system and openGL version.
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    _ = c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    // I think this is for mac only.
    _ = c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    const window = c.glfwCreateWindow(Renderer.WindowSize.width, Renderer.WindowSize.height, "Test Window", null, null) orelse {
        @panic("Could not open window!");
    };

    _ = c.glfwMakeContextCurrent(window);
    return window;
}

pub fn main() !void {
    const window = setupWindow();

    _ = c.glfwSetFramebufferSizeCallback(window, frame_buffer_size_callback);

    // Setup allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena_allocator = arena_allocator_state.allocator();
    // This is the creation of the shader program.
    var render_pipeline = Renderer.RenderPipeline.init(arena_allocator);

    const geometry = Square.SquareGeometry.init();

    const square_positions = [_][2]f32{
        .{ 100, 200 },
        .{ 0, 0 },
        .{ 750, 550 },
        .{ 250, 250 },
        .{ 400, 300 },
    };

    var global_state: state.GlobalState = .{
        .clock = std.time.Timer.start() catch |err| {
            std.debug.panic("Couldn't find timer!: {s}\n", .{@errorName(err)});
        },
        .game_state = state.GameState.init(arena_allocator) catch |err| {
            std.debug.panic("Failed to initialize game state: {s}\n", .{@errorName(err)});
        },
    };

    // This is the loop that keeps the window open and draws to the screen.

    //c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    global_state.clock.reset();
    var num_frames: u64 = 0;
    var last_second: u64 = 0;
    while (c.glfwWindowShouldClose(window) == 0) {
        const total_elapsed_ns = global_state.clock.read();

        // Process Input
        processInput(window);

        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        try render_pipeline.render(geometry, &square_positions);

        if (total_elapsed_ns / std.time.ns_per_s > last_second) {
            std.debug.print("{d} fps\n", .{num_frames});
            num_frames = 0;
            last_second += 1;
        }
        c.glfwSwapBuffers(window);
        num_frames += 1;
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
