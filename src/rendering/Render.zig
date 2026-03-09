// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const SquareGeometry = @import("./Square.zig").SquareGeometry;
const Square = @import("./Square.zig").Square;
const Texture = @import ("./Texture.zig").Texture;
const DrawCommand = @import("./Drawable.zig").DrawCommand;
const Drawable = @import("./Drawable.zig").Drawable;
const Backend = @import("./Backend.zig").Backend;

// Maybe the GraphicsApi enum should not live in the window module.
const GraphicsApi = @import("../window/Window.zig").GraphicsApi;

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


// Right now, the render queue can just be an array.
// Later, it will have to sort things as they enter and so on.
// We can update flush then.
pub const Renderer = struct {
    backend: Backend,
    renderQueue: std.ArrayList(DrawCommand),

    pub fn init(allocator: std.mem.Allocator, api: GraphicsApi) Renderer {
        return Renderer {
            .Backend = Backend.init(allocator, api),
        };
    }

    pub fn draw(self: *Renderer, drawable: Drawable) void {
        const cmd = switch (drawable) {
            .rect => |q| q.drawCommand(),
            .sprite => |s| s.drawCommand(),
        };
        self.backend.render(cmd);
    }

};

// Render queue here.
