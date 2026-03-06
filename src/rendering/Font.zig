const std = @import("std");

pub const c = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
    @cInclude("GL/gl.h");
});

pub const Glyph = struct {
    texture_id: u32,
    width: i32,
    height: i32,
    bearing_x: i32,
    bearing_y: i32,
    advance: i32,
};

pub const Font = struct {
    face: c.FT_Face,
    glyphs: [128]Glyph,
    loaded: bool = false,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !*Font {
        var library: c.FT_Library = null;
        if (c.FT_Init_FreeType(&library) != 0)
            return error.FreeTypeInitFailed;

        var face: c.FT_Face = null;
        if (c.FT_New_Face(library, path.ptr, 0, &face) != 0)
            return error.FontLoadFailed;

        _ = c.FT_Set_Pixel_Sizes(face, 0, 48);

        var self = try allocator.create(Font);
        self.face = face;

        for (0..128) |i| {
            if (c.FT_Load_Char(face, @intCast(i), c.FT_LOAD_RENDER) != 0)
                continue;

            const bitmap = face.*.glyph.*.bitmap;
            var tex: u32 = 0;
            c.glGenTextures(1, &tex);
            c.glBindTexture(c.GL_TEXTURE_2D, tex);
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

            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

            self.glyphs[i] = Glyph{
                .texture_id = tex,
                .width = @intCast(bitmap.width),
                .height = @intCast(bitmap.rows),
                .bearing_x = face.*.glyph.*.bitmap_left,
                .bearing_y = face.*.glyph.*.bitmap_top,
                .advance = @as(i32, @intCast(face.*.glyph.*.advance.x)) >> 6,
            };
        }

        c.glBindTexture(c.GL_TEXTURE_2D, 0);
        self.loaded = true;
        return self;
    }
};
