const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const constants = @import("../constants.zig");
const Context = @import("../Context.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

var coin_deck: CoinDeck = undefined;
var last_coin: Coin = .{ .win = {} };
/// unit: cent / $0.01
/// may need to be increased if we get to over *a lot* money
var money: u64 = 10_00;
var bet_precentage: f128 = 0.5;
var effects: EffectList = .{};

pub fn init(ctx: *Context) !void {
    coin_deck = try CoinDeck.init(
        constants.initial_coins,
        @truncate(@abs(std.time.nanoTimestamp())),
        ctx.allocator,
    );
    errdefer coin_deck.deinit(ctx.allocator);

    try coin_deck.positive_deck.append(ctx.allocator, .{ .additive_win = 10_00 });
    try coin_deck.negative_deck.append(ctx.allocator, .{ .next_multiplier = 2 });
}

pub fn deinit(ctx: *Context) void {
    effects.deinit(ctx.allocator);
    coin_deck.deinit(ctx.allocator);
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

    var new_bet_precentage: f32 = @floatCast(bet_precentage);
    _ = raygui.guiSliderBar(.{
        .x = @floatFromInt(constants.SIZE_WIDTH / 3),
        .width = @floatFromInt(constants.SIZE_WIDTH / 3),
        .y = 64,
        .height = 64,
    }, "", "", &new_bet_precentage, 0.0, 1.0);
    bet_precentage = @floatCast(new_bet_precentage);

    const should_flip = raygui.guiButton(.{
        .x = @floatFromInt(constants.SIZE_WIDTH / 3),
        .width = @floatFromInt(constants.SIZE_WIDTH / 3),
        .y = @floatFromInt(constants.SIZE_HEIGHT - 12 - 64),
        .height = 64,
    }, "") != 0 or raylib.isKeyPressed(.space);

    if (should_flip) {
        const bet_amount: @TypeOf(money) = @intFromFloat(@ceil(@as(f128, @floatFromInt(money)) * bet_precentage));

        last_coin = coin_deck.flip(0.5);
        // zig fmt: off
        switch (last_coin) { // TODO: add new effects that get applied once flipping
            .win             => money += bet_amount * effects.multiplier,
            .loss            => money -= bet_amount,
            .additive_win    => |val| money += val * effects.multiplier,
            .next_multiplier => try effects.addEffect(.{
                .coin     = last_coin,
                .duration = 2,
            }, ctx.allocator),
        }
        // zig fmt: on

        effects.update(ctx.allocator);
    }
}

pub fn render(ctx: *Context) !void {
    _ = ctx;

    raylib.clearBackground(raylib.Color.black);
    var text_buffer: [256]u8 = undefined;

    { // draw results of last coin flip
        // zig fmt: off
        const coin_text: [:0]const u8 = switch (last_coin) { // TODO: add new effects that get shown once flipping
            .win             => "heads\x00",
            .loss            => "tails\x00",
            .additive_win    => |val| std.fmt.bufPrintZ(text_buffer[0..], "+ ${d}.{d:02}", .{val / 100, val % 100}) catch unreachable,
            .next_multiplier => |val| std.fmt.bufPrintZ(text_buffer[0..], "next two x{d}", .{val}) catch unreachable,
        };
        // zig fmt: on
        const coin_text_width = raylib.measureText(coin_text.ptr, 32);
        std.debug.assert(coin_text_width >= 0);
        raylib.drawText(coin_text.ptr, constants.SIZE_WIDTH / 2 - @divTrunc(coin_text_width, 2), constants.SIZE_HEIGHT - 12 - 46, 32, raylib.Color.black);
    }

    { // draw current balance
        const balance_text = std.fmt.bufPrintZ(text_buffer[0..], "${d}.{d:02}", .{ money / 100, money % 100 }) catch unreachable;
        const balance_text_width = raylib.measureText(balance_text.ptr, 32);
        std.debug.assert(balance_text_width >= 0);
        raylib.drawText(balance_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(balance_text_width, 2), 16, 32, raylib.Color.white);
    }

    { // draw bet amount and slider
        const bet_amount: u64 = @intFromFloat(@ceil(@as(f128, @floatFromInt(money)) * bet_precentage));
        const bet_amount_text = std.fmt.bufPrintZ(text_buffer[0..], "Betting: ${d}.{d:02}", .{ bet_amount / 100, bet_amount % 100 }) catch unreachable;
        const bet_amount_text_width = raylib.measureText(bet_amount_text.ptr, 32);
        std.debug.assert(bet_amount_text_width >= 0);
        raylib.drawText(bet_amount_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(bet_amount_text_width, 2), 82, 32, raylib.Color.black);
    }

    var effect_y: usize = 0;
    var maybe_effect = effects.effects.first;
    while (maybe_effect) |node| : (maybe_effect = node.next) {
        defer effect_y += 14;

        const effect_text = switch (node.data.coin) {
            .next_multiplier => |val| std.fmt.bufPrintZ(text_buffer[0..], "{d}x multiplier", .{val}) catch unreachable,
            .additive_win => |val| std.fmt.bufPrintZ(text_buffer[0..], "+{d} money", .{val}) catch unreachable,
            else => unreachable,
        };

        raylib.drawText(effect_text, 2, @intCast(2 + effect_y), 2, raylib.Color.white);
    }
}

/// the state of a flipped coin
/// later one, there will also be stuff like
/// - next coin multiplier
/// - extra dice
/// etc here
const Coin = union(enum) {
    /// aka heads
    /// returns 200% of bet amount
    win: void,
    /// aka numbers / tails
    /// doesnt return anything
    loss: void,
    /// returns 100% of bet amount + value
    /// unit: cent / $0.01
    additive_win: u64,
    /// next 2 flips will get a multiplier of value
    /// only if the result is positive tho, ofc
    next_multiplier: u64,
};

/// the effect of a coin combined with a duration
const Effect = struct {
    coin: Coin,
    duration: u32,

    /// returns updated version of an effect
    pub fn update(effect: Effect) ?Effect {
        if (effect.duration <= 0) return null;
        return Effect{
            .coin = effect.coin,
            .duration = effect.duration - 1,
        };
    }
};

/// a list of effects
/// also keeps track of the total effects for convenience
const EffectList = struct {
    const Effects = std.DoublyLinkedList(Effect);

    /// DO NOT OVERWRITE
    effects: Effects = .{},
    /// DO NOT OVERWRITE
    multiplier: u64 = 1,

    pub fn deinit(self: *EffectList, allocator: std.mem.Allocator) void {
        var maybe_node = self.effects.first;
        while (maybe_node) |node| {
            defer allocator.destroy(node);
            defer maybe_node = node.next;
        }
    }

    /// adds an effect and updates values
    pub fn addEffect(self: *EffectList, effect: Effect, allocator: std.mem.Allocator) !void {
        const new_node = try allocator.create(Effects.Node);
        new_node.data = effect;

        self.effects.append(new_node);

        // TODO: update with new effects
        switch (effect.coin) {
            .next_multiplier => |val| self.multiplier *= val,
            else => {},
        }
    }

    /// updates effect list
    pub fn update(self: *EffectList, allocator: std.mem.Allocator) void {
        var maybe_node = self.effects.first;
        while (maybe_node) |node| : (maybe_node = node.next) {
            if (node.data.update()) |updated_effect| {
                node.data = updated_effect;
            } else {
                switch (node.data.coin) {
                    .next_multiplier => |val| self.multiplier /= val,
                    else => {},
                }

                self.effects.remove(node);
                defer allocator.destroy(node);
            }
        }
    }
};

/// some coins
const CoinDeck = struct {
    const Deck = std.ArrayListUnmanaged(Coin);

    rng: std.Random.DefaultPrng,
    positive_deck: Deck,
    negative_deck: Deck,

    /// need to call `deinit()` later to not leak memory
    pub fn init(initial_coins: usize, seed: u64, allocator: std.mem.Allocator) !CoinDeck {

        // create decks
        var positive_deck: Deck = try .initCapacity(allocator, 128);
        var negative_deck: Deck = try .initCapacity(allocator, 128);

        positive_deck.appendNTimesAssumeCapacity(.win, initial_coins);
        negative_deck.appendNTimesAssumeCapacity(.loss, initial_coins);

        // create rng
        const rng = std.Random.DefaultPrng.init(seed);

        return CoinDeck{
            .rng = rng,
            .positive_deck = positive_deck,
            .negative_deck = negative_deck,
        };
    }

    /// frees allocated memory
    pub fn deinit(self: *CoinDeck, allocator: std.mem.Allocator) void {
        self.positive_deck.deinit(allocator);
        self.negative_deck.deinit(allocator);
    }

    /// get a random coin from deck
    /// positive chance is the chance to get one from the positive deck, otherwise you'll get a negative coin
    pub fn flip(self: *CoinDeck, positive_chance: f32) Coin {
        const rng = self.rng.random();

        // get deck
        const deck = if (rng.float(f32) < positive_chance)
            self.positive_deck
        else
            self.negative_deck;

        // get random coin from deck
        const random_index = rng.uintLessThan(usize, deck.items.len);
        const coin = deck.items[random_index];

        return coin;
    }
};
