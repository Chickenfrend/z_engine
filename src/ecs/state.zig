const std = @import("std");
const Allocator = std.mem.Allocator;


const MAX_ENTITIES = 5_000;
const MAX_COMPONENTS = 50_000;

const RectangleEntity = struct  {
    pub var position_idx: u64;
};

const PositionComponent = struct {
    pub var x: f64;
    pub var y: f64;
}

const State = struct {
    pub var rectangles: [*]RectangleEntity;

    pub var positions: [*]PositionComponent;

    pub fn init(allo: Allocator) State {
        return State{
            .rectangles = try allo.alloc(RectangleEntity, MAX_ENTITIES),
            .positions = try allo.alloc(PositionComponent, MAX_COMPONENTS),
        }
    }
}
