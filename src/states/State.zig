const std = @import("std");

const Context = @import("../Context.zig");

const State = @This();

pub const states = struct {
    // zig fmt: off
    pub const Game      = @import("game.zig").interface;
    pub const PauseMenu = @import("pause_menu.zig").interface;
    // zig fmt: on

    pub fn init(ctx: *Context) !void {
        inline for (@typeInfo(states).@"struct".decls) |decl_info| {
            const decl = @field(states, decl_info.name);
            if (@typeInfo(@TypeOf(decl)) != .@"struct") continue;
            try decl.init(ctx);
        }
    }

    pub fn deinit(ctx: *Context) void {
        inline for (@typeInfo(states).@"struct".decls) |decl_info| {
            const decl = @field(states, decl_info.name);
            if (@typeInfo(@TypeOf(decl)) != .@"struct") continue;
            decl.deinit(ctx);
        }
    }
};

init: *const fn (*Context) anyerror!void,
deinit: *const fn (*Context) void,
enter: *const fn (*Context) anyerror!void,
leave: *const fn (*Context) anyerror!void,
update: *const fn (*Context) anyerror!void,
render: *const fn (*Context) anyerror!void,
