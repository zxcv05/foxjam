const Context = @import("../Context.zig");

pub const states = struct {
    // zig fmt: off
    pub const Game      = @import("game.zig").interface;
    pub const PauseMenu = @import("pause_menu.zig").interface;
    // zig fmt: on
};

enter: *const fn (*Context) anyerror!void,
leave: *const fn (*Context) anyerror!void,
update: *const fn (*Context) anyerror!void,
render: *const fn (*Context) anyerror!void,
