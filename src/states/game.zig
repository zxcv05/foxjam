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

var show_coin: bool = false;
var coin_anim: Animation = .init(8, 32.0);
var rng: std.Random.DefaultPrng = undefined;

pub fn init(ctx: *Context) !void {
    rng = .init(@bitCast(std.time.microTimestamp()));
    _ = ctx;
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
}

pub fn update(ctx: *Context) !void {
    const go_to_trophies =
        raygui.guiButton(.{
            .x = constants.SIZE_WIDTH - 12 - 32 - 6 - 32 - 6 - 32 - 6 - 32,
            .width = 32,
            .y = 12,
            .height = 32,
        }, "#157#") != 0;
    if (go_to_trophies)
        try ctx.switch_driver(&State.states.Trophies);

    const view_stats =
        raygui.guiButton(.{
            .x = constants.SIZE_WIDTH - 12 - 32 - 6 - 32 - 6 - 32,
            .width = 32,
            .y = 12,
            .height = 32,
        }, "#191#") != 0;
    if (view_stats)
        try ctx.switch_driver(&State.states.Stats);

    const view_help =
        raygui.guiButton(.{
            .x = constants.SIZE_WIDTH - 12 - 32 - 6 - 32,
            .width = 32,
            .y = 12,
            .height = 32,
        }, "#193#") != 0;
    if (view_help)
        try ctx.switch_driver(&State.states.Help);

    const go_to_pause_menu =
        raygui.guiButton(.{
            .x = constants.SIZE_WIDTH - 12 - 32,
            .width = 32,
            .y = 12,
            .height = 32,
        }, "#140#") != 0 or raylib.isKeyPressed(.escape);
    if (go_to_pause_menu)
        try ctx.switch_driver(&State.states.PauseMenu);

    _ = raygui.guiSliderBar(.{
        .x = 12 + 96 + 12 + 96 + 12,
        .width = @floatFromInt(constants.SIZE_WIDTH - 2 * (12 + 96 + 12 + 96 + 12)),
        .y = constants.SIZE_HEIGHT - 12 - 64 - 12 - 64,
        .height = 64,
    }, "", "", &ctx.bet_percentage, 0.0, 1.0);

    if (raylib.isKeyPressed(.left)) ctx.bet_percentage -= 0.05;
    if (raylib.isKeyPressed(.right)) ctx.bet_percentage += 0.05;

    // This makes the slider do steps of 0.05
    ctx.bet_percentage = std.math.clamp(@round(ctx.bet_percentage * 20) / 20, 0.0, 1.0);

    const going_to_work =
        raygui.guiButton(.{
            .x = 12,
            .width = 96 + 12 + 96,
            .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64 - 12 - 64),
            .height = 64,
        }, "Go to work") != 0 or raylib.isKeyPressed(.w);

    if (going_to_work) {
        ctx.money += rng.random().intRangeAtMost(u256, constants.work_money_min, constants.work_money_max);

        // TODO: Should this be click or coin?
        // definitely coin, ure getting cash after all
        ctx.assets.play_sound("coin2");
    }

    { // shop stuff
        const prev_text_size = raygui.guiGetStyle(.default, raygui.GuiDefaultProperty.text_size);
        defer raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, prev_text_size);

        raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, 22);
        const refreshing_shop =
            raygui.guiButton(.{
                .x = @floatFromInt(constants.SIZE_WIDTH - 12 - 96 - 12 - 96),
                .width = 96 + 12 + 96,
                .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64 - 12 - 64),
                .height = 64,
            }, "Refresh shop: $10.00") != 0 or raylib.isKeyPressed(.r);

        if (refreshing_shop) {
            if (ctx.money >= 10_00) {
                defer ctx.money -= 10_00;
                ctx.refreshShop();
                ctx.assets.play_sound("click2");
            } else ctx.assets.play_sound("click_bad");
        }

        display_loop: for (0..constants.max_shop_items) |display_num| {
            raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, prev_text_size);
            var display_text_buffer: [256]u8 = undefined;
            const display_text: [:0]const u8 = switch (ctx.shop_items[display_num]) {
                .not_unlocked => "Not unlocked",
                .sold         => "Sold",
                .selling      => |val| blk: {
                    const coin_text = val.coin.toString(&display_text_buffer, 1, 1) catch |err| switch (err) {
                        std.fmt.BufPrintError.NoSpaceLeft => unreachable,
                        else => return err,
                    };
                    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, 16);
                    display_text_buffer[coin_text.len] = '\n';
                    const price_text = try std.fmt.bufPrintZ(display_text_buffer[(coin_text.len + 1)..], "Cost: ${d}.{d:02}", .{val.price / 100, val.price % 100});
                    break :blk @ptrCast(display_text_buffer[0..(coin_text.len + 1 + price_text.len + 1)]);
                },
            };
            const buying_item =
                raygui.guiButton(.{
                    .x = @floatFromInt(constants.SIZE_WIDTH - 12 - 96 - 12 - 96),
                    .width = 96 + 12 + 96,
                    .y = @floatFromInt(constants.SIZE_HEIGHT - (3 + (3 - display_num)) * (12 + 64)),
                    .height = 64,
                }, display_text) != 0;
            if (buying_item) {
                if (ctx.shop_items[display_num] == .not_unlocked or ctx.shop_items[display_num] == .sold) {
                    ctx.assets.play_sound("click_bad");
                    continue :display_loop;
                }
                // we know its selling
                if (ctx.money < ctx.shop_items[display_num].selling.price) {
                    ctx.assets.play_sound("click_bad");
                    continue :display_loop;
                }
                ctx.assets.play_sound("coin2");
                ctx.money -= ctx.shop_items[display_num].selling.price;
                switch (ctx.shop_items[display_num].selling.coin) {
                    .win, .additive_win, .better_win, .next_duration_multiplier, .next_multiplier, .next_value_multiplier => try ctx.coin_deck.positive_deck.append(ctx.allocator, ctx.shop_items[display_num].selling.coin),
                    .loss => unreachable, // we cannot buy a loss
                    else => try ctx.coin_deck.negative_deck.append(ctx.allocator, ctx.shop_items[display_num].selling.coin),
                }
                ctx.shop_items[display_num] = .{ .sold = {} };
            }
        }
    }

    const should_flip =
        raygui.guiButton(.{
            .x = 12 ,
            .width = @floatFromInt(constants.SIZE_WIDTH - 12 - 12),
            .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64),
            .height = 64,
        }, "Flip coin") != 0 or raylib.isKeyPressed(.space);

    if (should_flip) {
        const bet_amount: @TypeOf(ctx.money) = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_percentage));

        coin_anim.frames_played = 0;
        show_coin = true;

        ctx.last_coin = ctx.coin_deck.flip();

        switch (ctx.last_coin) { // TODO: add new effects here
            .win             => ctx.money +|= bet_amount * ctx.effects.multiplier,
            .loss            => ctx.money -|= bet_amount,
            .additive_win    => |val| ctx.money +|= val * ctx.effects.multiplier,
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
            .lesser_loss   => |val| ctx.money -|= @intFromFloat(@as(f32, @floatFromInt(bet_amount)) * val),
            .weighted_coin => |val| try ctx.effects.addEffect(.{
                .coin     = .{ .weighted_coin = val * @as(f32, @floatFromInt(ctx.effects.value_multiplier)) },
                .duration = 3 * ctx.effects.duration_multiplier,
            }, ctx.allocator),
            .better_win => |val| ctx.money +|= @intFromFloat(@as(f32, @floatFromInt(bet_amount * ctx.effects.multiplier)) * (1.0 + val)),
        }

        ctx.effects.update(ctx.allocator);
    }

    if (show_coin) {
        defer coin_anim.update();
        if (coin_anim.frames_played >= 32) show_coin = false;
    }
}

