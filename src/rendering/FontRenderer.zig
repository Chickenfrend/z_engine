// FontRenderer.zig - Dynamic text rendering with FreeType
const std = @import("std");
const zm = @import("zm");
const Shader = @import("ShaderLib.zig");

const builtin = @import("builtin");

const c = if (builtin.os.tag == .macos)
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("OpenGL/gl3.h");
        @cInclude("ft2build.h");
        @cInclude("freetype/freetype.h");
    })
else
    @cImport({
        @cDefine("GLFW_INCLUDE_NONE", "");
        @cDefine("GL_GLEXT_PROTOTYPES", "");
        @cInclude("GLFW/glfw3.h");
        @cInclude("GL/gl.h");
        @cInclude("GL/glext.h");
        @cInclude("ft2build.h");
        @cInclude("freetype/freetype.h");
    });

pub const Glyph = struct {
    texture_id: c.GLuint,
    width: i32,
    height: i32,
    bearing_x: i32,
    bearing_y: i32,
    advance: i32, // Advance in pixels (already divided by 64)
};

pub const FontRenderer = struct {
    library: c.FT_Library,
    face: c.FT_Face,
    glyphs: std.AutoHashMap(u8, Glyph), // Cache for ASCII glyphs
    shader: Shader,
    vao: c.GLuint,
    vbo: c.GLuint,
    projection: [4][4]f32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, font_path: []const u8, font_size: u32, projection: [4][4]f32) !FontRenderer {
        // Initialize FreeType
        var library: c.FT_Library = undefined;
        if (c.FT_Init_FreeType(&library) != 0) {
            return error.FreeTypeInitFailed;
        }

        // Load font face
        var face: c.FT_Face = undefined;
        const path_z = try allocator.dupeZ(u8, font_path);
        defer allocator.free(path_z);

        if (c.FT_New_Face(library, path_z.ptr, 0, &face) != 0) {
            _ = c.FT_Done_FreeType(library);
            return error.FontLoadFailed;
        }

        // Set font size
        _ = c.FT_Set_Pixel_Sizes(face, 0, font_size);

        // Create shader for text rendering
        const shader = Shader.create(
            allocator,
            "src/rendering/shaders/text_shader.vs",
            "src/rendering/shaders/text_shader.frag",
        );

        // Setup OpenGL state for text rendering
        var vao: c.GLuint = undefined;
        var vbo: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

        // Allocate VBO for 6 vertices (2 triangles = 1 quad) with 4 floats each (x, y, u, v)
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(f32) * 6 * 4, null, c.GL_DYNAMIC_DRAW);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 4, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), null);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        c.glBindVertexArray(0);

        var self = FontRenderer{
            .library = library,
            .face = face,
            .glyphs = std.AutoHashMap(u8, Glyph).init(allocator),
            .shader = shader,
            .vao = vao,
            .vbo = vbo,
            .projection = projection,
            .allocator = allocator,
        };

        // Pre-load ASCII characters (32-127)
        try self.loadAsciiGlyphs();

        return self;
    }

    fn loadAsciiGlyphs(self: *FontRenderer) !void {
        // Configure OpenGL for grayscale textures
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        var char: u8 = 32; // Start from space
        while (char < 128) : (char += 1) {
            if (c.FT_Load_Char(self.face, char, c.FT_LOAD_RENDER) != 0) {
                std.debug.print("Failed to load glyph for char: {c}\n", .{char});
                continue;
            }

            const bitmap = self.face.*.glyph.*.bitmap;

            // Generate texture
            var texture: c.GLuint = undefined;
            c.glGenTextures(1, &texture);
            c.glBindTexture(c.GL_TEXTURE_2D, texture);

            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0,
                c.GL_RED,
                @intCast(bitmap.width),
                @intCast(bitmap.rows),
                0,
                c.GL_RED,
                c.GL_UNSIGNED_BYTE,
                bitmap.buffer,
            );

            // Set texture options
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

            // Store glyph
            const glyph = Glyph{
                .texture_id = texture,
                .width = @intCast(bitmap.width),
                .height = @intCast(bitmap.rows),
                .bearing_x = self.face.*.glyph.*.bitmap_left,
                .bearing_y = self.face.*.glyph.*.bitmap_top,
                .advance = @intCast(@as(i64, self.face.*.glyph.*.advance.x) >> 6),
            };

            try self.glyphs.put(char, glyph);
        }

        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }

    pub fn renderText(self: *FontRenderer, text: []const u8, x: f32, y: f32, scale: f32, color: [3]f32) void {
        // Enable blending for alpha textures
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        self.shader.use();

        // Set uniforms
        const projection_flat = flattenMat4(self.projection);
        self.shader.setMat4f("projection", projection_flat);
        self.shader.setVec3f("textColor", color);

        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindVertexArray(self.vao);

        var cursor_x = x;

        for (text) |char| {
            const glyph = self.glyphs.get(char) orelse continue;

            const xpos = cursor_x + @as(f32, @floatFromInt(glyph.bearing_x)) * scale;
            const ypos = y - @as(f32, @floatFromInt(glyph.bearing_y)) * scale;

            const w = @as(f32, @floatFromInt(glyph.width)) * scale;
            const h = @as(f32, @floatFromInt(glyph.height)) * scale;

            // Update VBO for each character
            const vertices = [_]f32{
                // Position (x, y), TexCoords (u, v)
                xpos, ypos + h, 0.0, 1.0, // Bottom-left
                xpos, ypos, 0.0, 0.0, // Top-left
                xpos + w, ypos, 1.0, 0.0, // Top-right
                xpos, ypos + h, 0.0, 1.0, // Bottom-left
                xpos + w, ypos, 1.0, 0.0, // Top-right
                xpos + w, ypos + h, 1.0, 1.0, // Bottom-right
            };

            // Bind glyph texture
            c.glBindTexture(c.GL_TEXTURE_2D, glyph.texture_id);

            // Update VBO memory
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
            c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(@TypeOf(vertices)), &vertices);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

            // Render quad
            c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

            // Advance cursor (note: advance is in 1/64th pixels)
            cursor_x += @as(f32, @floatFromInt(glyph.advance)) * scale;
        }

        c.glBindVertexArray(0);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
        c.glDisable(c.GL_BLEND);
    }

    pub fn deinit(self: *FontRenderer) void {
        // Cleanup OpenGL resources
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);

        // Cleanup textures
        var iter = self.glyphs.valueIterator();
        while (iter.next()) |glyph| {
            c.glDeleteTextures(1, &glyph.texture_id);
        }
        self.glyphs.deinit();

        // Cleanup FreeType
        _ = c.FT_Done_Face(self.face);
        _ = c.FT_Done_FreeType(self.library);
    }
};

fn flattenMat4(mat: [4][4]f32) [16]f32 {
    return @as(*const [16]f32, @ptrCast(&mat)).*;
}
