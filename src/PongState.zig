const std = @import("std");

pub const PongState = struct {
    paddle_left_y: f32,
    paddle_right_y: f32,
    paddle_speed: f32,
    game_height: f32,
    game_width: f32,
    ball_pos: [2]f32,
    ball_vel: [2]f32,

    pub fn init(window_width: f32, window_height: f32) PongState {
        return .{
            .paddle_left_y = 250,
            .paddle_right_y = 250,
            .paddle_speed = 200,
            .game_height = window_height,
            .game_width = window_width,
            .ball_pos = .{window_width/2, window_height/2},
            .ball_vel = .{200, 200},
        };
    }

    // The number here is the paddle height. This kinda sucks that it's hard coded.
    // It is just a proof of concept though.
    pub fn moveLeftPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_left_y += direction*self.paddle_speed*dt;
        self.paddle_left_y = std.math.clamp(self.paddle_left_y, 50, self.game_height - 50);
    }

    pub fn moveRightPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_right_y += direction*self.paddle_speed*dt;
        self.paddle_right_y = std.math.clamp(self.paddle_right_y, 50, self.game_height - 50);
    }

    pub fn update(self: *PongState, dt: f32) void {
        self.ball_pos[0] += self.ball_vel[0] * dt;
        self.ball_pos[1] += self.ball_vel[1] * dt;

        if (self.ball_pos[1] <= 0 or self.ball_pos[1] >= self.game_height) {
            self.ball_vel[1] = -self.ball_vel[1];
        }

        if (self.ball_pos[0] <= 0 or self.ball_pos[0] >= self.game_width) {
            self.ball_vel[0] = -self.ball_vel[0];
        }
    }
};
