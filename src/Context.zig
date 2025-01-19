//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const std = @import("std");

const Assets = @import("Assets.zig");
const constants = @import("constants.zig");
const Settings = @import("Settings.zig");
const State = @import("states/State.zig");
const Serde = @import("serde.zig");
const trophy = @import("trophy.zig");
const types = @import("types.zig");

const Context = @This();

running: bool = true,
assets: Assets = .{},
allocator: std.mem.Allocator,
driver: *const State = &State.states.Game,

settings: Settings = .{},

coin_deck: types.CoinDeck = undefined,
last_coin: types.Coin = .{ .win = {} },
money: u256 = constants.starting_money,

bet_percentage: f32 = 0.5,
effects: types.EffectList = .{},

shop_items: [constants.max_shop_items]types.ShopItem = undefined,
shop_refreshes: u16 = 0,

trophy_case: trophy.Case = .{},

pub fn serialize(this: *const Context, writer: std.io.AnyWriter) !void {
    try this.settings.serialize(writer);
    try this.coin_deck.serialize(writer);
    _ = try writer.writeAll(std.mem.asBytes(&this.last_coin));
    try writer.writeInt(@FieldType(Context, "money"), this.money, .big);
    _ = try writer.writeAll(std.mem.asBytes(&this.bet_percentage));
    try this.effects.serialize(writer);

    try writer.writeInt(u16, this.shop_refreshes, .big);
    try writer.writeInt(usize, this.shop_items.len, .big);
    _ = try writer.writeAll(std.mem.sliceAsBytes(this.shop_items[0..]));

    try this.trophy_case.serialize(writer);
}

pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !Context {
    const settings = try Settings.deserialize(alloc, reader);
    var coin_deck = try types.CoinDeck.deserialize(alloc, reader);
    errdefer coin_deck.deinit(alloc);

    var last_coins_bytes: [@sizeOf(types.Coin)]u8 = undefined;
    _ = try reader.readAll(last_coins_bytes[0..]);
    const last_coin = std.mem.bytesToValue(types.Coin, last_coins_bytes[0..]);

    const money = try reader.readInt(@FieldType(Context, "money"), .big);

    var bet_percentage_bytes: [@sizeOf(f32)]u8 = undefined;
    _ = try reader.readAll(bet_percentage_bytes[0..]);
    const bet_percentage = std.mem.bytesToValue(f32, bet_percentage_bytes[0..]);

    var effects = try types.EffectList.deserialize(alloc, reader);
    errdefer effects.deinit(alloc);

    const shop_refreshes = try reader.readInt(u16, .big);
    const shop_items_len = try reader.readInt(usize, .big);

    if (shop_items_len != constants.max_shop_items) return error.InvalidSave;

    var shop_items: [constants.max_shop_items]types.ShopItem = undefined;
    _ = try reader.readAll(std.mem.sliceAsBytes(shop_items[0..]));

    const trophy_case = trophy.Case.deserialize(alloc, reader) catch |e| default: {
        std.log.err("error deserializing trophies: {s}", .{@errorName(e)});
        break :default trophy.Case{};
    };

    return .{
        .allocator = alloc,
        .settings = settings,
        .coin_deck = coin_deck,
        .last_coin = last_coin,
        .money = money,
        .bet_percentage = bet_percentage,
        .effects = effects,
        .shop_refreshes = shop_refreshes,
        .shop_items = shop_items,
        .trophy_case = trophy_case,
    };
}

pub fn init(alloc: std.mem.Allocator) !Context {
    var outp: Context = .{
        .allocator = alloc,
    };

    outp.coin_deck = try .init(constants.initial_coins, alloc);
    errdefer outp.coin_deck.deinit(alloc);

    outp.refreshShop();

    return outp;
}

pub fn deinit(this: *Context) void {
    this.effects.deinit(this.allocator);
    this.coin_deck.deinit(this.allocator);
}

pub fn switch_driver(this: *Context, driver: *const State) !void {
    try this.driver.leave(this);
    try driver.enter(this);

    this.driver = driver;
}

pub inline fn positive_chance(this: *Context) f32 {
    return this.effects.coin_weight / 2.0 +
        std.math.lerp(
        1.0,
        0.5,
        std.math.clamp(
            @as(f32, @floatFromInt(this.coin_deck.flips)) / 8.0,
            0.0,
            1.0,
        ),
    );
}

