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
    _ = ctx;

    raylib.clearBackground(raylib.Color.black);
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    raylib.drawText("Help", constants.SIZE_WIDTH / 2 - @divTrunc(raylib.measureText("Help", 48), 2), 24, 48, text_color);

    raylib.drawText(
        \\ Press Escape to go back
        \\
        \\ # Global
        \\ Escape : Pause menu or "go back"
        \\ H : Show Help
        \\ I : Show Stats
        \\
        \\ # In game
        \\ Space : Flip coin
    , 20, 120, 24, text_color);
}
