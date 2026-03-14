// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const SquareGeometry = @import("./Square.zig").SquareGeometry;
const Square = @import("./Square.zig").Square;
const Texture = @import ("./Texture.zig").Texture;
const Backend = @import("./Backend.zig").Backend;
const DrawCommand = @import("./Backend.zig").DrawCommand;
const DrawParams = @import("./DrawParams.zig");
const Camera2D = @import("./Camera.zig").Camera2D;

// Maybe the GraphicsApi enum should not live in the window module.
const GraphicsApi = @import("../window/Window.zig").GraphicsApi;

const std = @import("std");

// Right now, the render queue can just be an array.
// Later, it will have to sort things as they enter and so on.
// We can update flush then.
// The renderQueue here should be turned into some array with a static size.
// Render queue should be its own struct which you can add to,
// which can also get full. When it gets full, we should force a flush.
// When we do this, we might be able to get rid of some of the error returns.
pub const Renderer = struct {
    allocator: std.mem.Allocator,
    camera: Camera2D,
    backend: Backend,
    renderQueue: std.ArrayList(DrawCommand),

    pub fn init(allocator: std.mem.Allocator, api: GraphicsApi) !Renderer {
        return Renderer {
            .allocator = allocator,
            .camera = .{},
            .backend = Backend.init(allocator, api),
            .renderQueue = .empty,
        };
    }

    pub fn drawRect(self: *Renderer, params: DrawParams.RectParams) !void {
        const command = DrawCommand {
            .position = params.position,
            .width = params.width,
            .height = params.height,
            .uv_offset = .{0, 0},
            .uv_size = .{1, 1},
            .material = .{
                .texture = null,
                .color = params.color,
                .blend = false,
            }
        };

        try self.renderQueue.append(self.allocator, command);
    }

    pub fn drawSprite(self: *Renderer, params: DrawParams.RectParams) !void {
        const command = DrawCommand {
            .position = params.position,
            .width = params.width,
            .height = params.height,
            .uv_offset = params.uv_offset,
            .uv_size = params.uv_size,
            .material = .{
                .texture = params.texture,
                .color = params.color,
                .blend = false,
            }
        };

        try self.renderQueue.append(self.allocator, command);
    }

    pub fn beginDrawing(self: *Renderer) void {
        self.backend.beginDrawing(self.camera);
    }

    pub fn endDrawing(self: *Renderer) !void {
        try self.backend.render(self.renderQueue.items);
        self.renderQueue.clearRetainingCapacity();
    }

    pub fn deinit(self: *Renderer) void {
        self.backend.deinit();
        self.renderQueue.deinit(self.allocator);
    }

};

// Render queue here.
