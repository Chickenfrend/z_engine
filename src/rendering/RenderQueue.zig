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
const BATCH_MASK: u64 = 0xFFFFFFFFFFFF0000;
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

    // This includes the render_class, which is whether it's alpha blended, masked,
    // or solid, as well as the texture and submission index, layer and order.
    // Inspired by this: https://realtimecollisiondetection.net/blog/?p=86
    // This key means we can later sort by simple integer comparison.
    // The fields we care most about should go on the left.
    // This should include blending information too.
    // And maybe z layer for transparency.
    fn makeSortKey(command: DrawCommand, submission_index: u32) u64 {
        // Note that this could really be a u16. And we could even smash it into
        // 10 bits in the key.
        // Also, the + 1 to tex here is to make room for null, which is 0.
        const texture_key: u32 = if (command.material.texture) |tex| tex + 1 else 0;

        // Make sure the submission index and texture_key match the requirements.
        // This requirement should be documented somewhere.
        std.debug.assert(submission_index <= std.math.maxInt(u16));
        std.debug.assert(texture_key <= std.math.maxInt(u16));

        const packed_submission: u16 = @intCast(submission_index);
        const layer_key: u16 = command.layer;

        // We don't sort alpha blended stuff by texture.
        // This is inneficient for batching and could be fixed later.
        const packed_texture_key: u16 = switch (command.material.render_class) {
            .solid, .masked => @intCast(texture_key),
            .alpha_blended => 0,
        };

        // Bit shifting to fit the various things in the key.
        // Some or all of these could fit in fewer bits than they currently do.
        return (@as(u64, layer_key) << 48)
        | (@as(u64, command.order) << 32)
        | (@as(u64, packed_texture_key) << 16)
        | packed_submission;
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

    // This should be optimized later. Right now the approach is that 
    // transparent stuff is never batched. That's not optimal, for obvious reasons.
    pub fn nextBatchEnd(self: *const RenderQueue, startIndex: usize) usize {
        if (self.items[startIndex].command.material.render_class == .alpha_blended ) {
            return startIndex + 1;
        }

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
