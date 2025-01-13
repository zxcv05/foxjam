const std = @import("std");
const raylib = @import("raylib");

const State = @import("State.zig");
const Context = @import("../Context.zig");

pub const interface = State{
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

pub fn enter(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Entered Game state\n", .{});
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
    std.debug.print("Left Game state\n", .{});
}

pub fn update(ctx: *Context) !void {
    if (raylib.isMouseButtonPressed(.left)) {
        raylib.playSound(ctx.assets.click8a);
    }
    if (raylib.isKeyPressed(.escape)) {
        try ctx.switch_driver(&State.states.PauseMenu);
    }
}

pub fn render(ctx: *Context) !void {
    raylib.drawText("yippie", 0, 0, 32, raylib.Color.white);
    raylib.drawTexture(ctx.assets.zxcv_pfp, 64, 64, raylib.Color.white);
}
