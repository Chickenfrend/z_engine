//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const zm = @import("zm");

const builtin = @import("builtin");

const c = if (builtin.os.tag == .macos)
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("OpenGL/gl3.h");
    })
else
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cDefine("GL_GLEXT_PROTOTYPES", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("GL/gl.h");
        @cInclude("GL/glext.h");
    });

const state = @import("./ecs/state.zig");
const Shader = @import("./rendering/ShaderLib.zig");
const Square = @import("./rendering/Square.zig");
const Renderer = @import("./rendering/Render.zig");
const FontRenderer = @import("./rendering/FontRenderer.zig");

// This main functions does a lot. It creates shaders, links them, opens a window, and draws a triangle.
// Probably we could split these aparts and have modules dedicated to shaders, a module for shapes, and so on.
pub fn setupWindow() ?*c.GLFWwindow {
    if (c.glfwInit() == 0) {
        std.debug.print("GLFW init failed!\n", .{});
        return null;
    }

    // Without these hints the shaders wouldn't compile. They might need to be changed depending on your system and openGL version.
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    _ = c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    // I think this is for mac only.
    _ = c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    var window = c.glfwCreateWindow(Renderer.WindowSize.width, Renderer.WindowSize.height, "Z Engine", null, null);

    if (window == null) {
        std.debug.print("OpenGL 3.3 failed, trying 3.0...\n", .{});
        // Fallback to OpenGL 3.0
        _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        _ = c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 0);
        window = c.glfwCreateWindow(Renderer.WindowSize.width, Renderer.WindowSize.height, "Z Engine", null, null);
    }

    if (window == null) {
        std.debug.print("All OpenGL versions failed. GPU/driver issue.\n", .{});
        @panic("Could not open window!");
    }

    _ = c.glfwMakeContextCurrent(window);

    // Print which GPU we're using
    const renderer = c.glGetString(c.GL_RENDERER);
    const version = c.glGetString(c.GL_VERSION);
    std.debug.print("Using GPU: {s}\n", .{renderer});
    std.debug.print("OpenGL Version: {s}\n", .{version});

    return window;
}

pub fn main() !void {
    const window = setupWindow();

    _ = c.glfwSetFramebufferSizeCallback(window, frame_buffer_size_callback);

    // Setup allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena_allocator = arena_allocator_state.allocator();

    // This is the creation of the shader program.
    var render_pipeline = Renderer.RenderPipeline.init(arena_allocator);

    const geometry = Square.SquareGeometry.init();

    const square_positions = [_][2]f32{
        .{ 300, 300 },
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

    // Initialize FontRenderer
    // Try multiple font paths - system fonts or assets folder
    const font_paths = [_][]const u8{
        "assets/fonts/Roboto-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
    };

    var font_renderer: ?FontRenderer.FontRenderer = null;
    for (font_paths) |font_path| {
        font_renderer = FontRenderer.FontRenderer.init(
            arena_allocator,
            font_path,
            48,
            render_pipeline.projection,
        ) catch |err| {
            std.debug.print("Failed to load font from {s}: {s}\n", .{ font_path, @errorName(err) });
            continue;
        };
        std.debug.print("Loaded font from: {s}\n", .{font_path});
        break;
    }

    if (font_renderer == null) {
        std.debug.print("WARNING: No font loaded, text rendering will be skipped\n", .{});
    }

    defer {
        if (font_renderer) |*fr| {
            fr.deinit();
        }
    }

    // This is the loop that keeps the window open and draws to the screen.
    global_state.clock.reset();
    var num_frames: u64 = 0;
    var last_second: u64 = 0;
    var fps_display: u64 = 0;

    while (c.glfwWindowShouldClose(window) == 0) {
        const total_elapsed_ns = global_state.clock.read();

        // Process Input
        processInput(window);

        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Render squares
        try render_pipeline.render(geometry, &square_positions);

        // Render text if font is loaded
        if (font_renderer) |*fr| {
            // Title text
            fr.renderText("Z Engine - Game Engine", 10.0, 10.0, 0.8, .{ 1.0, 1.0, 1.0 });

            // FPS counter
            const fps_text = try std.fmt.allocPrint(arena_allocator, "FPS: {d}", .{fps_display});
            fr.renderText(fps_text, 10.0, 60.0, 0.6, .{ 0.0, 1.0, 0.0 });

            // Controls hint
            fr.renderText("Press ESC to exit", 10.0, @as(f32, @floatFromInt(Renderer.WindowSize.height)) - 60.0, 0.5, .{ 0.7, 0.7, 0.7 });
        }

        // Update FPS counter once per second
        if (total_elapsed_ns / std.time.ns_per_s > last_second) {
            fps_display = num_frames;
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

fn frame_buffer_size_callback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
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
