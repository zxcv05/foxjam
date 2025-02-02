//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const std = @import("std");

const constants = @import("constants.zig");
const Settings = @import("Settings.zig");
const Assets = @import("Assets.zig");
const trophy = @import("trophy.zig");
const types = @import("types.zig");
const serde = @import("serde.zig");
const Bet = @import("bet.zig");

const State = @import("states/State.zig");

const Context = @This();

pub const SAVE_ID: u8 = 0x2a;

running: bool = true,
assets: Assets = .{},
allocator: std.mem.Allocator,
driver: *const State = &State.states.Game,

settings: Settings = .{},

coin_deck: types.CoinDeck,
last_coin: types.Coin = .{ .win = {} },

money: std.math.big.int.Managed,
money_string: []u8 = &.{},

bet: Bet.Amount = .@"50%",

effects: types.EffectList = .{},

shop_items: [constants.max_shop_items]types.ShopItem = undefined,
shop_refreshes: u16 = 0,

times_worked: u16 = 0,

trophy_case: trophy.Case = .{},

losses_in_a_row: u16 = 0,
wins_in_a_row: u16 = 0,

pub fn serialize(this: *const Context, writer: std.io.AnyWriter) !void {
    try serde.write(this.settings, writer);
    try serde.write(this.coin_deck, writer);

    try serde.write(this.last_coin, writer);

    try serde.write(this.money.metadata, writer);
    try writer.writeAll(std.mem.sliceAsBytes(this.money.limbs[0..this.money.len()]));

    try serde.write(this.bet, writer);
    try serde.write(this.effects, writer);

    try serde.write(this.shop_refreshes, writer);

    try serde.write(this.shop_items.len, writer);
    try serde.write(this.shop_items, writer);

    try serde.write(this.times_worked, writer);
    try serde.write(this.trophy_case, writer);
}

pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !Context {
    const settings = try serde.read(Settings, alloc, reader);

    var coin_deck = try serde.read(types.CoinDeck, alloc, reader);
    errdefer coin_deck.deinit(alloc);

    const last_coin = try serde.read(types.Coin, null, reader);

    const money_metadata = try serde.read(usize, null, reader);
    const money_len = money_metadata & ~@as(usize, 1 << (@typeInfo(usize).int.bits - 1));

    const money_limbs = try alloc.alloc(usize, money_len);
    defer alloc.free(money_limbs);

    if (@divExact(try reader.readAll(std.mem.sliceAsBytes(money_limbs)), @sizeOf(usize)) != money_len) return error.EndOfStream;

    const const_money: std.math.big.int.Const = .{
        .positive = money_metadata & ~money_len == 0,
        .limbs = money_limbs,
    };

    const money: @FieldType(Context, "money") = try const_money.toManaged(alloc);

    const bet = try serde.read(Bet.Amount, null, reader);

    var effects = try serde.read(types.EffectList, alloc, reader);
    errdefer effects.deinit(alloc);

    const shop_refreshes = try serde.read(u16, null, reader);

    const shop_items_len = try serde.read(usize, null, reader);
    if (shop_items_len != constants.max_shop_items) return error.InvalidSave;

    const shop_items = try serde.read(@FieldType(Context, "shop_items"), null, reader);

    const times_worked = try serde.read(u16, null, reader);
    const trophy_case = try serde.read(trophy.Case, alloc, reader);

    return .{
        .allocator = alloc,
        .settings = settings,
        .coin_deck = coin_deck,
        .last_coin = last_coin,
        .money = money,
        .bet = bet,
        .effects = effects,
        .shop_refreshes = shop_refreshes,
        .shop_items = shop_items,
        .trophy_case = trophy_case,
        .times_worked = times_worked,
    };
}

