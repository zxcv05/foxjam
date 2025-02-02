const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const Context = @import("../Context.zig");
const constants = @import("../constants.zig");
const types = @import("../types.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

var just_entered: bool = false;

var pos_chance: f32 = 0.0;
var neg_chance: f32 = 0.0;

var num_pos: usize = 0;
var num_neg: usize = 0;

var pos_coins = std.EnumMap(types.Coin.Tag, usize).initFull(0);
var neg_coins = std.EnumMap(types.Coin.Tag, usize).initFull(0);

pub fn init(ctx: *Context) !void {
    _ = ctx;
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
}

pub fn enter(ctx: *Context) !void {
    for (ctx.coin_deck.positive_deck.items) |coin| {
        num_pos += 1;
        pos_coins.getPtrAssertContains(coin).* += 1;
    }

    for (ctx.coin_deck.negative_deck.items) |coin| {
        num_neg += 1;
        neg_coins.getPtrAssertContains(coin).* += 1;
    }

    pos_chance = ctx.positive_chance() * 100;
    neg_chance = 100.0 - pos_chance;

    just_entered = true;
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;

    num_pos = 0;
    num_neg = 0;

    inline for (@typeInfo(types.Coin.Tag).@"enum".fields) |field| {
        const coin: types.Coin.Tag = @enumFromInt(field.value);

        pos_coins.put(coin, 0);
        neg_coins.put(coin, 0);
    }
}

pub fn update(ctx: *Context) !void {
    const go_back =
        raygui.guiButton(.{
        .x = constants.SIZE_WIDTH - 12 - 32,
        .width = 32,
        .y = 12,
        .height = 32,
    }, "#118#") != 0 or raylib.isKeyPressed(.escape) or (raylib.isKeyPressed(.i) and !just_entered);
    if (go_back)
        try ctx.switch_driver(&State.states.Game);

    just_entered = false;
}

pub fn render(ctx: *Context) !void {
    var buffer: [64]u8 = undefined;

    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    raylib.drawText("Deck", constants.SIZE_WIDTH / 2 - @divTrunc(raylib.measureText("Deck", 48), 2), 24, 48, text_color);

    const flips_text = std.fmt.bufPrintZ(buffer[0..], "Flips: {d}", .{ctx.coin_deck.flips}) catch unreachable;
    raylib.drawText(flips_text, 25, 100, 24, text_color);

    const coins_y = 150;

    const pos_coins_text = std.fmt.bufPrintZ(buffer[0..], "Heads: {d} ({d:02.2}%)", .{ num_pos, pos_chance }) catch unreachable;
    raylib.drawText(pos_coins_text, 25, coins_y, 24, text_color);

    var pos_coin_index: i32 = 0;
    var pos_coins_iter = pos_coins.iterator();
    while (pos_coins_iter.next()) |coin| {
        if (coin.value.* == 0) continue;
        defer pos_coin_index += 1;

        const chance: f32 = @as(f32, @floatFromInt(coin.value.*)) / @as(f32, @floatFromInt(num_pos)) * 100;
        const text = std.fmt.bufPrintZ(buffer[0..], "- {s}: {d} ({d:.2}%)", .{ @tagName(coin.key), coin.value.*, chance }) catch unreachable;
        raylib.drawText(text, 25, coins_y + pos_coin_index * 20 + 30, 20, text_color);
    }

    const spacing: i32 = pos_coin_index * 20 + 50;
    const neg_coins_text = std.fmt.bufPrintZ(buffer[0..], "Tails: {d} ({d:02.2}%)", .{ num_neg, neg_chance }) catch unreachable;
    raylib.drawText(neg_coins_text, 25, spacing + coins_y, 24, text_color);

    var neg_coin_index: i32 = 0;
    var neg_coins_iter = neg_coins.iterator();
    while (neg_coins_iter.next()) |coin| {
        if (coin.value.* == 0) continue;
        defer neg_coin_index += 1;

        const chance: f32 = @as(f32, @floatFromInt(coin.value.*)) / @as(f32, @floatFromInt(num_neg)) * 100;
        const text = std.fmt.bufPrintZ(buffer[0..], "- {s}: {d} ({d:.2}%)", .{ @tagName(coin.key), coin.value.*, chance }) catch unreachable;
        raylib.drawText(text, 25, spacing + coins_y + neg_coin_index * 20 + 30, 20, text_color);
    }
}
