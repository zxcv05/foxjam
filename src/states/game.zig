// zig fmt: off
const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const Animation = @import("../Animation.zig");
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

var shop_items: [constants.max_shop_items]types.ShopItem = undefined;
var shop_refreshes: u16 = 0;

var show_coin: bool = false;
var coin_anim: Animation = .init(8, 8.0);

pub fn init(ctx: *Context) !void {
    ctx.coin_deck = try .init(
        constants.initial_coins,
        @truncate(@abs(std.time.nanoTimestamp())),
        ctx.allocator
    );
    errdefer ctx.coin_deck.deinit(ctx.allocator);
    //refresh_shop();

    try ctx.coin_deck.positive_deck.append(ctx.allocator, .{ .next_multiplier = 3});
    try ctx.coin_deck.positive_deck.append(ctx.allocator, .{ .next_value_multiplier = 3});
    try ctx.coin_deck.positive_deck.append(ctx.allocator, .{ .next_duration_multiplier = 3 });
    try ctx.coin_deck.negative_deck.append(ctx.allocator, .{ .weighted_coin = 0.25 });
    try ctx.coin_deck.negative_deck.append(ctx.allocator, .{ .lesser_loss = 0.75 });
}

pub fn deinit(ctx: *Context) void {
    ctx.effects.deinit(ctx.allocator);
    ctx.coin_deck.deinit(ctx.allocator);
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Entered Game state\n", .{});
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Left Game state\n", .{});
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

    const should_flip =
        raygui.guiButton(.{
            .x = 12,
            .width = @floatFromInt(constants.SIZE_WIDTH - 24),
            .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64),
            .height = 64,
        }, "") != 0 or
        raylib.isKeyPressed(.space);

    if (should_flip) {
        const bet_amount: @TypeOf(ctx.money) = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_precentage));

        coin_anim.frames_played = 0;
        show_coin = true;

        ctx.last_coin = ctx.coin_deck.flip(
            ctx.effects.coin_weight / 2.0 +
            std.math.lerp(1.0, 0.5, std.math.clamp(@as(f32, @floatFromInt(ctx.coin_deck.flips)) / 8.0, 0.0, 1.0))
        ); // rigged >:3

        switch (ctx.last_coin) { // TODO: add new effects here
            .win             => ctx.money += bet_amount * ctx.effects.multiplier,
            .loss            => ctx.money -= bet_amount,
            .additive_win    => |val| ctx.money += val * ctx.effects.multiplier,
            .next_multiplier => |val| try ctx.effects.addEffect(.{
                .coin     = .{ .next_multiplier = val * ctx.effects.value_multiplier},
                .duration = 2 * ctx.effects.duration_multiplier,
            }, ctx.allocator),
            .next_value_multiplier => |val| try ctx.effects.addEffect(.{
                .coin     = .{ .next_value_multiplier = val },
                .duration = 3 * ctx.effects.duration_multiplier,
            }, ctx.allocator),
            .next_duration_multiplier => |val| try ctx.effects.addEffect(.{
                .coin     = .{ .next_duration_multiplier = val * @as(u32, @intCast(ctx.effects.value_multiplier)) },
                .duration = 2,
            }, ctx.allocator),
            .lesser_loss   => |val| ctx.money -= @intFromFloat(@as(f32, @floatFromInt(bet_amount)) * val),
            .weighted_coin => |val| try ctx.effects.addEffect(.{
                .coin     = .{ .weighted_coin = val * @as(f32, @floatFromInt(ctx.effects.value_multiplier)) },
                .duration = 3 * ctx.effects.duration_multiplier,
            }, ctx.allocator),
        }

        ctx.effects.update(ctx.allocator);
    }

    if (show_coin) {
        defer coin_anim.update();
        if (coin_anim.frames_played >= 16) show_coin = false;
    }
}

