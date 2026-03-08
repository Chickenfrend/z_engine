
// This is the data that the Render Pipeline needs in order to draw.
// uv_offset and uv_size are needed for textures.
// This may need to be expanded to support materials and so on.
// Right now, everything is a quad. If we want to add other shape primitives,
// like triangles, we might need to add a "shape" data section here.
// Or, and I think this is probably the direction we should go, add vertices as data here.
// It's possible different back ends might handle vertices and indices differently.
// But we could always pick one method and adjust for that in the backend code.
pub const DrawCommand = struct {
    position: [2]f32,
    width: f32,
    height: f32,
    texture: ?u32,  // backend-agnostic handle, null for untextured
    uv_offset: [2]f32,
    uv_size: [2]f32,
    blend: bool,
};
