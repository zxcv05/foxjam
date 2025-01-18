const std = @import("std");
const raylib = @import("raylib");

pub const Animation = @This();

frames: usize,
next_frame_deadline: i64 = 0,
last_frame_index: usize = 0,
frames_played: usize = 0,
frame_index: usize = 0,
mspf: f64,

pub fn init(frames: usize, fps: f64) Animation {
    return .{
        .frames = frames,
        .mspf = 1_000 / fps,
    };
}

pub fn start(this: *Animation) void {
    this.frame_index = 0;
    this.last_frame_index = 0;
    this.frames_played = 0;

    const ts: f64 = @floatFromInt(std.time.milliTimestamp());
    this.next_frame_deadline = @intFromFloat(ts + this.mspf);
}

pub fn update(this: *Animation) void {
    if (std.time.milliTimestamp() > this.next_frame_deadline) {
        this.frame_index = (this.frame_index + 1) % this.frames;
        defer this.last_frame_index = this.frame_index;

        if (this.frame_index != this.last_frame_index)
            this.frames_played += 1;

        const ts: f64 = @floatFromInt(std.time.milliTimestamp());
        this.next_frame_deadline = @intFromFloat(ts + this.mspf);
    }
}