pub fn render(ctx: *Context) !void {
    var text_buffer: [256]u8 = undefined;
    { // draw results of last coin flip
        // zig fmt: off
        const coin_text: [:0]const u8 = switch (ctx.last_coin) { // TODO: add new effects here
            .win                      => "heads",
            .loss                     => "tails",
            .additive_win             => |val| std.fmt.bufPrintZ(&text_buffer, "+ ${d}.{d:02}", .{val / 100, val % 100}) catch unreachable,
            .next_multiplier          => |val| std.fmt.bufPrintZ(&text_buffer, "next {d}: x{d}", .{2 * ctx.effects.duration_multiplier, val * ctx.effects.value_multiplier}) catch unreachable,
            .next_value_multiplier    => |val| std.fmt.bufPrintZ(&text_buffer, "next {d}: effects x{d}", .{3 * ctx.effects.duration_multiplier, val}) catch unreachable,
            .next_duration_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "next 2: duration x{d}", .{val * @as(u32, @intCast(ctx.effects.value_multiplier))}) catch unreachable,
            .lesser_loss              => |val| std.fmt.bufPrintZ(&text_buffer, "{d}% tails", .{@as(u8, @intFromFloat(val * 100.0))}) catch unreachable,
            .weighted_coin            => |val| std.fmt.bufPrintZ(&text_buffer, "next {d}: {d}% less negative", .{3 * ctx.effects.duration_multiplier, @as(u8, @intFromFloat(val * 100.0 * @as(f32, @floatFromInt(ctx.effects.value_multiplier))))}) catch unreachable,
        };
        // zig fmt: on
        const coin_text_width = raylib.measureText(coin_text.ptr, 32);
        std.debug.assert(coin_text_width >= 0);
        raylib.drawText(coin_text.ptr, constants.SIZE_WIDTH / 2 - @divTrunc(coin_text_width, 2), constants.SIZE_HEIGHT - 12 - 46, 32, raylib.Color.black);
    }
    { // draw current balance
        const balance_text = std.fmt.bufPrintZ(&text_buffer, "${d}.{d:02}", .{ ctx.money / 100, ctx.money % 100 }) catch unreachable;
        const balance_text_width = raylib.measureText(balance_text.ptr, 32);
        std.debug.assert(balance_text_width >= 0);
        raylib.drawText(balance_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(balance_text_width, 2), 16, 32, raylib.Color.white);
    }
    { // draw bet amount and slider
        const bet_amount: u64 = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_precentage));
        const bet_amount_text = std.fmt.bufPrintZ(&text_buffer, "Betting: ${d}.{d:02}", .{ bet_amount / 100, bet_amount % 100 }) catch unreachable;
        const bet_amount_text_width = raylib.measureText(bet_amount_text.ptr, 32);
        std.debug.assert(bet_amount_text_width >= 0);
        raylib.drawText(bet_amount_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(bet_amount_text_width, 2), 82, 32, raylib.Color.black);
    }
    var maybe_effect = ctx.effects.effects.first;
    var i: usize = 0;
    while (maybe_effect) |effect_node| : (i += 1) { // draw effects
        maybe_effect = effect_node.next;
        const effect = effect_node.data;
        const effect_text = switch (effect.coin) { // TODO: add new effects here
            .next_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "{d}x multiplier", .{val}) catch unreachable,
            .next_value_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "effects {d}x stronger", .{val}) catch unreachable,
            .next_duration_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "effects {d}x longer", .{val}) catch unreachable,
            .weighted_coin => |val| std.fmt.bufPrintZ(&text_buffer, "{d}% less likely to get bad coin", .{@as(u8, @intFromFloat(val * 100.0))}) catch unreachable,
            else => unreachable,
        };
        raylib.drawText(effect_text, 2, @intCast(2 + i * 14), 2, raylib.Color.white);
    }

    if (show_coin) {
        const textures = [_]raylib.Texture2D{
            ctx.assets.coin_01,
            ctx.assets.coin_02,
            ctx.assets.coin_03,
            ctx.assets.coin_04,
            ctx.assets.coin_05,
            ctx.assets.coin_06,
            ctx.assets.coin_07,
            ctx.assets.coin_08,
        };

        const texture = textures[coin_anim.frame_index];
        texture.drawEx(
            .{
                .x = constants.SIZE_WIDTH / 2 - @as(f32, @floatFromInt(texture.width)),
                .y = constants.SIZE_HEIGHT / 2 - @as(f32, @floatFromInt(texture.height)),
            },
            0.0,
            2.0,
            raylib.Color.white,
        );
    }
}

///// updates shop items
//fn refresh_shop() void {
//    shop_refreshes += 1;
//    var rng_outer = std.Random.DefaultPrng.init(@truncate(@abs(std.time.microTimestamp())));
//    const rng = rng_outer.random();
//    const rarity = 0;
//
//    for (shop_items) |*shop_item| {
//        shop_item.selling = types.Coin.randomFromRarity(rarity, rng);
//    }
//}
// zig fmt: on
