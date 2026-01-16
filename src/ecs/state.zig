const std = @import("std");
const Allocator = std.mem.Allocator;

const MAX_ENTITIES = 5_000;
const MAX_COMPONENTS = 50_000;

const RectangleEntity = struct {
    position_idx: u64,
};

const PositionComponent = struct {
    x: f64,
    y: f64,
};

pub const GlobalState = struct {
    clock: std.time.Timer,
    game_state: GameState,
};

pub const GameState = struct {
    rectangles: []RectangleEntity,

    positions: []PositionComponent,

    pub fn init(allo: Allocator) !GameState {
        return .{
            .rectangles = try allo.alloc(RectangleEntity, MAX_ENTITIES),
            .positions = try allo.alloc(PositionComponent, MAX_COMPONENTS),
        };
    }
};
