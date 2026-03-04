const std = @import("std");

pub const PongState = struct {
    paddle_left_y: f32,
    paddle_right_y: f32,
    paddle_speed: f32,
    game_height: f32,
    game_width: f32,

    pub fn init(window_width: f32, window_height: f32) PongState {
        return .{
            .paddle_left_y = 250,
            .paddle_right_y = 250,
            .paddle_speed = 200,
            .game_height = window_height,
            .game_width = window_width,
        };
    }

    // The number here is the paddle height. This kinda sucks that it's hard coded.
    // It is just a proof of concept though.
    pub fn moveLeftPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_left_y += direction*self.paddle_speed*dt;
        self.paddle_left_y = std.math.clamp(self.paddle_left_y, 50, self.game_height - 250);
    }

    pub fn moveRightPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_right_y += direction*self.paddle_speed*dt;
        self.paddle_right_y = std.math.clamp(self.paddle_right_y, 50, self.game_height - 250);
    }
};
