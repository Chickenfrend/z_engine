
pub const PongState = struct {
    paddle_left_y: f32,
    paddle_right_y: f32,

    pub fn init() PongState {
        return .{
            .paddle_left_y = 250,
            .paddle_right_y = 250,
        };
    }
};
