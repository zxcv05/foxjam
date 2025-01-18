const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const Context = @import("../Context.zig");
const constants = @import("../constants.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

pub fn init(ctx: *Context) !void {
    _ = ctx;
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
}

pub fn update(ctx: *Context) !void {
    if (raylib.isKeyPressed(.escape))
        try ctx.switch_driver(&State.states.Game);
}

pub fn render(ctx: *Context) !void {
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    raylib.drawText("Paused", constants.SIZE_WIDTH / 2 - @divTrunc(raylib.measureText("Paused", 48), 2), 24, 48, text_color);

    if (raygui.guiButton(.{ .x = 10, .y = 10, .width = 100, .height = 50 }, "Reset") > 0) {
        const allocator = ctx.allocator;

        ctx.deinit();
        ctx.* = try .init(allocator);
    }

    if (raygui.guiButton(.{ .x = constants.SIZE_WIDTH / 2 - 80, .width = 160, .height = 50, .y = 180 }, "Go back") > 0)
        try ctx.switch_driver(&State.states.Game);

    if (raygui.guiButton(.{ .x = constants.SIZE_WIDTH / 2 - 80, .width = 160, .height = 50, .y = 250 }, "Help") > 0)
        try ctx.switch_driver(&State.states.Help);

    if (raygui.guiButton(.{ .x = constants.SIZE_WIDTH / 2 - 80, .width = 160, .height = 50, .y = 320 }, "Exit") > 0)
        ctx.running = false;
}
