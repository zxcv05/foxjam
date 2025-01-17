const std = @import("std");
const raylib = @import("raylib");

const State = @import("State.zig");
const Context = @import("../Context.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    _ = allocator;
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Entered PauseMenu state\n", .{});
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Left PauseMenu state\n", .{});
}

pub fn update(ctx: *Context) !void {
    if (raylib.isKeyPressed(.escape)) {
        try ctx.switch_driver(&State.states.Game);
    }

    if (raylib.isKeyPressed(.enter)) {
        ctx.running = false;
    }
}

pub fn render(ctx: *Context) !void {
    _ = ctx;

    raylib.drawText(
        \\pause menu :3
        \\
        \\press escape to go back to game
        \\press enter to exit game
    , 0, 0, 32, raylib.Color.white);
}
