const std = @import("std");
const raylib = @import("raylib");

const Context = @import("Context.zig");
const constants = @import("constants.zig");

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
    new_unlock: ?Trophy.Tag = null,
    new_unlock_ts: i64 = 0,

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

pub inline fn get_stand_description_for(fox: Trophy.Tag) [*:0]const u8 {
    return switch (fox) {
        .@"8bit" => "8-bit fox\n- Flipped a couple coins",
        .arctic => "Arctic fox\n- The house always wins",
        .bat => "Bat-Eared fox\n- That's a lot of negative coins",
        .black => "Black fox\n- This can't be a livable wage...",
        .corsac => "Corsac fox\n- That's a lot coins",
        .dog => "Dog\n- 777",
        .fennec => "Fennec fox\n- All those effects must be boosting my hearing",
        .fire => "Firefox\n- Absolutely legendary",
        .golden => "Golden fox\n- You're a cutie <3",
        .kitsune => "Kitsune\n- I just like having options",
        .news => "Fox News\n- Oof unlucky",
        .real => "Realistic fox\n- Flipped a lot of coins",
        .red => "Red fox\n- Thanks for playing :)",
        .robin => "Robin Hood fox\n- Positivity is the core of a good life",
        .sand => "Sand Tibetan fox\n- Filthy rich",
        .umbryan => "Umbryan fox\n- You can't click that",
        .unfinished => "Unfinished fox\n- Wait, seriously? That's it?",
    };
}

pub inline fn unlock_if(ctx: *Context, comptime fox: Trophy.Tag, cond: bool) void {
    if (cond and !is_unlocked(ctx, fox)) unlock(ctx, fox);
}

pub inline fn is_unlocked(ctx: *Context, comptime fox: Trophy.Tag) bool {
    return ctx.trophy_case.displays.getAssertContains(fox);
}

pub fn unlock(ctx: *Context, comptime fox: Trophy.Tag) void {
    ctx.trophy_case.displays.put(fox, true);

    ctx.trophy_case.new_unlock = fox;
    ctx.trophy_case.new_unlock_ts = std.time.milliTimestamp() + constants.trophy_unlock_display_time;
}
