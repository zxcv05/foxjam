//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const Audios = @import("audios.zig");
const Sprites = @import("sprites.zig");

const State = @This();

running: bool = true,

audios: Audios = .{},
sprites: Sprites = .{},

active_states: game_flags.FlagType = game_flags.default,

pub const game_flags = struct {
    /// type capable of representing all possible flags
    // bit width should equal amount of possible states
    pub const FlagType = u2;

    // zig fmt: off
    pub const game:       FlagType = 1 << 0;
    pub const pause_menu: FlagType = 1 << 1;
    // zig fmt: on

    /// game state to start on
    pub const default = game_flags.game;
};

pub inline fn isStateActive(self: State, flag: game_flags.FlagType) bool {
    return (self.active_states & flag) != 0;
}

pub inline fn highestActiveState(self: State) game_flags.FlagType {
    return @as(game_flags.FlagType, 1) << @intCast(@typeInfo(game_flags.FlagType).int.bits - 1 - @clz(self.active_states));
}

pub inline fn activateState(self: *State, flag: game_flags.FlagType) void {
    self.active_states |= flag;
}

pub inline fn deactivateState(self: *State, flag: game_flags.FlagType) void {
    self.active_states &= ~flag;
}
