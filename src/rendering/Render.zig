// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const Square = @import("./Square.zig");

const std = @import("std");
const zm = @import("zm");
const zigimg = @import("zigimg");

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
    allocator: std.mem.Allocator,
    matrices: std.ArrayList([16]f32),

    // The square geometry should be changed when we implement sprites. Probably.
    pub fn render(self: *RenderPipeline, geometry: Square.SquareGeometry, positions: []const [2]f32) !void {
        // Render
        // This clears the screen
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Reuse memory
        self.matrices.clearRetainingCapacity();

        for (positions) |position| {
            const square_trans = zm.Mat4f.translation(position[0], position[1], 0.0);
            const scale = zm.Mat4f.scaling(300.0, 300.0, 1.0);

            // You could add rotation and stuff onto this.
            const modelM = square_trans.multiply(scale);

            // Add to the list of things to be drawn.
            try self.matrices.append(self.allocator, flattenMat4(modelM.data));
        }

        // Send the instance data
        geometry.updateInstanceData(self.matrices.items);

        // Draw the square
        self.shader.use();
        self.shader.setMat4f("projection", flattenMat4(self.projection));

        // Draw em all. We're sending the instance count here.
        geometry.drawInstanced(@intCast(positions.len));
    }

    pub fn init(allocator: std.mem.Allocator) RenderPipeline {
        const shaderProgram: Shader = Shader.create(
            allocator,
            "src/rendering/shaders/position_shader.vs",
            "src/rendering/shaders/triangle_shader.frag",
        );

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
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        const gl_format: c.GLint, const img_ptr: ?*const anyopaque = switch (image.pixels) {
            .grayscale8 => |data| .{ c.GL_RED, @ptrCast(data.ptr) },
            .rgb24 => |data| .{ c.GL_RGB, @ptrCast(data.ptr) },
            .rgba32 => |data| .{ c.GL_RGBA, @ptrCast(data.ptr) },
            else => {
                std.debug.print("Unsupported pixel format: {}\n", .{image.pixels});
                std.process.exit(1);
            },
        };

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            gl_format,
            @intCast(image.width),
            @intCast(image.height),
            0,
            @intCast(gl_format),
            c.GL_UNSIGNED_BYTE,
            img_ptr,
        );
        std.debug.print("Loaded texture: {}x{}\n", .{ image.width, image.height });

        const projM = zm.Mat4f.orthographicRH(0, WindowSize.width, WindowSize.height, 0, -1.0, 1.0);

        return RenderPipeline{
            .shader = shaderProgram,
            .projection = projM.data,
            .allocator = allocator,
            .matrices = .empty,
        };
    }

    pub fn cleanup(self: *RenderPipeline) void {
        self.matrices.deinit(self.allocator);
        c.glDeleteProgram(self.shader.ID);
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
