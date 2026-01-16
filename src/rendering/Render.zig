// File containing main renderer loop

const Shader = @import("ShaderLib.zig");
const Square = @import("./Square.zig");

const std = @import("std");
const zm = @import("zm");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};


// Rendering is currently only rendering squares. We should modify this and 
// add batch rendering.
//
// An easy thing to do would be to add some kind of abstract geometry struct.
pub const RenderPipeline = struct {
    shader: Shader,
    projection: @Vector(16, f32),

    // The square geometry should be changed when we implement sprites. Probably.
    pub fn render(self: RenderPipeline, geometry: Square.SquareGeometry, positions: []const [2]f32, ) !void {
        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Draw the square
        self.shader.use();
        self.shader.setMat4f("projection", self.projection);

        for (positions) |position| {
            const square_trans = zm.Mat4f.translation(position[0], position[1], 0.0);
            // const identity = zm.Mat4f.identity();
            const scale = zm.Mat4f.scaling(50.0, 50.0, 1.0);
            // const scale = identity;


            // You could add rotation and stuff onto this.
            const modelM = square_trans.multiply(scale); 

            self.shader.setMat4f("model", modelM.data);
            
            // Draw square using indices
            geometry.draw();
        }
    }

    pub fn init(allocator: std.mem.Allocator) RenderPipeline {
        const shaderProgram: Shader = Shader.create(allocator, "src/rendering/shaders/position_shader.vs", "src/rendering/shaders/triangle_shader.frag");


        const projM = zm.Mat4f.orthographic(0, WindowSize.width, WindowSize.height, 0, -1.0, 1.0);

        
        return RenderPipeline{
            .shader=shaderProgram,
            .projection=projM.data,
        };

    }

    pub fn cleanup(self: RenderPipeline) !void {
        defer c.glDeleteVertexArrays(1, &self.vao);
        defer c.glDeleteBuffers(1, &self.vbo);
        defer c.glDeleteBuffers(1, &self.ebo);
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
    indices: []u32
};
