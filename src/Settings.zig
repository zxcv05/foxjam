const std = @import("std");

const Settings = @This();

audio_muted: bool = false,

pub fn serialize(this: *const Settings, writer: std.io.AnyWriter) !void {
    try writer.writeInt(u8, @intFromBool(this.audio_muted), .big);
}

pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !Settings {
    _ = alloc;

    const audio_muted = try reader.readInt(u8, .big) > 0;

    return .{
        .audio_muted = audio_muted,
    };
}
