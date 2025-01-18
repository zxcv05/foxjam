const std = @import("std");
const raylib = @import("raylib");

pub const Animation = @This();

frames: usize,
frame_index: usize,
next_frame_deadline: i64,
mspf: f64,

pub fn init(frames: usize, fps: f64) Animation {
    return .{
        .frames = frames,
        .mspf = 1_000 / fps,

        .frame_index = 0,
        .next_frame_deadline = 0,
    };
}

pub fn start(this: *Animation) void {
    this.frame_index = 0;

    const ts: f64 = @floatFromInt(std.time.milliTimestamp());
    this.next_frame_deadline = @intFromFloat(ts + this.mspf);
}

pub fn update(this: *Animation) void {
    if (std.time.milliTimestamp() > this.next_frame_deadline) {
        this.frame_index = (this.frame_index + 1) % this.frames;

        const ts: f64 = @floatFromInt(std.time.milliTimestamp());
        this.next_frame_deadline = @intFromFloat(ts + this.mspf);
    }
}
