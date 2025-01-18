//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const std = @import("std");

const Assets = @import("Assets.zig");
const State = @import("states/State.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");
const Serde = @import("serde.zig");

const ContextSerde = Serde(Context, &.{ "coin_deck", "last_coin", "money", "bet_percentage", "effects" });

const Context = @This();
const constants = @import("constants.zig");

running: bool = true,
assets: Assets = .{},
allocator: std.mem.Allocator,
driver: *const State = &State.states.Game,

coin_deck: types.CoinDeck = undefined,
last_coin: types.Coin = .{ .win = {} },
/// unit: cent / $0.01
/// may need to be increased if we get to over *a lot* money
money: u256 = constants.starting_money,
bet_percentage: f32 = 0.5,
effects: types.EffectList = .{},

pub fn serialize(this: *const Context, writer: std.io.AnyWriter) !void {
    try this.coin_deck.serialize(writer);
    _ = try writer.write(std.mem.asBytes(&this.last_coin));
    try writer.writeInt(@FieldType(Context, "money"), this.money, .big);
    _ = try writer.write(std.mem.asBytes(&this.bet_percentage));
    try this.effects.serialize(writer);
}

pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !Context {
    const coin_deck = try types.CoinDeck.deserialize(alloc, reader);

    var last_coins_bytes: [@sizeOf(types.Coin)]u8 = undefined;
    _ = try reader.readAll(last_coins_bytes[0..]);
    const last_coin = std.mem.bytesToValue(types.Coin, last_coins_bytes[0..]);

    const money = try reader.readInt(@FieldType(Context, "money"), .big);

    var bet_percentage_bytes: [@sizeOf(f32)]u8 = undefined;
    _ = try reader.readAll(bet_percentage_bytes[0..]);
    const bet_percentage = std.mem.bytesToValue(f32, bet_percentage_bytes[0..]);

    const effects = try types.EffectList.deserialize(alloc, reader);

    return .{
        .allocator = alloc,
        .coin_deck = coin_deck,
        .last_coin = last_coin,
        .money = money,
        .bet_percentage = bet_percentage,
        .effects = effects,
    };
}

pub fn init(alloc: std.mem.Allocator) !Context {
    var coin_deck: types.CoinDeck = try .init(constants.initial_coins, alloc);
    errdefer coin_deck.deinit(alloc);

    try coin_deck.positive_deck.append(alloc, .{ .next_multiplier = 3 });
    try coin_deck.positive_deck.append(alloc, .{ .next_value_multiplier = 3 });
    try coin_deck.positive_deck.append(alloc, .{ .next_duration_multiplier = 3 });
    try coin_deck.negative_deck.append(alloc, .{ .weighted_coin = 0.25 });
    try coin_deck.negative_deck.append(alloc, .{ .lesser_loss = 0.75 });

    return .{
        .coin_deck = coin_deck,
        .allocator = alloc,
    };
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
