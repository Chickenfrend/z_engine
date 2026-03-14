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
    sprite_rect: SpriteRect,
//    uv_offset: [2]f32,
//    uv_size: [2]f32,
};

// This defines the position of the sprite within the texture, starting
// from top left. Then, it also defines the width and height of the texture.
pub const SpriteRect = struct {
    x: f32,
    y: f32,
    width: f32,
    heigh: f32,
};
