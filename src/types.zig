const std = @import("std");

/// the state of a flipped coin
/// later one, there will also be stuff like
/// - next coin multiplier
/// - extra dice
/// etc here
pub const Coin = union(enum) {
    pub const Tag = @typeInfo(Coin).@"union".tag_type.?;

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
pub const Effect = struct {
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
pub const EffectList = struct {
    pub const Effects = std.DoublyLinkedList(Effect);

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

        // zig fmt: off
        switch (effect.coin) { // TODO: add new effects here
            .next_multiplier => |val| self.multiplier *= val,
            else => {},
        }
        // zig fmt: on
    }

    /// updates effect list
    pub fn update(self: *EffectList, allocator: std.mem.Allocator) void {
        var maybe_node = self.effects.first;
        while (maybe_node) |node| {
            maybe_node = node.next;

            if (node.data.update()) |updated_effect| {
                node.data = updated_effect;
                continue;
            }

            // zig fmt: off
            switch (node.data.coin) { // TODO: add new effects here
                .next_multiplier => |val| self.multiplier /= val,
                else => {},
            }
            // zig fmt: on

            self.effects.remove(node);
            defer allocator.destroy(node);
        }
    }
};

/// some coins
pub const CoinDeck = struct {
    pub const Deck = std.ArrayListUnmanaged(Coin);

    rng: std.Random.DefaultPrng,
    positive_deck: Deck,
    negative_deck: Deck,
    flips: u64 = 0,

    /// need to call `deinit()` later to not leak memory
    pub fn init(initial_coins: usize, seed: u64, allocator: std.mem.Allocator) !CoinDeck {
        // create decks

        // TODO : Emscripten build fails here
        var positive_deck: Deck = try .initCapacity(allocator, 8);
        var negative_deck: Deck = try .initCapacity(allocator, 8);

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
        const deck =
            if (rng.float(f32) < positive_chance) self.positive_deck
            else                                  self.negative_deck;

        // get random coin from deck
        const random_index = rng.uintLessThan(usize, deck.items.len);
        const coin = deck.items[random_index];

        self.flips += 1;
        return coin;
    }
};
