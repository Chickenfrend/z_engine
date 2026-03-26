// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const SquareGeometry = @import("./Square.zig").SquareGeometry;
const Square = @import("./Square.zig").Square;
const Backend = @import("./Backend.zig").Backend;
const DrawCommand = @import("./Backend.zig").DrawCommand;
const DrawParams = @import("./DrawParams.zig");
const Camera2D = @import("./Camera.zig").Camera2D;
const RenderQueueModule = @import("./RenderQueue.zig");
const RenderQueue = RenderQueueModule.RenderQueue;
const RENDER_QUEUE_SIZE = RenderQueueModule.RENDER_QUEUE_SIZE;

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
    renderQueue: RenderQueue,
    batch_commands: [RENDER_QUEUE_SIZE]DrawCommand = undefined,

    // We're passing the window width and height but we need to thread through a resize
    // callback from the window module to the backend.
    pub fn init(allocator: std.mem.Allocator, api: GraphicsApi, window_width: u32, window_height: u32) !Renderer {
        return Renderer {
            .allocator = allocator,
            .camera = .{},
            .backend = Backend.init(allocator, api, window_width, window_height),
            .renderQueue = RenderQueue.init(),
        };
    }

    pub fn beginDrawing(self: *Renderer) void {
        self.renderQueue.reset();
        self.backend.beginDrawing(self.camera);
    }

    pub fn loadTexture(self: *Renderer, path: []const u8) !DrawParams.Texture {
        return self.backend.loadTexture(path);
    }

    pub fn drawRect(self: *Renderer, params: DrawParams.RectParams) !void {
        const command = DrawCommand {
            .position = params.position,
            .width = params.width,
            .height = params.height,
            .uv_offset = .{0, 0},
            .uv_size = .{1, 1},
            .layer = params.layer,
            .order = params.order,
            .material = .{
                .texture = null,
                .color = params.color,
                .render_class = params.render_class, 
            }
        };

        try self.pushToQueue(command);
    }

    // I'm not sure if this should return an error.
    // Actually, eventually it definitely shouldn't because renderQueue should be a fixed
    // size.
    pub fn drawSprite(self: *Renderer, params: DrawParams.SpriteParams) !void {
        const tw: f32 = @floatFromInt(params.texture.width);
        const th: f32 = @floatFromInt(params.texture.height);
        const command = DrawCommand {
            .position = params.position,
            .width = params.width,
            .height = params.height,
            .layer = params.layer,
            .order = params.order,
            .uv_offset = .{ params.sprite_rect.x / tw, params.sprite_rect.y / th },
            .uv_size = . { params.sprite_rect.width / tw, params.sprite_rect.height / th },
            .material = .{
                .texture = params.texture.id,
                .color = params.color,
                .render_class = params.render_class,
            }
        };

        try self.pushToQueue(command);
    }

    fn pushToQueue(self: *Renderer, command: DrawCommand) !void {
        if (self.renderQueue.isFull()) {
            try self.flushQueue();
        }

        try self.renderQueue.push(command);
    }

    fn flushQueue(self: *Renderer) !void {
        if (self.renderQueue.isEmpty()) {
            return;
        }

        self.renderQueue.sort();
        const items = self.renderQueue.items[0..self.renderQueue.len];
        var start_index: usize = 0;

        while (start_index < items.len) {
            const end_index = self.renderQueue.nextBatchEnd(start_index);

            for (items[start_index..end_index], 0..) |entry, i| {
                self.batch_commands[i] = entry.command;
            }

            try self.backend.render(self.batch_commands[0 .. end_index - start_index]);
            start_index = end_index;
        }

        self.renderQueue.clear();
    }

    // Very crude texture sorting.
    pub fn endDrawing(self: *Renderer) !void {
        try self.flushQueue();
    }

    pub fn deinit(self: *Renderer) void {
        self.backend.deinit();
    }

};

