const std = @import("std");
const raylib = @import("raylib");

const Context = @import("Context.zig");

/// All trophies will have an effect associated with them, thats TODO
pub const Trophy = union(enum) {
    pub const Tag = @typeInfo(Trophy).@"union".tag_type.?;

    @"8bit": void,
    arctic: void,
    bat: void,
    black: void,
    corsac: void,
    dog: void,
    fennec: void,
    fire: void,
    golden: void,
    kitsune: void,
    news: void,
    real: void,
    red: void,
    robin: void,
    sand: void,
    umbryan: void,
    unfinished: void,
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

pub inline fn get_texture_for(ctx: *const Context, comptime fox: Trophy.Tag) raylib.Texture2D {
    return @field(ctx.assets, "fox_" ++ @tagName(fox));
}

pub inline fn get_description_for(fox: Trophy.Tag) [*:0]const u8 {
    return switch (fox) {
        .@"8bit" => "Who turned down the quality?",
        .arctic => "Cold their heart like\nthe snow that surrounds them.",
        .bat => "It can't actually fly, unfortunately...",
        .black => "Shape of a wolf, color of a cat...\nYet it is neither.",
        .corsac => "Fox? Dog..? What are you??",
        .dog => "How did you get here?",
        .fennec => "Have a problem? This little guy is all ears!",
        .fire => "Likes to sleep on the web.",
        .golden => "The rarest fox of them all!\nThank you for playing <3",
        .kitsune => "The queen of ghost foxes!",
        .news => "What do you mean it's not about foxes?!",
        .real => "Who turned up the quality?",
        .red => "Just your average wild fox.",
        .robin => "Steals from the rich, gives to the poor.",
        .sand => "No, it's not actually made of sand.",
        .umbryan => "Legally distinct for copyright reasons.",
        .unfinished => "The artist didn't finish this one... Oh well.",
    };
}
