const std = @import("std");
const GraphicsApi = @import("../z_graphics/Window.zig").GraphicsApi;
const DrawCommand = @import("./Drawable.zig").DrawCommand;
const OpenGLBackend = @import("./opengl/OpenGLBackend.zig").OpenGLBackend;

const BackendImpl = union(enum) {
    opengl: OpenGLBackend,
    vulkan: void, // placeholder
};

// This is just a little abstraction layer on the backend.
// It's here so we can support multiple backends later.
pub const Backend = struct {
    impl: BackendImpl,

    pub fn init(allocator: std.mem.Allocator, api: GraphicsApi) !Backend {
        return switch (api) {
            .opengl => Backend{
                .impl = .{ .opengl = OpenGLBackend.init(allocator) },
            },
            .vulkan => return error.NotYetSupported,
        };
    }

    pub fn render(self: *Backend, commands: []DrawCommand) void {
        switch (self.impl) {
            .opengl => |*gl| gl.render(commands),
            .vulkan => unreachable,
        }
    }

    pub fn deinit(self: *Backend) void {
        switch (self.impl) {
            .opengl => |*gl| gl.cleanup(),
            .vulkan => unreachable,
        }
    }
};
