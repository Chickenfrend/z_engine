// This is the data that the Render Pipeline needs in order to draw.
// uv_offset and uv_size are needed for textures.
//
// I went ahead and added a material. I may add a mesh later.
// We should also probably have a transform component in the draw command. So it would have a
// mesh, a material, and a transform. The transform would have position data.
pub const DrawCommand = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    uv_offset: [2]f32,
    uv_size: [2]f32,
    material: Material,
};

pub const Material = struct {
    texture: ?u32,
    color: [4]f32,
    blend: bool,
};

// Other drawables here.
pub const Drawable = union(enum) {
    rect: RectDrawable,
    sprite: SpriteDrawable,
};

pub const RectDrawable = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32,

    pub fn drawCommand(self: *RectDrawable) DrawCommand {
        return DrawCommand {
            .position = self.position,
            .width = self.width,
            .height = self.height,
            .uv_offset = .{0, 0},
            .uv_size = .{1, 1},
            .material = .{
                .texture = null,
                .color = self.color,
                .blend = false,
            },
        };
    }
};

pub const SpriteDrawable = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32,
    texture: u32,
    uv_offset: [2]f32,
    uv_size: [2]f32,

    pub fn drawCommand(self: *SpriteDrawable) DrawCommand {
        return DrawCommand {
            .position = self.position,
            .width = self.width,
            .height = self.height,
            .uv_offset = self.uv_offset,
            .uv_size = self.uv_size,
            .material = .{
                .texture = self.texture,
                .color = self.color,
                .blend = false,
            },
        };
    }
};
