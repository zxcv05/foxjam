const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const constants = @import("../constants.zig");
const Context = @import("../Context.zig");
const types = @import("../types.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

pub fn init(ctx: *Context) !void {
    ctx.coin_deck = try .init(
        constants.initial_coins,
        @truncate(@abs(std.time.nanoTimestamp())),
        ctx.allocator,
    );
    errdefer ctx.coin_deck.deinit(ctx.allocator);

    try ctx.coin_deck.positive_deck.append(ctx.allocator, .{ .additive_win = 10_00 });
    try ctx.coin_deck.negative_deck.append(ctx.allocator, .{ .next_multiplier = 2 });
}

pub fn deinit(ctx: *Context) void {
    ctx.effects.deinit(ctx.allocator);
    ctx.coin_deck.deinit(ctx.allocator);
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
}

pub fn update(ctx: *Context) !void {
    if (raylib.isKeyPressed(.escape)) {
        try ctx.switch_driver(&State.states.PauseMenu);
    }

    _ = raygui.guiSliderBar(.{
        .x = @floatFromInt(constants.SIZE_WIDTH / 3),
        .width = @floatFromInt(constants.SIZE_WIDTH / 3),
        .y = 64,
        .height = 64,
    }, "", "", &ctx.bet_precentage, 0.0, 1.0);

    const should_flip = raygui.guiButton(.{
        .x = @floatFromInt(constants.SIZE_WIDTH / 3),
        .width = @floatFromInt(constants.SIZE_WIDTH / 3),
        .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64),
        .height = 64,
    }, "") != 0 or raylib.isKeyPressed(.space);

    if (should_flip) {
        const bet_amount: @TypeOf(ctx.money) = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_precentage));

        const coin = ctx.coin_deck.flip(0.5);
        defer ctx.last_coin = coin;

        // zig fmt: off
        switch (coin) { // TODO: add new effects that get applied once flipping
            .win             => ctx.money += bet_amount * ctx.effects.multiplier,
            .loss            => ctx.money -= bet_amount,
            .additive_win    => |val| ctx.money += val * ctx.effects.multiplier,
            .next_multiplier => try ctx.effects.addEffect(.{
                .coin     = coin,
                .duration = 2,
            }, ctx.allocator),
        }
        // zig fmt: on

        ctx.effects.update(ctx.allocator);
    }
}

pub fn render(ctx: *Context) !void {
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));
    var text_buffer: [256]u8 = undefined;

    { // draw results of last coin flip
        // zig fmt: off
        const coin_text: [:0]const u8 = switch (ctx.last_coin) { // TODO: add new effects that get shown once flipping
            .win             => "heads\x00",
            .loss            => "tails\x00",
            .additive_win    => |val| std.fmt.bufPrintZ(text_buffer[0..], "+ ${d}.{d:02}", .{val / 100, val % 100}) catch unreachable,
            .next_multiplier => |val| std.fmt.bufPrintZ(text_buffer[0..], "next two x{d}", .{val}) catch unreachable,
        };
        // zig fmt: on
        const coin_text_width = raylib.measureText(coin_text.ptr, 32);
        std.debug.assert(coin_text_width >= 0);
        raylib.drawText(coin_text.ptr, constants.SIZE_WIDTH / 2 - @divTrunc(coin_text_width, 2), constants.SIZE_HEIGHT - 12 - 46, 32, text_color);
    }

    { // draw current balance
        const balance_text = std.fmt.bufPrintZ(text_buffer[0..], "${d}.{d:02}", .{ ctx.money / 100, ctx.money % 100 }) catch unreachable;
        const balance_text_width = raylib.measureText(balance_text.ptr, 32);
        std.debug.assert(balance_text_width >= 0);
        raylib.drawText(balance_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(balance_text_width, 2), 16, 32, text_color);
    }

    { // draw bet amount and slider
        const bet_amount: u64 = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_precentage));
        const bet_amount_text = std.fmt.bufPrintZ(text_buffer[0..], "Betting: ${d}.{d:02}", .{ bet_amount / 100, bet_amount % 100 }) catch unreachable;
        const bet_amount_text_width = raylib.measureText(bet_amount_text.ptr, 32);
        std.debug.assert(bet_amount_text_width >= 0);
        raylib.drawText(bet_amount_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(bet_amount_text_width, 2), 82, 32, raylib.Color.black);
    }

    var effect_y: usize = 0;
    var maybe_effect = ctx.effects.effects.first;
    while (maybe_effect) |node| : (maybe_effect = node.next) {
        defer effect_y += 14;

        const effect_text = switch (node.data.coin) {
            .next_multiplier => |val| std.fmt.bufPrintZ(text_buffer[0..], "{d}x multiplier", .{val}) catch unreachable,
            .additive_win => |val| std.fmt.bufPrintZ(text_buffer[0..], "+{d} money", .{val}) catch unreachable,
            else => unreachable,
        };

        raylib.drawText(effect_text, 2, @intCast(2 + effect_y), 2, text_color);
    }
}