pub fn init(alloc: std.mem.Allocator) !Context {
    const coin_deck: @FieldType(Context, "coin_deck") = try .init(constants.initial_coins, alloc);
    const money: @FieldType(Context, "money") = try .initSet(alloc, constants.starting_money);

    var outp: Context = .{
        .allocator = alloc,
        .coin_deck = coin_deck,
        .money = money,
    };

    outp.money_string = try outp.bigint_string_alloc(money.toConst());
    outp.refreshShop();
    return outp;
}

pub fn deinit(this: *Context) void {
    this.save() catch |e| std.log.err("Failed to save: {s}", .{@errorName(e)});

    this.money.deinit();
    this.effects.deinit(this.allocator);
    this.coin_deck.deinit(this.allocator);
    this.allocator.free(this.money_string);
}

pub fn save(this: *Context) !void {
    const config_dir_path = try std.fs.getAppDataDir(this.allocator, "foxjam");
    defer this.allocator.free(config_dir_path);
    std.fs.makeDirAbsolute(config_dir_path) catch {};

    var config_dir = try std.fs.openDirAbsolute(config_dir_path, .{});
    defer config_dir.close();

    config_dir.deleteTree("ctx.sav.old") catch {};
    config_dir.rename("ctx.sav", "ctx.sav.old") catch {};

    const file = try config_dir.createFile("ctx.sav", .{});
    defer file.close();

    try serde.serialize(this.*, file.writer().any());
}

pub fn load(alloc: std.mem.Allocator) !Context {
    const config_dir_path = try std.fs.getAppDataDir(alloc, "foxjam");
    defer alloc.free(config_dir_path);
    std.fs.makeDirAbsolute(config_dir_path) catch {};

    var config_dir = try std.fs.openDirAbsolute(config_dir_path, .{});
    defer config_dir.close();

    return get_ctx: {
        const file = config_dir.openFile("ctx.sav", .{ .mode = .read_only }) catch {
            break :get_ctx try Context.init(alloc);
        };
        defer file.close();

        var ctx = serde.deserialize(Context, alloc, file.reader().any()) catch |e| {
            std.log.err("failed loading ctx: {s}", .{@errorName(e)});
            break :get_ctx try Context.init(alloc);
        };

        try ctx.update_money_string();

        break :get_ctx ctx;
    };
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
    ) + std.math.clamp(
        (@as(f32, @floatFromInt(this.losses_in_a_row)) - 1.0) * 0.1,
        0.0,
        0.5,
    );
}

pub fn update_money_string(ctx: *Context) !void {
    ctx.money_string = try bigint_string_realloc(ctx, ctx.money_string, ctx.money.toConst());
}

pub fn bigint_string_realloc(ctx: *Context, string: []u8, bigint: std.math.big.int.Const) ![]u8 {
    return try bigint_string(ctx, try ctx.allocator.realloc(string, ctx.money.sizeInBaseUpperBound(10) + 8), bigint);
}

pub fn bigint_string_alloc(ctx: *Context, bigint: std.math.big.int.Const) ![]u8 {
    return try bigint_string(ctx, try ctx.allocator.alloc(u8, ctx.money.sizeInBaseUpperBound(10) + 8), bigint);
}

fn bigint_string(ctx: *Context, string: []u8, bigint: std.math.big.int.Const) ![]u8 {
    if (bigint.orderAgainstScalar(1_00) == .lt) {
        const cents = bigint.to(u8) catch unreachable;

        const new_string = try std.fmt.bufPrintZ(string, "0.{d:02}", .{cents});
        return ctx.allocator.realloc(string, new_string.len + 1);
    }

    const limbs = try ctx.allocator.alloc(usize, std.math.big.int.calcToStringLimbsBufferLen(bigint.limbs.len, 10));
    defer ctx.allocator.free(limbs);

    const size = bigint.toString(string, 10, .lower, limbs);
    std.mem.copyBackwards(u8, string[size - 1 ..], string[size - 2 .. size]);

    string[size - 2] = '.';
    string[size + 1] = 0;

    return ctx.allocator.realloc(string, size + 2);
}

