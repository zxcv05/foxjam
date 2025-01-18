//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const std = @import("std");

const Assets = @import("Assets.zig");
const State = @import("states/State.zig");

const types = @import("types.zig");

const Context = @This();

running: bool = true,
assets: Assets = .{},
allocator: std.mem.Allocator,
driver: *const State = &State.states.Game,

coin_deck: types.CoinDeck = undefined,
last_coin: types.Coin = .{ .win = {} },
money: u64 = 10_00,
bet_precentage: f32 = 0.5,
positive_chance: f32 = 0.5,
effects: types.EffectList = .{},

pub fn switch_driver(this: *Context, driver: *const State) !void {
    try this.driver.leave(this);
    try driver.enter(this);

    this.driver = driver;
}
