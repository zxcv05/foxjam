const std = @import("std");
const raylib = @import("raylib");

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

pub fn init(allocator: std.mem.Allocator) !void {
    coin_deck = try CoinDeck.init(
        constants.initial_coins,
        @truncate(@abs(std.time.nanoTimestamp())),
        allocator
    );
    errdefer coin_deck.deinit();
}

pub fn deinit(allocator: std.mem.Allocator) void {
    _ = allocator;
    coin_deck.deinit();
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

    if (raylib.isKeyPressed(.space)) {
        last_coin = coin_deck.flip(0.5);
    }
}

pub fn render(ctx: *Context) !void {
    _ = ctx;

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

/// the state of a flipped coin
/// later one, there will also be stuff like
/// - next coin multiplier
/// - extra dice
/// etc here
const Coin = union (enum) {
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
            try outp.positive_deck.append(.{ .win  = {} });
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
            if (is_positive) self.positive_deck
            else             self.negative_deck;

        // get random coin from deck
        const random_index = rng.uintLessThan(usize, deck.items.len);
        const coin = deck.items[random_index];

        return coin;
    }
};
