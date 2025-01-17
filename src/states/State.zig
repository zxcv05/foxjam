const std = @import("std");

const Context = @import("../Context.zig");

const State = @This();

pub const states = struct {
    // zig fmt: off
    pub const Game      = @import("game.zig").interface;
    pub const PauseMenu = @import("pause_menu.zig").interface;
    // zig fmt: on

    /// list of all states, needed for initializationa dn deinitialization
    /// yes i know, code duplication bad, but this is sadly needed unless u come up with something smarter
    pub const all = [_]State {
        Game,
        PauseMenu,
    };
};

init: *const fn (*Context) anyerror!void,
deinit: *const fn (*Context) void,
enter: *const fn (*Context) anyerror!void,
leave: *const fn (*Context) anyerror!void,
update: *const fn (*Context) anyerror!void,
render: *const fn (*Context) anyerror!void,
