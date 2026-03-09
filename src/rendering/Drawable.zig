// This module 

// This is the data that the Render Pipeline needs in order to draw.
// uv_offset and uv_size are needed for textures.
// This may need to be expanded to support materials and so on.
// Right now, everything is a quad. If we want to add other shape primitives,
// like triangles, we might need to add a "shape" data section here.
// Or, and I think this is probably the direction we should go, add vertices as data here.
// It's possible different back ends might handle vertices and indices differently.
// But we could always pick one method and adjust for that in the backend code.
//
// Actually. This should have a mesh and a material, I think. 
// Different shapes would have different meshes.
//
// Okay, I went ahead and added a material. I may add a mesh later.
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

    pub fn drawCommand(self: *SpriteDrawable) DrawCommand {
        return DrawCommand {
            .position = self.position,
            .width = self.width,
            .height = self.height,
            .uv_offset = self.uv_offset,
            .uv_size = self.uv_size,
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
