const std = @import("std");

const Context = @import("Context.zig");
const trophy = @import("trophy.zig");

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
    additive_win: u256,
    /// next 2 flips will get a multiplier of value
    /// only if the result is positive tho, ofc
    next_multiplier: u256,
    /// next 3 flips, when an effect is gotten, value is multiplied by value
    /// doesnt apply to itself
    next_value_multiplier: u256,
    /// next 2 flips, when an effect is gotten, duration is multiplied by value
    /// doesnt apply to itself
    next_duration_multiplier: u32,
    /// you lose only value ([0,1]) of money
    lesser_loss: f32,
    /// next 3 flips, youre value ([0,1]) less likely to get a negative coin
    weighted_coin: f32,
    /// same as win, except it returns 100% + value of bet amount
    better_win: f32,

    // putting this here for less code duplication
    pub fn toString(self: Coin, buffer: []u8, duration_multiplier: u32, value_multiplier: u256) ![:0]const u8 {
        return switch (self) { // TODO: add new effects here
            .win => try std.fmt.bufPrintZ(buffer, "Heads", .{}),
            .loss => try std.fmt.bufPrintZ(buffer, "Tails", .{}),
            .additive_win => |val| try std.fmt.bufPrintZ(buffer, "Heads + ${d}.{d:02}", .{ val / 100, val % 100 }),
            .next_multiplier => |val| try std.fmt.bufPrintZ(buffer, "Next {d}: x{d}", .{ 2 * duration_multiplier, val * value_multiplier }),
            .next_value_multiplier => |val| try std.fmt.bufPrintZ(buffer, "Next {d}: effects x{d}", .{ 3 * duration_multiplier, val }),
            .next_duration_multiplier => |val| try std.fmt.bufPrintZ(buffer, "Next 2: duration x{d}", .{val * @as(u32, @intCast(value_multiplier))}),
            .lesser_loss => |val| try std.fmt.bufPrintZ(buffer, "{d}% tails", .{@as(u8, @intFromFloat(val * 100.0))}),
            .weighted_coin => |val| try std.fmt.bufPrintZ(buffer, "Next {d}: {d}% less negative", .{ 3 * duration_multiplier, @as(u8, @intFromFloat(val * 100.0 * @as(f32, @floatFromInt(value_multiplier)))) }),
            .better_win => |val| try std.fmt.bufPrintZ(buffer, "{d}% heads", .{100 + @as(u16, @intFromFloat(val * 100.0))}),
        };
    }
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
    multiplier: u256 = 1,
    /// DO NOT OVERWRITE
    value_multiplier: u256 = 1,
    /// DO NOT OVERWRITE
    duration_multiplier: u32 = 1,
    /// DO NOT OVERWRITE
    /// gets added to positive chance
    coin_weight: f32 = 0.0,

    pub fn serialize(this: *const EffectList, writer: std.io.AnyWriter) !void {
        try writer.writeInt(u256, this.multiplier, .big);
        try writer.writeInt(u256, this.value_multiplier, .big);
        try writer.writeInt(u32, this.duration_multiplier, .big);

        try writer.writeAll(std.mem.asBytes(&this.coin_weight));

        try writer.writeInt(usize, this.effects.len, .big);
        var maybe_node = this.effects.first;
        while (maybe_node) |node| : (maybe_node = node.next)
            try writer.writeAll(std.mem.asBytes(&node.data));
    }

    pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !EffectList {
        const multiplier = try reader.readInt(u256, .big);
        const value_multiplier = try reader.readInt(u256, .big);
        const duration_multiplier = try reader.readInt(u32, .big);

        var coin_weight_bytes: [@sizeOf(f32)]u8 = undefined;
        _ = try reader.readAll(coin_weight_bytes[0..]);
        const coin_weight = std.mem.bytesToValue(f32, coin_weight_bytes[0..]);

        var effects: Effects = .{};

        const effects_len = try reader.readInt(usize, .big);
        for (0..effects_len) |_| {
            var effect_bytes: [@sizeOf(Effect)]u8 = undefined;
            _ = try reader.readAll(effect_bytes[0..]);

            const node = try alloc.create(Effects.Node);
            node.data = std.mem.bytesToValue(Effect, effect_bytes[0..]);

            effects.append(node);
        }

        return .{
            .effects = effects,
            .multiplier = multiplier,
            .value_multiplier = value_multiplier,
            .duration_multiplier = duration_multiplier,
            .coin_weight = coin_weight,
        };
    }

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
            .next_multiplier          => |val| self.multiplier *= val,
            .next_value_multiplier    => |val| self.value_multiplier *= val,
            .next_duration_multiplier => |val| self.duration_multiplier *= val,
            .weighted_coin            => |val| self.coin_weight += val,
            else => unreachable,
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
                .next_multiplier          => |val| self.multiplier /= val,
                .next_value_multiplier    => |val| self.value_multiplier /= val,
                .next_duration_multiplier => |val| self.duration_multiplier /= val,
                .weighted_coin            => |val| self.coin_weight -= val,
                else => unreachable,
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

    pub fn serialize(this: *const CoinDeck, writer: std.io.AnyWriter) !void {
        try writer.writeInt(u64, this.flips, .big);

        try writer.writeInt(usize, this.positive_deck.items.len, .big);
        for (this.positive_deck.items) |*item|
            try writer.writeAll(std.mem.asBytes(item));

        try writer.writeInt(usize, this.negative_deck.items.len, .big);
        for (this.negative_deck.items) |*item|
            try writer.writeAll(std.mem.asBytes(item));
    }

    pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !CoinDeck {
        const rng = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
        const flips = try reader.readInt(u64, .big);

        const pos_deck_size = try reader.readInt(usize, .big);
        var pos_deck: Deck = try .initCapacity(alloc, pos_deck_size);
        errdefer pos_deck.deinit(alloc);
        for (0..pos_deck_size) |_| {
            var buffer: [@sizeOf(Coin)]u8 = undefined;
            _ = try reader.readAll(buffer[0..]);
            pos_deck.appendAssumeCapacity(std.mem.bytesToValue(Coin, buffer[0..]));
        }

        const neg_deck_size = try reader.readInt(usize, .big);
        var neg_deck: Deck = try .initCapacity(alloc, neg_deck_size);
        errdefer neg_deck.deinit(alloc);
        for (0..neg_deck_size) |_| {
            var buffer: [@sizeOf(Coin)]u8 = undefined;
            _ = try reader.readAll(buffer[0..]);
            neg_deck.appendAssumeCapacity(std.mem.bytesToValue(Coin, buffer[0..]));
        }

        return .{
            .rng = rng,
            .flips = flips,
            .positive_deck = pos_deck,
            .negative_deck = neg_deck,
        };
    }

    /// need to call `deinit()` later to not leak memory
    pub fn init(initial_coins: usize, allocator: std.mem.Allocator) !CoinDeck {
        // create decks

        // TODO : Emscripten build fails here
        var positive_deck: Deck = try .initCapacity(allocator, 8);
        var negative_deck: Deck = try .initCapacity(allocator, 8);

        positive_deck.appendNTimesAssumeCapacity(.win, initial_coins);
        negative_deck.appendNTimesAssumeCapacity(.loss, initial_coins);

        // create rng
        const rng = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));

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
    pub fn flip(self: *CoinDeck) Coin {
        const ctx: *Context = @alignCast(@fieldParentPtr("coin_deck", self)); // hehe :3
        // i assume well keep this open source, god people might hate this
        // dont listen to the haters tho, i love it :3
        const rand = self.rng.random();

        // get deck
        const positive = rand.float(f32) < ctx.positive_chance();
        ctx.wins_in_a_row =
            if (positive) ctx.wins_in_a_row + 1 else 0;
        ctx.losses_in_a_row =
            if (positive) 0 else ctx.losses_in_a_row + 1;
        const deck = if (positive) self.positive_deck else self.negative_deck;

        // todo: is this the right place for this?
        if (positive) ctx.assets.play_sound("coin1") else ctx.assets.play_sound("coin2");

        // get random coin from deck
        const random_index = rand.uintLessThan(usize, deck.items.len);
        const coin = deck.items[random_index];

        self.flips += 1;
        return coin;
    }
};

pub const ShopItem = union(enum) {
    not_unlocked: void,
    sold: void,
    selling: struct {
        coin: Coin,
        price: u256,
    },
};
