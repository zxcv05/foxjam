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
    if (raylib.isKeyPressed(.escape))
        try ctx.switch_driver(&State.states.Game);
}

pub fn render(ctx: *Context) !void {
    var buffer: [64]u8 = undefined;

    raylib.clearBackground(raylib.Color.black);
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    raylib.drawText("Stats", constants.SIZE_WIDTH / 2 - @divTrunc(raylib.measureText("Stats", 48), 2), 24, 48, text_color);

    const pos_deck_text = std.fmt.bufPrintZ(buffer[0..], "Chance for positive coin: {d:.2}%", .{ctx.positive_chance * 100}) catch unreachable;
    raylib.drawText(pos_deck_text, 15, 110, 24, text_color);

    const coins_y = 150;

    const pos_coins_text = std.fmt.bufPrintZ(buffer[0..], "Positive coins: {d}", .{num_pos}) catch unreachable;
    raylib.drawText(pos_coins_text, 15, coins_y, 24, text_color);

    var pos_coin_index: i32 = 0;
    var pos_coins_iter = pos_coins.iterator();
    while (pos_coins_iter.next()) |coin| {
        if (coin.value.* == 0) continue;
        defer pos_coin_index += 1;

        const chance: f32 = @as(f32, @floatFromInt(coin.value.*)) / @as(f32, @floatFromInt(num_pos)) * 100;
        const text = std.fmt.bufPrintZ(buffer[0..], "- {s}: {d} ({d:.2}%)", .{ @tagName(coin.key), coin.value.*, chance }) catch unreachable;
        raylib.drawText(text, 15, coins_y + pos_coin_index * 20 + 30, 20, text_color);
    }

    const spacing: i32 = pos_coin_index * 20 + 50;
    const neg_coins_text = std.fmt.bufPrintZ(buffer[0..], "Negative coins: {d}", .{num_neg}) catch unreachable;
    raylib.drawText(neg_coins_text, 15, spacing + coins_y, 24, text_color);

    var neg_coin_index: i32 = 0;
    var neg_coins_iter = neg_coins.iterator();
    while (neg_coins_iter.next()) |coin| {
        if (coin.value.* == 0) continue;
        defer neg_coin_index += 1;

        const chance: f32 = @as(f32, @floatFromInt(coin.value.*)) / @as(f32, @floatFromInt(num_pos)) * 100;
        const text = std.fmt.bufPrintZ(buffer[0..], "- {s}: {d} ({d:.2}%)", .{ @tagName(coin.key), coin.value.*, chance }) catch unreachable;
        raylib.drawText(text, 15, spacing + coins_y + neg_coin_index * 20 + 30, 20, text_color);
    }
}
