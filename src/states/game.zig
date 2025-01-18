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

pub fn init(ctx: *Context) !void {
    coin_deck = try CoinDeck.init(
        constants.initial_coins,
        @truncate(@abs(std.time.nanoTimestamp())),
        ctx.allocator,
    );
    errdefer coin_deck.deinit();
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
    coin_deck.deinit();
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

    if (raylib.isKeyPressed(.space)) {
        last_coin = coin_deck.flip(0.5);
        switch (last_coin) {
            .loss => money -= @intFromFloat(@ceil(@as(f128, @floatFromInt(money)) * bet_precentage)),
            .win => money += @intFromFloat(@ceil(@as(f128, @floatFromInt(money)) * bet_precentage)),
        }
    }
}

pub fn render(ctx: *Context) !void {
    raylib.clearBackground(raylib.Color.black);

    { // draw results of last coin flip
        const coin_text: [:0]const u8 = switch (last_coin) {
            .win => "heads",
            .loss => "tails",
        };
        const coin_text_width = raylib.measureText(coin_text.ptr, 32);
        std.debug.assert(coin_text_width >= 0);
        raylib.drawText(
            coin_text.ptr,
            @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(coin_text_width, 2),
            @intCast(constants.SIZE_HEIGHT * 3 / 4),
            32,
            raylib.Color.white,
        );
    }
    { // draw current balance
        const balance_text = try std.fmt.allocPrintZ(ctx.allocator, "${d}.{d:02}", .{ money / 100, money % 100 });
        defer ctx.allocator.free(balance_text);
        const balance_text_width = raylib.measureText(balance_text.ptr, 32);
        std.debug.assert(balance_text_width >= 0);
        raylib.drawText(balance_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(balance_text_width, 2), 4, 32, raylib.Color.white);
    }
    { // draw bet amount and slider
        var new_bet_precentage: f32 = @floatCast(bet_precentage);
        _ = raygui.guiSliderBar(.{
            .x = @floatFromInt(constants.SIZE_WIDTH * 1 / 3),
            .width = @floatFromInt(constants.SIZE_WIDTH * 1 / 3),
            .y = 64.0,
            .height = 24.0,
        }, "0%", "100%", &new_bet_precentage, 0.0, 1.0);
        bet_precentage = @floatCast(new_bet_precentage);
        const bet_amount: u64 = @intFromFloat(@ceil(@as(f128, @floatFromInt(money)) * bet_precentage));
        const bet_amount_text = try std.fmt.allocPrintZ(ctx.allocator, "Betting: ${d}.{d:02}", .{ bet_amount / 100, bet_amount % 100 });
        defer ctx.allocator.free(bet_amount_text);
        const bet_amount_text_width = raylib.measureText(bet_amount_text.ptr, 24);
        std.debug.assert(bet_amount_text_width >= 0);
        raylib.drawText(bet_amount_text, @as(i32, @intCast(constants.SIZE_WIDTH / 2)) - @divTrunc(bet_amount_text_width, 2), 92, 24, raylib.Color.white);
    }
}

/// the state of a flipped coin
/// later one, there will also be stuff like
/// - next coin multiplier
/// - extra dice
/// etc here
const Coin = union(enum) {
    /// aka heads
    win: void,
    /// aka numbers / tails
    loss: void,
};

/// some coins
const CoinDeck = struct {
    rng: std.Random.DefaultPrng,
    positive_deck: std.ArrayList(Coin),
    negative_deck: std.ArrayList(Coin),

    /// need to call `deinit()` later to not leak memory
    pub fn init(initial_coins: usize, seed: u64, allocator: std.mem.Allocator) !CoinDeck {
        var outp: CoinDeck = undefined;

        // create decks
        outp.positive_deck = std.ArrayList(Coin).init(allocator);
        errdefer outp.positive_deck.deinit();
        outp.negative_deck = std.ArrayList(Coin).init(allocator);
        errdefer outp.positive_deck.deinit();

        // populate decks
        try outp.positive_deck.ensureTotalCapacity(initial_coins);
        try outp.negative_deck.ensureTotalCapacity(initial_coins);
        for (0..initial_coins) |_| {
            try outp.positive_deck.append(.{ .win = {} });
            try outp.negative_deck.append(.{ .loss = {} });
        }

        // create rng
        outp.rng = std.Random.DefaultPrng.init(seed);

        return outp;
    }
    /// frees allocated memory
    pub fn deinit(self: *CoinDeck) void {
        self.positive_deck.deinit();
        self.negative_deck.deinit();
    }

    /// get a random coin from deck
    /// positive chance is the chance to get one from the positive deck, otherwise you'll get a negative coin
    pub fn flip(self: *CoinDeck, positive_chance: f32) Coin {
        const rng = self.rng.random();

        // get deck
        const is_positive = rng.float(f32) < positive_chance;
        const deck =
            if (is_positive) self.positive_deck else self.negative_deck;

        // TODO: This segfaults after clicking the bar once and trying to flip

        // get random coin from deck
        const random_index = rng.uintLessThan(usize, deck.items.len);
        const coin = deck.items[random_index];

        return coin;
    }
};
