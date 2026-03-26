const RenderClass = @import("Backend.zig").RenderClass;

// This is the data that the Render Pipeline needs in order to draw.
// uv_offset and uv_size are needed for textures.

pub const RectParams = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32,
    layer: u16 = 0,
    order: u16 = 0,
    render_class: RenderClass = .solid,
};

pub const SpriteParams = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    color: [4]f32 = .{1, 1, 1, 1},
    texture: Texture,
    layer: u16 = 0,
    order: u16 = 0,
    sprite_rect: SpriteRect,
    render_class: RenderClass = .masked,
};

// This defines the position of the sprite within the texture with its x and y
// coordinates, starting from top left. 
// The width and heigh variables define the width and height of 
// the portion of the texture is uses.
pub const SpriteRect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

// This Texture type contains an id which refers to its position in the backend texture
// list, as well as the textures width and height in pixels.
// This might belong somewhere other than DrawParams. 
// Or maybe DrawParams should be renamed.
pub const Texture = struct {
    id: u32,
    width: u32,
    height: u32,
};
