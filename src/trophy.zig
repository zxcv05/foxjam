const std = @import("std");
const raylib = @import("raylib");

const Context = @import("Context.zig");

/// All trophies will have an effect associated with them, thats TODO
pub const Trophy = union(enum) {
    pub const Tag = @typeInfo(Trophy).@"union".tag_type.?;

    orange: void,
    white: void,
    black: void,
    bat: void,
    fennec: void,
    tibetan: void,
    corsac: void,
    robin: void,
    fire: void,
    @"8bit": void,
};

pub const Case = struct {
    displays: std.EnumMap(Trophy.Tag, bool) = .initFull(false),

    const packed_display = packed struct(u8) {
        enabled: u1,
        tag: u7,
    };

    pub fn serialize(this: *const Case, writer: std.io.AnyWriter) !void {
        try writer.writeInt(usize, @typeInfo(Trophy.Tag).@"enum".fields.len, .big);

        // lol
        var iter = @constCast(&this.displays).iterator();
        while (iter.next()) |kv| {
            const display = packed_display{
                .enabled = @intFromBool(kv.value.*),
                .tag = @intFromEnum(kv.key),
            };

            try writer.writeInt(u8, @bitCast(display), .big);
        }
    }

    pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !Case {
        _ = alloc;

        const sanity = try reader.readInt(usize, .big);
        if (sanity != @typeInfo(Trophy.Tag).@"enum".fields.len) return error.InvalidSave;

        var base: Case = .{};

        for (0..sanity) |_| {
            const display: packed_display = @bitCast(try reader.readInt(u8, .big));
            base.displays.put(@enumFromInt(display.tag), display.enabled == 1);
        }

        return base;
    }
};

pub inline fn get_texture_for(ctx: *const Context, fox: Trophy.Tag) raylib.Texture2D {
    return @field(ctx.assets, "fox_" ++ @tagName(fox));

    // return switch (fox) {
    //     // zig fmt: off
    //     .orange  => ctx.assets.fox_orange,
    //     .white   => ctx.assets.fox_white,
    //     .black   => ctx.assets.fox_black,
    //     .bat     => ctx.assets.fox_bat,
    //     .fennec  => ctx.assets.fox_fennec,
    //     .tibetan => ctx.assets.fox_tibetan,
    //     .corsac  => ctx.assets.fox_corsac,
    //     .robin   => ctx.assets.fox_robin,
    //     .fire    => ctx.assets.fox_fire,
    //     .@"8bit" => ctx.assets.fox_8bit,
    //     // .orange => ctx.assets.fox_orange,
    //     // .orange => ctx.assets.fox_orange,
    //     // .orange => ctx.assets.fox_orange,
    //     // .orange => ctx.assets.fox_orange,
    //     // .orange => ctx.assets.fox_orange,
    //     // .orange => ctx.assets.fox_orange,
    //     // zig fmt: on
    // };
}
