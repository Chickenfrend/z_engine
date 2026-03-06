//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const zm = @import("zm");

const builtin = @import("builtin");

const c = if (builtin.os.tag == .macos)
    @cImport({
        @cInclude("OpenGL/gl3.h");
    })
else
    @cImport({
        @cDefine("GL_GLEXT_PROTOTYPES", "");
        @cInclude("GL/gl.h");
        @cInclude("GL/glext.h");
    });

const state = @import("./ecs/state.zig");
const Shader = @import("./rendering/ShaderLib.zig");
const FontRenderer = @import("./rendering/FontRenderer.zig");
const PongState = @import("./PongState.zig").PongState;
const Window = @import("./window/Window.zig").Window;
const Renderer = @import("./rendering/Renderer.zig").Renderer;
const RectParams = @import("./rendering/DrawParams.zig").RectParams;

// This main functions does a lot. It creates shaders, links them, opens a window, and draws a triangle.
// Probably we could split these aparts and have modules dedicated to shaders, a module for shapes, and so on.

pub fn main() !void {
    var window = try Window.init(800, 600, "Z Engine", .opengl);
    defer window.deinit();

    // Setup allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var arena_allocator_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator_state.deinit();
    const arena_allocator = arena_allocator_state.allocator();

    var render_pipeline = try Renderer.init(arena_allocator, .opengl, window.width, window.height);
    defer render_pipeline.deinit();

    var pong = PongState.init(@floatFromInt(window.width), @floatFromInt(window.height));

    const background_texture = try render_pipeline.loadTexture("./assets/Signed_Pong_Cabinet.jpg");

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
    // This is bad lol. Should be removed. Also, fonts should be refactored to use the main render pipeline somehow.
    const projection = render_pipeline.backend.impl.opengl.projection;
    for (font_paths) |font_path| {
        font_renderer = FontRenderer.FontRenderer.init(
            arena_allocator,
            font_path,
            48,
            projection,
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

    var last_elapsed_ns: u64 = 0;
    while (!window.shouldClose()) {
        const size = window.getFramebufferSize();
        c.glViewport(0, 0, @intCast(size[0]), @intCast(size[1]));
        const total_elapsed_ns = global_state.clock.read();
        const delta_ns = total_elapsed_ns - last_elapsed_ns;
        last_elapsed_ns = total_elapsed_ns;

        // Process Input
        const dt: f32 = @floatCast(@as(f64, @floatFromInt(delta_ns)) / std.time.ns_per_s);
        window.processInput(&pong, &render_pipeline.camera, dt);
        pong.update(dt);

        const rects = [_]RectParams{
            .{ .position = .{ 20, pong.paddle_left_y }, .width = 20, .height = 100, .color = .{ 0, 0.5, 1, 1 } },
            .{ .position = .{ 760, pong.paddle_right_y }, .width = 20, .height = 100, .color = .{ 1, 0.2, 0.2, 1 } },
            .{ .position = pong.ball_pos, .width = 15, .height = 15, .color = .{ 1, 1, 0, 1 } },
        };
        render_pipeline.beginDrawing();

        const background_width: f32 = @floatFromInt(background_texture.width);
        const background_height: f32 = @floatFromInt(background_texture.height);
        try render_pipeline.drawSprite(.{ .position = .{ 300, 100 }, .width = background_width / 4.0, .height = background_height / 4.0, .texture = background_texture, .sprite_rect = .{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(background_texture.width),
            .height = @floatFromInt(background_texture.height),
        } });
        for (rects) |rect| {
            try render_pipeline.drawRect(rect);
        }

        // Render text if font is loaded
        if (font_renderer) |*fr| {
            // FPS counter
            const fps_text = try std.fmt.allocPrint(arena_allocator, "FPS: {d}", .{fps_display});
            fr.renderText(fps_text, 10.0, 60.0, 0.6, .{ 0.0, 1.0, 0.0 });

            // Controls hint
            fr.renderText("Press ESC to exit", 10.0, @as(f32, @floatFromInt(window.height)) - 60.0, 0.5, .{ 0.7, 0.7, 0.7 });
            //Pong Score
            fr.renderText(
                try std.fmt.allocPrint(arena_allocator, "{d} - {d}", .{ pong.left_score, pong.right_score }),
                @as(f32, Renderer.WindowSize.width) / 2 - 50,
                50.0,
                1.0,
                .{ 1.0, 1.0, 1.0 },
            );
        }

        // Update FPS counter once per second
        if (total_elapsed_ns / std.time.ns_per_s > last_second) {
            fps_display = num_frames;
            num_frames = 0;
            last_second += 1;
        }

        try render_pipeline.endDrawing();
        window.swapBuffers();
        num_frames += 1;
        window.pollEvents();
    }

    return;
}

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig-opengl_lib");