/// updates shop items
pub fn refreshShop(ctx: *Context) void {
    ctx.shop_refreshes += 1;
    var rng_outer = std.Random.DefaultPrng.init(@truncate(@abs(std.time.microTimestamp())));
    const rng = rng_outer.random();

    const is_mid_game = countTrues(&[_]bool{
        ctx.shop_refreshes >= 4,
        ctx.coin_deck.flips >= 10,
        ctx.money >= 50_00,
    }) >= 2;
    const is_end_game = countTrues(&[_]bool{
        ctx.shop_refreshes >= 11,
        ctx.coin_deck.flips >= 25,
        ctx.money >= 250_00,
    }) >= 2;
    const is_legendary = countTrues(&[_]bool{
        ctx.shop_refreshes >= 21,
        ctx.coin_deck.flips >= 50,
        ctx.money >= 1000_00,
    }) >= 2;

    const base_price: f32 = @floatFromInt(ctx.shop_refreshes * 5);

    for (0..constants.max_shop_items) |i| {
        if (is_legendary and rng.float(f32) < 0.1) {
            const random_index = rng.uintLessThan(usize, legendary_shop_items.len);
            ctx.shop_items[i] = .{ .selling = .{
                .coin = legendary_shop_items[random_index],
                .price = @intFromFloat(3 * base_price * std.math.clamp(rng.floatNorm(f32) * 0.2 + 1.0, 0.5, 2.0)),
            } };
            continue;
        }

        const possible_items: ?[]const types.Coin = switch (i) {
            0, 1 => // starting displays
            if (is_mid_game) &(early_shop_items ++ mid_shop_items) else &early_shop_items,
            2 => // mid game shop
            if (!is_mid_game) null else if (is_end_game) &(mid_shop_items ++ end_shop_items) else &mid_shop_items,
            3 => // end game shop
            if (!is_end_game) null else &end_shop_items,
            else => unreachable,
        };
        if (possible_items) |items| {
            const random_index = rng.uintLessThan(usize, items.len);
            ctx.shop_items[i] = .{ .selling = .{
                .coin = items[random_index],
                .price = @intFromFloat(base_price * std.math.clamp(rng.floatNorm(f32) * 0.1 + 1.0, 0.0, 2.0)),
            } };
        } else ctx.shop_items[i] = .{ .not_unlocked = {} };
    }
}
const early_shop_items = [_]types.Coin{
    .{ .win = {} },
    .{ .win = {} },
    .{ .win = {} },
    .{ .win = {} },

    .{ .additive_win = 1_75 },
    .{ .additive_win = 2_00 },
    .{ .additive_win = 2_00 },
    .{ .additive_win = 2_25 },
    .{ .additive_win = 2_50 },

    .{ .lesser_loss = 0.80 },
    .{ .lesser_loss = 0.75 },
    .{ .lesser_loss = 0.75 },
    .{ .lesser_loss = 0.70 },
    .{ .lesser_loss = 0.60 },

    .{ .weighted_coin = 0.15 },
    .{ .next_multiplier = 2 },
};
const mid_shop_items = [_]types.Coin{
    .{ .win = {} },
    .{ .win = {} },
    .{ .win = {} },
    .{ .better_win = 1.0 },

    .{ .additive_win = 10_00 },
    .{ .additive_win = 12_50 },
    .{ .additive_win = 12_50 },
    .{ .additive_win = 15_00 },
    .{ .additive_win = 15_00 },
    .{ .additive_win = 20_00 },

    .{ .next_multiplier = 2 },
    .{ .next_multiplier = 2 },
    .{ .next_multiplier = 3 },
    .{ .next_multiplier = 4 },

    .{ .next_value_multiplier = 2 },
    .{ .next_value_multiplier = 2 },

    .{ .next_duration_multiplier = 2 },
    .{ .next_duration_multiplier = 2 },

    .{ .weighted_coin = 0.30 },
    .{ .weighted_coin = 0.30 },
    .{ .weighted_coin = 0.40 },

    .{ .lesser_loss = 0.50 },
    .{ .lesser_loss = 0.45 },
    .{ .lesser_loss = 0.45 },
    .{ .lesser_loss = 0.40 },
};
const end_shop_items = [_]types.Coin{
    .{ .better_win = 1.5 },
    .{ .better_win = 2.0 },
    .{ .better_win = 2.0 },
    .{ .better_win = 2.5 },
    .{ .better_win = 2.5 },
    .{ .better_win = 3.0 },

    .{ .next_multiplier = 6 },
    .{ .next_multiplier = 8 },
    .{ .next_multiplier = 8 },
    .{ .next_multiplier = 10 },

    .{ .next_value_multiplier = 3 },
    .{ .next_value_multiplier = 3 },
    .{ .next_value_multiplier = 4 },
    .{ .next_value_multiplier = 4 },

    .{ .next_duration_multiplier = 3 },
    .{ .next_duration_multiplier = 3 },
    .{ .next_duration_multiplier = 4 },
    .{ .next_duration_multiplier = 4 },

    .{ .weighted_coin = 0.50 },
    .{ .weighted_coin = 0.75 },
    .{ .weighted_coin = 0.75 },
    .{ .weighted_coin = 0.90 },

    .{ .lesser_loss = 0.25 },
    .{ .lesser_loss = 0.25 },
};
const legendary_shop_items = [_]types.Coin{
    .{ .better_win = 10.0 },
    .{ .next_multiplier = 25 },
    .{ .next_value_multiplier = 10 },
    .{ .next_duration_multiplier = 10 },
    .{ .weighted_coin = 1.0 },
    .{ .lesser_loss = 0.0 },
};
fn countTrues(bools: []const bool) usize {
    var count: usize = 0;
    for (bools) |b| {
        if (b) count += 1;
    }
    return count;
}
