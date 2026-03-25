const std = @import("std");
const DrawCommand = @import("./Backend.zig").DrawCommand;

// Later the sort key should maybe be a struct, including the texture
// and the blend. So, we'd construct a key based on that struct.
pub const QueueEntry = struct {
    sort_key: u64,
    command: DrawCommand,
};

// Render queue here.
pub const RENDER_QUEUE_SIZE = 2048;
// This mask is for sorting the batch.
// Right now 32 bits are 0s.
// This should be changed when the key changes.
const BATCH_MASK: u64 = 0xFFFFFFFF00000000;
pub const RenderQueue = struct {
    items: [RENDER_QUEUE_SIZE]QueueEntry,
    len: usize = 0,
    sorted: bool = true,
    submission_index: u32 = 0,

    pub fn init() RenderQueue {
        return RenderQueue{
            .items = undefined,
        };
    }

    // This only includes texture information right now.
    // And submission order.
    // Inspired by this: https://realtimecollisiondetection.net/blog/?p=86
    // Note that once we have this, we can sort with normal integer comparison
    // The fields we care most about should go on the left.
    // This should include blending information too.
    // And maybe z layer for transparency.
    fn makeSortKey(command: DrawCommand, submission_index: u32) u64 {
        // Note that this could really be a u16. And we could even smash it into
        // 10 bits in the key.
        // Also, the + 1 to tex here is to make room for null.
        const texture_key: u32 = if (command.material.texture) |tex| tex + 1 else 0;
        const layer_key: u16 = command.layer;
        // This bitshift means that textures come before submission keys.
        // Blending could later come before textures, so that transparent stuff
        // gets rendered last?
        // The layer probably doesn't need a whole 16 bits.
        return ( 
            @as(u64, layer_key) << 48
            | @as(u64, texture_key) << 32
            | submission_index);
    }

    pub fn push(self: *RenderQueue, command: DrawCommand) !void {
        if (self.len >= RENDER_QUEUE_SIZE) {
            return error.QueueFull;
        }

        const entry = QueueEntry{
            .sort_key = makeSortKey(command, self.submission_index),
            .command = command,
        };
        self.items[self.len] = entry;

        if (self.len > 0 and entry.sort_key < self.items[self.len - 1].sort_key) {
            self.sorted = false;
        }
        self.len += 1;
        self.submission_index += 1;
    }

    pub fn sort(self: *RenderQueue) void {
        if (self.sorted)
            return;

        std.sort.pdq(QueueEntry, self.items[0..self.len], {}, struct {
            fn lessThan(_: void, a: QueueEntry, b: QueueEntry) bool {
                return a.sort_key < b.sort_key;
            }
        }.lessThan);
        self.sorted = true;
    }

    pub fn nextBatchEnd(self: *const RenderQueue, startIndex: usize) usize {
        std.debug.assert(startIndex < self.len);
        const start_key = self.items[startIndex].sort_key & BATCH_MASK;

        for (self.items[startIndex + 1 .. self.len], startIndex + 1..self.len) |entry, i| {
            if ((entry.sort_key & BATCH_MASK) != start_key) {
                return i;
            }
        }
        return self.len;
    }

    pub fn isFull(self: *const RenderQueue) bool {
        return self.len == RENDER_QUEUE_SIZE;
    }

    pub fn isEmpty(self: *const RenderQueue) bool {
        return self.len == 0;
    }

    // This can happen in the middle of frames so preserving submission_index
    // actually matters. That shouldn't happen often... But it could.
    pub fn clear(self: *RenderQueue) void {
        self.len = 0;
        self.sorted = true;
    }

    // This should really only be called at the beginning of each frame,
    // probably. Resets the submission_index so when we eventually support transparency,
    // it'll matter that that only happens when we're done drawing.
    pub fn reset(self: *RenderQueue) void {
        self.len = 0;
        self.submission_index = 0;
        self.sorted = true;
    }
};
