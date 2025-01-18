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
    raygui.guiLoadStyle("res/style_dark.rgs");
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
    if (raylib.isKeyPressed(.escape)) {
        ctx.running = false;
    }
}

pub fn render(ctx: *Context) !void {
    raylib.clearBackground(raylib.Color.black);
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    // centered text: x is width/2 - 2*font_size + manual_nudge
    raylib.drawText("Paused", constants.SIZE_WIDTH / 2 - 86, 32, 48, text_color);

    if (raygui.guiButton(.{ .x = constants.SIZE_WIDTH / 2 - 80, .width = 160, .height = 50, .y = 250 }, "Go back") > 0)
        try ctx.switch_driver(&State.states.Game);

    if (raygui.guiButton(.{ .x = constants.SIZE_WIDTH / 2 - 80, .width = 160, .height = 50, .y = 320 }, "Exit") > 0)
        ctx.running = false;
}
