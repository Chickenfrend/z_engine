// This is the data that the Render Pipeline needs in order to draw.
// uv_offset and uv_size are needed for textures.

pub const RectParams = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32,
};

pub const SpriteDrawable = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32,
    texture: u32,
    uv_offset: [2]f32,
    uv_size: [2]f32,
};
