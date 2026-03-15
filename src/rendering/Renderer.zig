// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const SquareGeometry = @import("./Square.zig").SquareGeometry;
const Square = @import("./Square.zig").Square;
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

    // This should maybe return some kind of struct to wrap the u32.
    // The u32 is all it needs at the moment but it's not very, descriptive.
    pub fn loadTexture(self: *Renderer, path: []const u8) DrawParams.Texture {
        return self.backend.loadTexture(path);
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

    pub fn drawSprite(self: *Renderer, params: DrawParams.SpriteParams) !void {
        const tw = params.texture.width;
        const th = params.texture.height;
        const command = DrawCommand {
            .position = params.position,
            .width = params.width,
            .height = params.height,
            .uv_offset = .{ params.sprite_rect.x / tw, params.sprite_rect.y / th },
            .uv_size = . { params.sprite_rect.width / tw, params.sprite_rect.height / th },
            .material = .{
                .texture = params.texture.id,
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
