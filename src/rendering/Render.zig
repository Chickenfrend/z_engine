// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const SquareGeometry = @import("./Square.zig").SquareGeometry;
const Square = @import("./Square.zig").Square;
const Texture = @import ("./Texture.zig").Texture;

const std = @import("std");
const zm = @import("zm");

const builtin = @import("builtin");

const c = if (builtin.os.tag == .macos)
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("OpenGL/gl3.h");
    })
else
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cDefine("GL_GLEXT_PROTOTYPES", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("GL/gl.h");
        @cInclude("GL/glext.h");
    });

pub const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

// Rendering is currently only rendering squares. We should modify this and
// add batch rendering.
//
// An easy thing to do would be to add some kind of abstract geometry struct.
fn flattenMat4(mat: [4][4]f32) [16]f32 {
    return @as(*const [16]f32, @ptrCast(&mat)).*;
}

pub const RenderPipeline = struct {
    shader: Shader,
    texture: Texture,
    projection: [4][4]f32,
    allocator: std.mem.Allocator,
    matrices: std.ArrayList([16]f32),

    // The square geometry should be changed when we implement sprites. Probably.
    // I think this should take a flag, called "instanced" or something, which would let it toggle
    // between rendering instanced and uniform/non-instanced.
    // I'm not sure exactly how that should be worked out or how instanced vs non instanced stuff
    // should be organized. Right now (02/26/2026) the VBO/VAO is associated with the geometry,
    // not the render pipeline.
    pub fn render(self: *RenderPipeline, geometry: SquareGeometry, squares: []const Square) !void {
        // Render
        // This clears the screen
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Reuse memory
        self.matrices.clearRetainingCapacity();

        for (squares) |square| {
            const square_trans = zm.Mat4f.translation(square.position[0], square.position[1], 0.0);
            const scale = zm.Mat4f.scaling(square.width, square.height, 1.0);

            // You could add rotation and stuff onto this.
            // This has to be transposed here because it isn't tranposed by the setMat4f
            // function like the projection matrix is.
            // I'm not sure how efficient this is.
            const modelM = square_trans.multiply(scale).transpose();

            // Add to the list of things to be drawn.
            try self.matrices.append(self.allocator, flattenMat4(modelM.data));
        }

        // Send the instance data
        geometry.updateInstanceData(self.matrices.items);

        // Draw the square
        self.shader.use();
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture.id);
        self.shader.setInt("textureSampler", 0);
        self.shader.setMat4f("projection", flattenMat4(self.projection));

        var bound_texture: c.GLint = 0;
        c.glGetIntegerv(c.GL_TEXTURE_BINDING_2D, &bound_texture);
        var bound_program: c.GLint = 0;
        c.glGetIntegerv(c.GL_CURRENT_PROGRAM, &bound_program);
        var blend_enabled: c.GLboolean = 0;
        c.glGetBooleanv(c.GL_BLEND, &blend_enabled);
        std.debug.print("texture: {d} (expected {d}), program: {d} (expected {d}), blend: {d}\n", .{
            bound_texture, self.texture.id,
            bound_program, self.shader.ID,
            blend_enabled,
        });
        // Draw em all. We're sending the instance count here.
        geometry.drawInstanced(@intCast(squares.len));
    }

    pub fn init(allocator: std.mem.Allocator) RenderPipeline {
        const shaderProgram: Shader = Shader.create(
            allocator,
            "src/rendering/shaders/position_shader.vs",
            "src/rendering/shaders/triangle_shader.frag",
        );

        const texture = Texture.initFromFile(allocator, "src/font.png");

        const projM = zm.Mat4f.orthographicRH(0, WindowSize.width, WindowSize.height, 0, -1.0, 1.0);

        return RenderPipeline{
            .shader = shaderProgram,
            .projection = projM.data,
            .allocator = allocator,
            .matrices = .empty,
            .texture = texture,
        };
    }

    pub fn cleanup(self: *RenderPipeline) void {
        self.matrices.deinit(self.allocator);
        self.texture.deinit();
        c.glDeleteProgram(self.shader.ID);
    }
};

fn calculateGreenValue(time: f64) f32 {
    const timeCasted: f32 = @floatCast(time);
    return @sin(timeCasted) / 2.0 + 0.5;
}

// Changed this to slices so it isn't hard coded.
// But before it was 12 and 6. Not sure if this will create performance issues.
const VertexData = struct {
    vertices: []f32,
    indices: []u32,
};
