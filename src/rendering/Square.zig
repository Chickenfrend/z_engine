const Rendering = @import("./Render.zig");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_GL", "");
    @cDefine("GL_GLEXT_PROTOTYPES", "");    
    @cInclude("GLFW/glfw3.h");
});

pub const SquareGeometry = struct {
    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,
    
    // Position (x, y, z) + UV (u, v)
    const vertices = [20]f32{
        0.5,  0.5,  0.0,  1.0, 1.0,  // top right
        0.5,  -0.5, 0.0,  1.0, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  0.0, 0.0,  // bottom left
        -0.5, 0.5,  0.0,  0.0, 1.0,  // top left
    };
    
    const indices = [6]u32{
        0, 1, 3,
        1, 2, 3,
    };
    
    pub fn init() SquareGeometry {
        var geo: SquareGeometry = undefined;
        
        c.glGenVertexArrays(1, &geo.VAO);
        c.glGenBuffers(1, &geo.VBO);
        c.glGenBuffers(1, &geo.EBO);
        
        c.glBindVertexArray(geo.VAO);
        
        c.glBindBuffer(c.GL_ARRAY_BUFFER, geo.VBO);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);
        
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, geo.EBO);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);
        
        // Position attribute
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);
        // UV attribute
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(1);
        
        return geo;
    }
    
    pub fn deinit(self: *SquareGeometry) void {
        c.glDeleteVertexArrays(1, &self.VAO);
        c.glDeleteBuffers(1, &self.VBO);
        c.glDeleteBuffers(1, &self.EBO);
    }
    
    pub fn draw(self: *const SquareGeometry) void {
        c.glBindVertexArray(self.VAO);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
    }
};
pub const Square = struct {
    position: [2]f32,
    width: f32,
    length: f32,
};
