const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const State = @import("State.zig");
const Context = @import("../Context.zig");
const constants = @import("../constants.zig");
const trophy = @import("../trophy.zig");

pub const interface = State{
    .init = &init,
    .deinit = &deinit,
    .enter = &enter,
    .leave = &leave,
    .update = &update,
    .render = &render,
};

var just_entered: bool = false;

pub fn init(ctx: *Context) !void {
    _ = ctx;
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
}

pub fn enter(ctx: *Context) !void {
    _ = ctx;
    just_entered = true;
}

pub fn leave(ctx: *Context) !void {
    _ = ctx;
}

pub fn update(ctx: *Context) !void {
    if (raylib.isKeyPressed(.escape) or (raylib.isKeyPressed(.t) and !just_entered))
        try ctx.switch_driver(&State.states.Game);

    just_entered = false;
}

pub fn render(ctx: *Context) !void {
    raylib.clearBackground(raylib.Color.black);
    const text_color = raylib.getColor(@bitCast(raygui.guiGetStyle(.default, raygui.GuiControlProperty.base_color_pressed)));

    raylib.drawText("Trophies", constants.SIZE_WIDTH / 2 - @divTrunc(raylib.measureText("Trophies", 48), 2), 24, 48, text_color);

    // these are manually tweaked to perfection
    const pad_x = 105;
    const pad_y = 57;

    const off_x = -10;
    const off_y = -6;

    const center_x = constants.SIZE_WIDTH / 2;
    const center_y = constants.SIZE_HEIGHT / 2;

    // zig fmt: off

    draw_fox(ctx, .orange,   off_x + center_x - pad_x * 4, off_y + center_y - pad_y * 4);
    draw_fox(ctx, .white,    off_x + center_x - pad_x * 2, off_y + center_y - pad_y * 4);
    draw_fox(ctx, .black,    off_x + center_x + pad_x * 0, off_y + center_y - pad_y * 4);
    draw_fox(ctx, .bat,      off_x + center_x + pad_x * 2, off_y + center_y - pad_y * 4);

    draw_fox(ctx, .fennec,   off_x + center_x - pad_x * 3, off_y + center_y - pad_y * 2);
    draw_fox(ctx, .tibetan,  off_x + center_x - pad_x * 1, off_y + center_y - pad_y * 2);
    draw_fox(ctx, .corsac,   off_x + center_x + pad_x * 1, off_y + center_y - pad_y * 2);
    draw_fox(ctx, .robin,    off_x + center_x + pad_x * 3, off_y + center_y - pad_y * 2);

    draw_fox(ctx, .fire,     off_x + center_x - pad_x * 4, off_y + center_y + pad_y * 0);
    draw_fox(ctx, .@"8bit",  off_x + center_x - pad_x * 2, off_y + center_y + pad_y * 0);
    draw_fox(ctx, .orange,   off_x + center_x + pad_x * 0, off_y + center_y + pad_y * 0);
    draw_fox(ctx, .orange,   off_x + center_x + pad_x * 2, off_y + center_y + pad_y * 0);

    draw_fox(ctx, .orange,   off_x + center_x - pad_x * 3, off_y + center_y + pad_y * 2);
    draw_fox(ctx, .orange,   off_x + center_x - pad_x * 1, off_y + center_y + pad_y * 2);
    draw_fox(ctx, .orange,   off_x + center_x + pad_x * 1, off_y + center_y + pad_y * 2);
    draw_fox(ctx, .orange,   off_x + center_x + pad_x * 3, off_y + center_y + pad_y * 2);

    // zig fmt: on
}

pub fn draw_fox(ctx: *Context, comptime fox: trophy.Trophy.Tag, x: comptime_int, y: comptime_int) void {
    const tint = if (ctx.trophy_case.displays.getAssertContains(fox)) raylib.Color.white else raylib.Color.dark_gray;
    const texture = trophy.get_texture_for(ctx, fox);

    const width_diff = @divTrunc(texture.width - 128, 2);
    const height_diff = texture.height - 180;

    raylib.drawTexture(texture, x - width_diff, y - height_diff, tint);
}
