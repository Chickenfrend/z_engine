//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const renderPipeline = @import("./rendering/Render.zig");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");    
    @cInclude("GLFW/glfw3.h");
    @cInclude("miniaudio.h");
});

const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

// This main functions does a lot. It creates shaders, links them, opens a window, and draws a triangle.
// Probably we could split these aparts and have modules dedicated to shaders, a module for shapes, and so on.

pub fn main() !void {
    var result: c.ma_result = undefined;
    var engine: c.ma_engine = std.mem.zeroes(c.ma_engine);

    result = c.ma_engine_init(null, &engine);
    if (result != c.MA_SUCCESS) {
        std.log.info("Failed to initialize engine\n", .{});
        std.process.exit(1);
    }
    defer c.ma_engine_uninit(&engine);

    std.log.info("Engine initialized successfully\n", .{});

    const file_path = "/home/peter/Projects/z_engine/examples/assets/example.wav";
    var sound: c.ma_sound = undefined;
    result = c.ma_sound_init_from_file(&engine, file_path, 0, null, null, &sound);
    if (result != c.MA_SUCCESS) {
        std.log.err("Failed to load sound: {d}\n", .{result});
        return;
    }
    defer c.ma_sound_uninit(&sound);

    result = c.ma_sound_start(&sound);
    if (result != c.MA_SUCCESS) {
        std.log.err("Failed to start sound: {d}\n", .{result});
        return;
    }

    std.log.info("Playing audio...\n", .{});
    // Wait for sound to finish
    while (c.ma_sound_is_playing(&sound) > 0) {
        std.time.sleep(100 * std.time.ns_per_ms);
    }
    
    //result = c.ma_engine_play_sound(
    //    &engine,
    //    "/home/peter/Projects/z_engine/examples/assets/example.wav",
    //    null
    //);
 
    //if (result != c.MA_SUCCESS) {
    //    std.log.err("Failed to play sound: {d}\n", .{result});
    //    return;
    //} 

    std.time.sleep(3 * std.time.ns_per_s);

}

pub fn other() !void {
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


    const pipeline = renderPipeline.setup(arena_allocator);
    var maResult: c.ma_result = undefined;

    var maResourceManagerConfig: c.ma_resource_manager_config = undefined;
    var maResourceManager: c.ma_resource_manager = undefined;

    std.log.info("Creating resource manager config...\n", .{});
    maResourceManagerConfig = c.ma_resource_manager_config_init();
    maResult = c.ma_resource_manager_init(&maResourceManagerConfig, &maResourceManager);
    if (maResult != c.MA_SUCCESS) {
        std.log.info("Failed to initialize the resource manager: {d}\n", .{maResult});
        std.process.exit(1);
    }
    defer c.ma_resource_manager_uninit(&maResourceManager);
    std.log.info("Finished creating resource manager\n", .{});

    var maEngine: c.ma_engine = undefined;
    var maEngineConfig: c.ma_engine_config = undefined;

    maEngineConfig = c.ma_engine_config_init();
    maEngineConfig.pResourceManager = &maResourceManager;

    std.log.info("Creating miniaudio engine...\n", .{});
    maResult = c.ma_engine_init(&maEngineConfig, &maEngine);
    if (maResult != c.MA_SUCCESS) {
        std.log.info("Failed to initialize engine: {d}\n", .{maResult});
        std.process.exit(1);
    }
    defer c.ma_engine_uninit(&maEngine);
    std.log.info("Finished creating engine.\n", .{});

    std.log.info("Playing sound...\n", .{});
    maResult = c.ma_engine_play_sound(&maEngine, "/home/peter/Projects/z_engine/examples/assets/example.wav", null);
    if (maResult != c.MA_SUCCESS) {
        std.log.info("Failed to play sound: {d}\n", .{maResult});
        std.process.exit(1);
    }
    std.time.sleep(3 * std.time.ns_per_s); // Wait 3 seconds
    std.log.info("Finished playing sound.\n", .{});
    
    // This is the loop that keeps the window open and draws to the screen.
    while (c.glfwWindowShouldClose(window) == 0) {

        // Input
        processInput(window);

        pipeline.render() catch |err| {
            std.log.info("Error while rendering: {s}\n", .{err});
            std.process.exit(1);
        };

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