/// updates shop items
pub fn refreshShop(ctx: *Context) void {
    ctx.shop_refreshes += 1;

    var rng_outer = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    const rng = rng_outer.random();

    const is_mid_game = countTrues(&[_]bool{
        ctx.shop_refreshes >= 4,
        ctx.coin_deck.flips >= 10,
        ctx.money.toConst().orderAgainstScalar(100_00) != .lt,
    }) >= 2;

    const is_end_game = countTrues(&[_]bool{
        ctx.shop_refreshes >= 11,
        ctx.coin_deck.flips >= 100,
        ctx.money.toConst().orderAgainstScalar(500_00) != .lt,
    }) >= 2;

    const is_legendary = countTrues(&[_]bool{
        ctx.shop_refreshes >= 21,
        ctx.coin_deck.flips >= 500,
        ctx.money.toConst().orderAgainstScalar(10_000_00) != .lt,
    }) >= 2;

    trophy.unlock_if(ctx, .fire, is_legendary);

    const shop_refreshes_u256 = @as(u256, ctx.shop_refreshes);
    const base_price: f32 = if (shop_refreshes_u256 <= 10)
        @floatFromInt(shop_refreshes_u256 * 1_50)
    else
        @floatFromInt(shop_refreshes_u256 * shop_refreshes_u256 * 150 + 15000 - shop_refreshes_u256 * 2850);

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
            // starting displays
            0, 1 => if (is_mid_game)
                &(early_shop_items ++ mid_shop_items)
            else
                &early_shop_items,

            // mid game shop
            2 => if (is_end_game)
                &(mid_shop_items ++ end_shop_items)
            else if (is_mid_game)
                &mid_shop_items
            else
                null,

            // end game shop
            3 => if (is_end_game) &end_shop_items else null,

            else => unreachable,
        };

        if (possible_items) |items| {
            const random_index = rng.uintLessThan(usize, items.len);
            ctx.shop_items[i] = .{
                .selling = .{
                    .coin = switch (items[random_index]) {
                        // zig fmt: off
                        .additive_win   => |val| .{ .additive_win = @intFromFloat(@as(f32, @floatFromInt(val)) * std.math.clamp(rng.floatNorm(f32) * 0.1 + 1.0, 0.5, 2.0)) },
                        .weighted_coin  => |val| .{ .weighted_coin = val * std.math.clamp(rng.floatNorm(f32) * 0.1 + 1.0, 0.5, 2.0) },
                        else => items[random_index],
                        // zig fmt: on
                    },
                    .price = @intFromFloat(base_price * std.math.clamp(rng.floatNorm(f32) * 0.1 + 1.0, 0.0, 2.0)),
                },
            };
        } else ctx.shop_items[i] = .{ .not_unlocked = {} };
    }
}

const early_shop_items = [_]types.Coin{
    .{ .win = {} },
    .{ .win = {} },

    .{ .additive_win = 1_00 },
    .{ .additive_win = 1_25 },
    .{ .additive_win = 1_25 },
    .{ .additive_win = 1_50 },
    .{ .additive_win = 2_00 },

    .{ .weighted_coin = 0.15 },
    .{ .next_multiplier = 2 },
};

const mid_shop_items = [_]types.Coin{
    .{ .win = {} },

    .{ .additive_win = 5_00 },
    .{ .additive_win = 6_00 },
    .{ .additive_win = 6_00 },
    .{ .additive_win = 7_00 },
    .{ .additive_win = 7_00 },

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
};

const end_shop_items = [_]types.Coin{
    .{ .additive_win = 10_00 },
    .{ .additive_win = 12_50 },
    .{ .additive_win = 15_00 },

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
};

const legendary_shop_items = [_]types.Coin{
    .{ .next_multiplier = 25 },
    .{ .next_value_multiplier = 10 },
    .{ .next_duration_multiplier = 10 },
    .{ .weighted_coin = 1.0 },
};

fn countTrues(bools: []const bool) usize {
    var count: usize = 0;
    for (bools) |b| {
        if (b) count += 1;
    }
    return count;
}
