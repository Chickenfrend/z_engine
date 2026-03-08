const std = @import("std");
const GraphicsApi = @import("../z_graphics/Window.zig").GraphicsApi;
const DrawCommand = @import("./DrawCommand.zig").DrawCommand;
const OpenGLBackend = @import("./opengl/RenderPipeline.zig").RenderPipeline;

const BackendImpl = union(enum) {
    opengl: OpenGLBackend,
    vulkan: void, // placeholder
};

// Right now this is being implemented directly by the public renderer.
// I think there should be a render queue, also. I'm not certain if it should go 
// backend->renderqueue or renderqueue->backend.
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

    pub fn submit(self: *Backend, cmd: DrawCommand) void {
        switch (self.impl) {
            .opengl => |*gl| gl.submit(cmd),
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
