const std = @import("std");
const GraphicsApi = @import("../window/Window.zig").GraphicsApi;
const OpenGLBackend = @import("./opengl/OpenGLBackend.zig").OpenGLBackend;
const Camera2D = @import("./Camera.zig").Camera2D;

pub const Material = struct {
    texture: ?u32,
    color: [4]f32,
    blend: bool,
};

// I went ahead and added a material. I may add a mesh later.
// We should also probably have a transform component in the draw command. So it would have a
// mesh, a material, and a transform. The transform would have position data.
//
// On second though, I think we don't need a mesh and transform for the 2d draw command.
pub const DrawCommand = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    uv_offset: [2]f32,
    uv_size: [2]f32,
    material: Material,
};

const BackendImpl = union(enum) {
    opengl: OpenGLBackend,
    vulkan: void, // placeholder
};

// This is just a little abstraction layer on the backend.
// It's here so we can support multiple backends later.
pub const Backend = struct {
    impl: BackendImpl,

    pub fn beginDrawing(self: *Backend, camera: Camera2D) void {
        switch (self.impl) {
            .opengl => |*gl| gl.beginDrawing(camera.getViewMatrix()),
            .vulkan => unreachable,
        }
    }

    pub fn init(allocator: std.mem.Allocator, api: GraphicsApi) Backend {
        return switch (api) {
            .opengl => Backend{
                .impl = .{ .opengl = OpenGLBackend.init(allocator) },
            },
            .vulkan => @panic("Vulkan not yet support"),
        };
    }

    pub fn loadTexture(self: *Backend, path: []const u8) u32 {
        return switch (self.impl) {
            .opengl => |*gl| gl.loadTexture(path),
            .vulkan => unreachable,
        };
    }

    // Maybe this should be called beingDrawing, to match endDrawing?
    pub fn render(self: *Backend, commands: []DrawCommand) !void {
        switch (self.impl) {
            .opengl => |*gl| try gl.render(commands),
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
