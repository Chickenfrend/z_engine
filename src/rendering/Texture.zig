const std = @import("std");
const builtin = @import("builtin");
const zigimg = @import("zigimg");

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

pub const Texture = struct {
    id: c.GLuint,
    width: u32,
    height: u32,

    // Probably the texture parameters could be passed to this.
    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) Texture {
        var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
        var image = zigimg.Image.fromFilePath(allocator, path, read_buffer[0..]) catch |err| {
            std.debug.print("Failed to load image: {}\n", .{err});
            std.process.exit(1);
        };
        defer image.deinit(allocator);
        // Create OpenGL texture
        var textureId: c.GLuint = undefined;
        c.glGenTextures(1, &textureId);
        c.glBindTexture(c.GL_TEXTURE_2D, textureId);

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

        return Texture{
            .id = textureId,
            .width = @intCast(image.width),
            .height = @intCast(image.height),
        };
    }
    pub fn deinit(self: *Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
};
