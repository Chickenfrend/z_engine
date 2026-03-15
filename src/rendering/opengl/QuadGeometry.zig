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

pub const InstanceData = extern struct {
    model: [16]f32,
    uv_offset: [2]f32,
    uv_size: [2]f32,
};

pub const QuadGeometry = struct {
    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,
    instance_VBO: c_uint,

    // Position (x, y, z) + UV (u, v)
    const vertices = [20]f32{
        1.0, 1.0, 0.0, 1.0, 1.0, // right top (y=1 in screen space = bottom of quad)
        1.0, 0.0, 0.0, 1.0, 0.0,  // right bottom
        0.0, 0.0, 0.0, 0.0, 0.0,  // left bottom
        0.0, 1.0, 0.0, 0.0, 1.0, // left top   
    };

    const indices = [6]u32{
        0, 1, 3,
        1, 2, 3,
    };

    pub fn init() QuadGeometry {
        var geo: QuadGeometry = undefined;

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

        // This sets up the uv_offset for sprites.
        c.glEnableVertexAttribArray(6);
        c.glVertexAttribPointer(
            6, 
            2, 
            c.GL_FLOAT, 
            c.GL_FALSE, 
            @sizeOf(InstanceData), 
            @ptrFromInt(@offsetOf(InstanceData, "uv_offset"))
        );
        c.glVertexAttribDivisor(6, 1);

        // This sets up the uv_size for sprites.
        c.glEnableVertexAttribArray(7);
        c.glVertexAttribPointer(
            7,
            2, 
            c.GL_FLOAT, 
            c.GL_FALSE, 
            @sizeOf(InstanceData), 
            @ptrFromInt(@offsetOf(InstanceData, "uv_offset"))
        );
        c.glVertexAttribDivisor(7, 1);

        c.glBindVertexArray(0);

        return geo;
    }

    pub fn deinit(self: *QuadGeometry) void {
        c.glDeleteVertexArrays(1, &self.VAO);
        c.glDeleteBuffers(1, &self.VBO);
        c.glDeleteBuffers(1, &self.EBO);
        c.glDeleteBuffers(1, &self.instance_VBO);
    }

} ;
