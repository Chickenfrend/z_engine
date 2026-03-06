const std = @import("std");

pub const PongState = struct {
    paddle_left_y: f32,
    paddle_right_y: f32,
    paddle_speed: f32,
    game_height: f32,
    game_width: f32,
    ball_pos: [2]f32,
    ball_vel: [2]f32,
    left_score: f32,
    right_score: f32,
    ball_size: f32,
    paddle_height: f32,

    pub fn init(window_width: f32, window_height: f32) PongState {
        return .{
            .paddle_left_y = 250,
            .paddle_right_y = 250,
            .paddle_speed = 200,
            .game_height = window_height,
            .game_width = window_width,
            .ball_pos = .{window_width/2, window_height/2},
            .ball_vel = .{200, 200},
            .left_score = 0,
            .right_score = 0,
            .ball_size = 15,
            .paddle_height = 100,
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

        checkPaddleCollision(self);
        checkWallCollision(self);
    }

    fn checkPaddleCollision(self: *PongState) void {
        const paddle_width: f32 = 20;

        // Left paddle
        if (self.ball_pos[0] <= 20 + paddle_width and
            self.ball_vel[0] < 0 and
            self.ball_pos[1] + self.ball_size >= self.paddle_left_y - self.paddle_height/2 and
            self.ball_pos[1] <= self.paddle_left_y + self.paddle_height/2)
        {
            self.ball_vel[0] = @abs(self.ball_vel[0]);
            self.ball_pos[0] = 20 + paddle_width; // clamp out of paddle
        }

        // Right paddle
        if (self.ball_pos[0] + self.ball_size >= self.game_width - 20 and
            self.ball_pos[1] + self.ball_size >= self.paddle_right_y - self.paddle_height/2 and
            self.ball_pos[1] <= self.paddle_right_y + self.paddle_height/2)
        {
            self.ball_vel[0] = -@abs(self.ball_vel[0]);
            self.ball_pos[0] = self.game_width - 20 - self.ball_size; // clamp out of paddle
        }
    }

    fn checkWallCollision(self: *PongState) void {
        if (self.ball_pos[0] < 0) {
            self.ball_pos = .{self.game_width/2, self.game_height/2};
            self.left_score += 1;
        }
        if (self.ball_pos[0] > self.game_width) {
            self.ball_pos = .{self.game_width/2, self.game_height/2};
            self.right_score += 1;
        }
    }
};
