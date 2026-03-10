const std = @import("std");

const BALL_START_VEL = 200;
const BALL_ACCELERATION = 1.2;

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
    rng: std.Random.DefaultPrng,

    pub fn init(window_width: f32, window_height: f32) PongState {
        const seed: u64 = @bitCast(std.time.milliTimestamp());
        var prng = std.Random.DefaultPrng.init(seed);
        const vel = getDirectionFromRng(prng.random());
        return .{
            .paddle_left_y = 250,
            .paddle_right_y = 250,
            .paddle_speed = 200,
            .game_height = window_height,
            .game_width = window_width,
            .ball_pos = .{ window_width / 2, window_height / 2 },
            .ball_vel = vel,
            .left_score = 0,
            .right_score = 0,
            .ball_size = 15,
            .paddle_height = 100,
            .rng = prng,
        };
    }

    fn getDirectionFromRng(rng: std.Random) [2]f32 {
        const magnitude: f32 = @as(f32, BALL_START_VEL) * std.math.sqrt(@as(f32, 2.0));
        const angle = rng.float(f32) * 2.0 * std.math.pi;
        return .{
            magnitude * std.math.cos(angle),
            magnitude * std.math.sin(angle),
        };
    }

    fn getDirection(self: *PongState) [2]f32 {
        return getDirectionFromRng(self.rng.random());
    }

    // The number here is the paddle height. This kinda sucks that it's hard coded.
    // It is just a proof of concept though.
    pub fn moveLeftPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_left_y += direction * self.paddle_speed * dt;
        self.paddle_left_y = std.math.clamp(self.paddle_left_y, 0, self.game_height - self.paddle_height);
    }

    pub fn moveRightPaddle(self: *PongState, direction: f32, dt: f32) void {
        self.paddle_right_y += direction * self.paddle_speed * dt;
        self.paddle_right_y = std.math.clamp(self.paddle_right_y, 0, self.game_height - self.paddle_height);
    }

    pub fn update(self: *PongState, dt: f32) void {
        self.ball_pos[0] += self.ball_vel[0] * dt;
        self.ball_pos[1] += self.ball_vel[1] * dt;

        if (self.ball_pos[1] <= 0 or self.ball_pos[1] >= self.game_height) {
            self.ball_vel[1] = -self.ball_vel[1] * BALL_ACCELERATION;
        }

        if (self.ball_pos[0] <= 0 or self.ball_pos[0] >= self.game_width) {
            self.ball_vel[0] = -self.ball_vel[0] * BALL_ACCELERATION;
        }

        checkPaddleCollision(self);
        checkWallCollision(self);
    }

    fn checkPaddleCollision(self: *PongState) void {
        const paddle_width: f32 = 20;

        // Left paddle
        if (self.ball_pos[0] <= 20 + paddle_width and
            self.ball_pos[1] + self.ball_size >= self.paddle_left_y and
            self.ball_pos[1] <= self.paddle_left_y + self.paddle_height)
        {
            self.ball_vel[0] = @abs(self.ball_vel[0]) * BALL_ACCELERATION;
            self.ball_pos[0] = 20 + paddle_width; // clamp out of paddle
        }

        // Right paddle
        if (self.ball_pos[0] + self.ball_size >= self.game_width - 40 and
            self.ball_pos[1] + self.ball_size >= self.paddle_right_y and
            self.ball_pos[1] <= self.paddle_right_y + self.paddle_height)
        {
            self.ball_vel[0] = -@abs(self.ball_vel[0]) * BALL_ACCELERATION;
            self.ball_pos[0] = self.game_width - 40 - self.ball_size; // clamp out of paddle
        }
    }

    fn checkWallCollision(self: *PongState) void {
        if (self.ball_pos[0] < 0) {
            self.ball_pos = .{ self.game_width / 2, self.game_height / 2 };
            self.left_score += 1;
            self.ball_vel = self.getDirection();
        }
        if (self.ball_pos[0] > self.game_width) {
            self.ball_pos = .{ self.game_width / 2, self.game_height / 2 };
            self.right_score += 1;
            self.ball_vel = self.getDirection();
        }
    }
};
