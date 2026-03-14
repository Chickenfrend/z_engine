const zm = @import("zm");

pub const Camera2D = struct {
    position: [2]f32 = .{0.0, 0.0},
    zoom: f32 = 1.0,
    rotation: f32 = 0.0,

    pub fn getViewMatrix(self: Camera2D) [4][4]f32 {
            // Translate by negative camera position (moving camera right = world moves left),
        // then scale by zoom
        const translate = zm.Mat4f.translation(-self.position[0], -self.position[1], 0.0);
        const scale = zm.Mat4f.scaling(self.zoom, self.zoom, 1.0);
        return scale.multiply(translate).data;
    }

};

