// File containing main renderer loop

const Shader = @import("../ShaderLib.zig");
const DrawCommand = @import("../Backend.zig").DrawCommand;
const QuadGeometry = @import("./QuadGeometry.zig").QuadGeometry;
const InstanceData = @import("./QuadGeometry.zig").InstanceData;
const Texture = @import("../DrawParams.zig").Texture;
const GPUTexture = @import ("./Texture.zig").Texture;

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

fn flattenMat4(mat: [4][4]f32) [16]f32 {
    return @as(*const [16]f32, @ptrCast(&mat)).*;
}

const MAX_TEXTURES: u32 = 1024;


pub const OpenGLBackend = struct {
    shader: Shader,
    textures: [MAX_TEXTURES]GPUTexture,
    view: [4][4]f32,
    projection: [4][4]f32,
    allocator: std.mem.Allocator,
    instanceData: std.ArrayList(InstanceData),
    geometry: QuadGeometry,
    texture_count: u32,

    // I think this should take a flag, called "instanced" or something, which would let it toggle
    // between rendering instanced and uniform/non-instanced.
    // I'm not sure exactly how that should be worked out or how instanced vs non instanced stuff
    // should be organized. Right now (02/26/2026) the VBO/VAO is associated with the geometry,
    // not the render pipeline.
    
    pub fn beginDrawing(self: *OpenGLBackend, view: [4][4]f32) void {
        self.view = view; 
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
    }

    pub fn render(self: *OpenGLBackend, drawCommands: []const DrawCommand) !void {
        // Reuse memory
        self.instanceData.clearRetainingCapacity();

        if (drawCommands.len == 0) return;

        c.glDisable(c.GL_BLEND);
        // Since we're instancing, each command should have the same texture.
        const texture_id = if (drawCommands[0].material.texture) |handle|
            self.textures[handle].id
        else
            self.textures[0].id;

        for (drawCommands) |command| {
            const translation_matrix = zm.Mat4f.translation(command.position[0], command.position[1], 0.0);
            const scale = zm.Mat4f.scaling(command.width, command.height, 1.0);

            // You could add rotation and stuff onto this.
            // This has to be transposed here because it isn't tranposed by the setMat4f
            // function like the projection matrix is.
            // I'm not sure how efficient this is. 
            // It's CPU side math every frame. The matrix is small though.
            const modelM = translation_matrix.multiply(scale).transpose();

            // Construct an instance data and append one for each draw command.
            try self.instanceData.append(self.allocator, .{
                .model = flattenMat4(modelM.data),
                .uv_offset = command.uv_offset,
                .uv_size = command.uv_size,
                .color = command.material.color,
            });
        }

        // Send the instance data
        self.updateInstanceData();

        // Draw
        self.shader.use();
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, texture_id);
        self.shader.setInt("textureSampler", 0);
        self.shader.setMat4f("projection", flattenMat4(self.projection));
        self.shader.setMat4f("view", flattenMat4(self.view));

        // Draw em all. We're sending the instance count here.
        self.drawInstanced(@intCast(drawCommands.len));
    }

    pub fn init(allocator: std.mem.Allocator, window_width: u32, window_height: u32) OpenGLBackend {
        const shaderProgram: Shader = Shader.create(
            allocator,
            "src/rendering/shaders/position_shader.vs",
            "src/rendering/shaders/triangle_shader.frag",
        );

        const geometry = QuadGeometry.init();

        const projM = zm.Mat4f.orthographicRH(
            0, 
            @floatFromInt(window_width), 
            @floatFromInt(window_height),
            0,
            -1.0,
            1.0
        );

        const view = zm.Mat4f.identity();

        // Create a 1x1 white texture as default
        var white_texture_id: c.GLuint = undefined;
        c.glGenTextures(1, &white_texture_id);
        c.glBindTexture(c.GL_TEXTURE_2D, white_texture_id);
        const white_pixel = [4]u8{ 255, 255, 255, 255 };
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, 1, 1, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &white_pixel);
        
        // Push it as the first texture (handle 0)
        var textures: [MAX_TEXTURES]GPUTexture = std.mem.zeroes([MAX_TEXTURES]GPUTexture);
        textures[0] = GPUTexture{ .id = white_texture_id, .width = 1, .height = 1 };
        const texture_count = 1;

        return OpenGLBackend{
            .shader = shaderProgram,
            .projection = projM.data,
            .allocator = allocator,
            .instanceData = .empty,
            .textures = textures,
            .geometry = geometry,
            .view = view.data,
            .texture_count = texture_count,
        };
    }

    // Note that the texture id can't be bigger than max_textures. So, we can compact it
    // into a small space in the 64 bit render key.
    pub fn loadTexture(self: *OpenGLBackend, path: []const u8) !Texture {
        if (self.texture_count >= MAX_TEXTURES) return error.TooManyTextures;
        const texture = GPUTexture.initFromFile(self.allocator, path);
        self.textures[self.texture_count] = texture;
        const texture_id = self.texture_count;
        self.texture_count += 1;
        return Texture {
            .id = texture_id,
            .width = texture.width,
            .height = texture.height,
        };
    }

    pub fn drawInstanced(self: *OpenGLBackend, instance_count: c_int) void {
        c.glBindVertexArray(self.geometry.VAO);
        c.glDrawElementsInstanced(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null, instance_count);
    }

    pub fn updateInstanceData(self: *OpenGLBackend) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.geometry.instance_VBO);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(self.instanceData.items.len * @sizeOf(InstanceData)),
            self.instanceData.items.ptr,
            c.GL_DYNAMIC_DRAW
        );
    }

    pub fn cleanup(self: *OpenGLBackend) void {
        self.instanceData.deinit(self.allocator);
        self.geometry.deinit();
        c.glDeleteProgram(self.shader.ID);
        
        var ids_to_delete: [MAX_TEXTURES]c.GLuint = undefined;
        for (self.textures[0..self.texture_count], 0..) |texture, i| {
            ids_to_delete[i] = texture.id;
        }
        c.glDeleteTextures(@intCast(self.texture_count), &ids_to_delete[0]);
    }
};
