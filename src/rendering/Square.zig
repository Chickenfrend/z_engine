const Rendering = @import("./Render.zig");
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

pub const SquareGeometry = struct {
    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,
    instance_VBO: c_uint,

    // Position (x, y, z) + UV (u, v)
    const vertices = [20]f32{
        0.5, 0.5, 0.0, 0.128, 0.21, // right top
        0.5, -0.5, 0.0, 0.128, 0.1, // right bottom
        -0.5, -0.5, 0.0, 0.06, 0.1, // left bottom
        -0.5, 0.5, 0.0, 0.06, 0.21, // left top
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
        c.glGenBuffers(1, &geo.instance_VBO);

        c.glBindVertexArray(geo.VAO);

        // Setup vertex data
        c.glBindBuffer(c.GL_ARRAY_BUFFER, geo.VBO);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, geo.EBO);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

        // Position attribute
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);

        // UV attribute (from VBO)
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(1);

        // Setup for instance data buffer
        c.glBindBuffer(c.GL_ARRAY_BUFFER, geo.instance_VBO);

        // Model matrix columns (each mat4 takes 4 attribute locations)
        // We'll send the full 4x4 matrix per instance
        var i: u32 = 0;
        while (i < 4) : (i += 1) {
            const loc = 2 + i;  // locations 2, 3, 4, 5
            c.glEnableVertexAttribArray(loc);
            c.glVertexAttribPointer(
                loc, 
                4, 
                c.GL_FLOAT, 
                c.GL_FALSE, 
                @sizeOf([16]f32),  // stride = size of mat4
                @ptrFromInt(i * @sizeOf([4]f32))  // offset to each column
            );
            c.glVertexAttribDivisor(loc, 1);  // This makes it instanced
        }

        c.glBindVertexArray(0);

        return geo;
    }

    pub fn deinit(self: *SquareGeometry) void {
        c.glDeleteVertexArrays(1, &self.VAO);
        c.glDeleteBuffers(1, &self.VBO);
        c.glDeleteBuffers(1, &self.EBO);
        c.glDeleteBuffers(1, &self.instance_VBO);
    }

    pub fn draw(self: *const SquareGeometry) void {
        c.glBindVertexArray(self.VAO);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
    }

    pub fn drawInstanced(self: *const SquareGeometry, instance_count: c_int) void {
        c.glBindVertexArray(self.VAO);
        c.glDrawElementsInstanced(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null, instance_count);
    }

    pub fn updateInstanceData(self: *const SquareGeometry, matrices: []const [16]f32) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.instance_VBO);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(matrices.len * @sizeOf([16]f32)),
            matrices.ptr,
            c.GL_DYNAMIC_DRAW
        );
    }
};
pub const Square = struct {
    position: [2]f32,
    width: f32,
    length: f32,
};
