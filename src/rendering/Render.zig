// File containing main renderer loop

const Shader = @import("ShaderLib.zig");

const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");
    @cInclude("GLFW/glfw3.h");
});

const WindowSize = struct {
    pub const width: u32 = 800;
    pub const height: u32 = 600;
};

const RenderPipeline = struct {
    vbo: c_uint,
    vao: c_uint,
    ebo: c_uint,
    shader: Shader,

    pub fn render(self: RenderPipeline) !void {
        // Render
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // Draw the square
        self.shader.use();

        const vertexColorLocation = c.glGetUniformLocation(self.shader.ID, "ourColor");
        c.glUniform4f(vertexColorLocation, 0.0, calculateGreenValue(c.glfwGetTime()), 0.0, 1.0);
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);   
    }

    pub fn cleanup(self: RenderPipeline) !void {
        defer c.glDeleteVertexArrays(1, &self.vao);
        defer c.glDeleteBuffers(1, &self.vbo);
        defer c.glDeleteBuffers(1, &self.ebo);
    }
};

pub fn setup(allocator: std.mem.Allocator) RenderPipeline{
    // This is the creation of the shader program.
    const shaderProgram: Shader = Shader.create(allocator, "src/rendering/shaders/triangle_shader.vert", "src/rendering/shaders/triangle_shader.frag");

    // These are the twelve vertices that make up the square.
    const vertices = [18]f32{
            // positions         // colors
         0.5, -0.5, 0.0,  1.0, 0.0, 0.0,   // bottom right
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,   // bottom left
         0.0,  0.5, 0.0,  0.0, 0.0, 1.0    // top 
    };
    // These are the indices for the two triangles that make up the square.
    const indices = [3]u32{
        0, 1, 2,
    };

    // This is the vertex buffer id, the vertex array object id, and the element buffer object ID. Later we assign a vertex buffer to the vertex buffer id.
    // The vertex buffer lets us send a lot of vertex information to the GPU at once.
    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;
    var EBO: c_uint = undefined;
    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);
    c.glGenBuffers(1, &EBO);

    // We start by binding the vertex array object.
    c.glBindVertexArray(VAO);

    // Then we bind the vertex buffer object. This is where we send the vertex data to the GPU.
    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, c.GL_STATIC_DRAW);

    // Now we bind the element buffer object. This is where we send the indices to the GPU.
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, EBO);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * indices.len, &indices, c.GL_STATIC_DRAW);

    // This tells openGL how to interpret the vertex data. It defines the layout of the vertex data in the buffer.
    // These parameters are confusing. But, info on them can be found here: https://learnopengl.com/Getting-started/Hello-Triangle
    // I'll just say that the 3 is because we're using vec3
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);
    
    c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), @ptrFromInt(3*@sizeOf(f32)));
    c.glEnableVertexAttribArray(1);

    // Uncomment this to get wireframes
    // c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    return RenderPipeline{.vao=VAO, .vbo=VBO, .ebo=EBO, .shader=shaderProgram};
}


fn calculateGreenValue(time: f64) f32 {
    const timeCasted: f32 = @floatCast(time);
    return @sin(timeCasted) / 2.0 + 0.5;
}

const VertexData = struct {
    vertices: []f32,
    indices: []u32
};
