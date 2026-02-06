// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const Square = @import("./Square.zig");

const std = @import("std");
const zm = @import("zm");
const zigimg = @import("zigimg");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

// Rendering is currently only rendering squares. We should modify this and
// add batch rendering.
//
// An easy thing to do would be to add some kind of abstract geometry struct.
fn flattenMat4(mat: [4][4]f32) [16]f32 {
    return @as(*const [16]f32, @ptrCast(&mat)).*;
}

pub const RenderPipeline = struct {
    shader: Shader,
    projection: [4][4]f32,

    // The square geometry should be changed when we implement sprites. Probably.
    pub fn render(self: RenderPipeline, geometry: Square.SquareGeometry, positions: []const [2]f32, elapsed_ns: u64) !void {
        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Draw the square
        self.shader.use();
        self.shader.setMat4f("projection", flattenMat4(self.projection));

        const ns_per_cycle: f32 = 10 * std.time.ns_per_s;
        for (positions) |position| {
            const square_trans = zm.Mat4f.translation(position[0], position[1], 0.0);
            const factor: f32 = @floatCast(0.8 *
                @cos(2 * std.math.pi * @as(f32, @floatFromInt(elapsed_ns)) / ns_per_cycle));
            const scale = zm.Mat4f.scaling(300.0 * factor, 300.0 * factor, 1.0);

            // You could add rotation and stuff onto this.
            const modelM = square_trans.multiply(scale);

            self.shader.setMat4f("model", flattenMat4(modelM.data));

            // Draw square using indices
            geometry.draw();
        }
    }

    pub fn init(allocator: std.mem.Allocator) RenderPipeline {
        const shaderProgram: Shader = Shader.create(allocator, "src/rendering/shaders/position_shader.vs", "src/rendering/shaders/triangle_shader.frag");

        // TODO refactor texture loading
        var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
        var image = zigimg.Image.fromFilePath(allocator, "src/font.png", read_buffer[0..]) catch |err| {
            std.debug.print("Failed to load image: {}\n", .{err});
            std.process.exit(1);
        };
        defer image.deinit(allocator);

        // Create OpenGL texture
        var texture: c.GLuint = undefined;
        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        // Set texture parameters
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

        // Upload image data to GPU
        const img_data = image.pixels.rgb24;
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGB,
            @intCast(image.width),
            @intCast(image.height),
            0,
            c.GL_RGB,
            c.GL_UNSIGNED_BYTE,
            @ptrCast(img_data.ptr),
        );
        std.debug.print("Loaded texture: {}x{}\n", .{ image.width, image.height });

        const projM = zm.Mat4f.orthographicRH(0, WindowSize.width, WindowSize.height, 0, -1.0, 1.0);

        return RenderPipeline{
            .shader = shaderProgram,
            .projection = projM.data,
        };
    }

    pub fn cleanup(self: RenderPipeline) !void {
        defer c.glDeleteVertexArrays(1, &self.vao);
        defer c.glDeleteBuffers(1, &self.vbo);
        defer c.glDeleteBuffers(1, &self.ebo);
    }
};

fn calculateGreenValue(time: f64) f32 {
    const timeCasted: f32 = @floatCast(time);
    return @sin(timeCasted) / 2.0 + 0.5;
}

// Changed this to slices so it isn't hard coded.
// But before it was 12 and 6. Not sure if this will create performance issues.
const VertexData = struct {
    vertices: []f32,
    indices: []u32,
};