pub fn render(ctx: *Context) !void {
    var text_buffer: [256]u8 = undefined;
    { // draw results of last coin flip
        const coin_text: [:0]const u8 = ctx.last_coin.toString(&text_buffer, ctx.effects.duration_multiplier, ctx.effects.value_multiplier) catch |err| switch (err) {
            std.fmt.BufPrintError.NoSpaceLeft => unreachable,
            else => return err,
        };
        const coin_text_width = raylib.measureText(coin_text.ptr, 32);
        std.debug.assert(coin_text_width >= 0);
        raylib.drawText(
            coin_text.ptr,
            constants.SIZE_WIDTH / 2 - @divTrunc(coin_text_width, 2),
            constants.SIZE_HEIGHT - 12 - 46 - 12 - 64 - 12 - 64,
            32,
            raylib.Color.white
        );
    }
    { // draw current balance
        const balance_text = std.fmt.bufPrintZ(&text_buffer, "${d}.{d:02}", .{ ctx.money / 100, ctx.money % 100 }) catch unreachable;
        const balance_text_width = raylib.measureText(balance_text.ptr, 48);
        std.debug.assert(balance_text_width >= 0);
        raylib.drawText(
            balance_text,
            @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(balance_text_width, 2),
            12,
            48,
            raylib.Color.white
        );
    }
    { // draw bet amount
        const bet_amount: u64 = @intFromFloat(@ceil(@as(f32, @floatFromInt(ctx.money)) * ctx.bet_percentage));
        const bet_amount_text = std.fmt.bufPrintZ(&text_buffer, "Betting: ${d}.{d:02}", .{ bet_amount / 100, bet_amount % 100 }) catch unreachable;
        const bet_amount_text_width = raylib.measureText(bet_amount_text.ptr, 32);
        std.debug.assert(bet_amount_text_width >= 0);
        raylib.drawText(
            bet_amount_text,
            @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(bet_amount_text_width, 2),
            constants.SIZE_HEIGHT - 12 - 64 - 12 - 46,
            32,
            raylib.Color.black
        );
    }
    var maybe_effect = ctx.effects.effects.first;
    var i: usize = 0;
    while (maybe_effect) |effect_node| : (i += 1) { // draw effects
        maybe_effect = effect_node.next;
        const effect = effect_node.data;
        const effect_text = switch (effect.coin) { // TODO: add new effects here
            .next_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "{d}x multiplier", .{val}) catch unreachable,
            .next_value_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "Effects {d}x stronger", .{val}) catch unreachable,
            .next_duration_multiplier => |val| std.fmt.bufPrintZ(&text_buffer, "Effects {d}x longer", .{val}) catch unreachable,
            .weighted_coin => |val| std.fmt.bufPrintZ(&text_buffer, "{d}% less likely to get bad coin", .{@as(u8, @intFromFloat(val * 100.0))}) catch unreachable,
            else => unreachable,
        };
        _ = raygui.guiTextBox(.{
            .x = 12,
            .width = 96 + 12 + 96,
            .y = @floatFromInt(12 + i * (64 + 12)),
            .height = 64,
        }, effect_text, 256, false);
//        raylib.drawText(
//            effect_text,
//            2,
//            @intCast(2 + i * 14),
//            2,
//            raylib.Color.white
//        );
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
                .y = constants.SIZE_HEIGHT / 2 - @as(f32, @floatFromInt(texture.height)) - 60,
            },
            0.0,
            2.0,
            raylib.Color.white,
        );
    }
}
// zig fmt: on
