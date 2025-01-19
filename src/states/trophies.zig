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

    const mouse_x = raylib.getMouseX();
    const mouse_y = raylib.getMouseY();

    var show_tooltip_for: ?trophy.Trophy.Tag = null;

    process_trophy(ctx, .orange,      off_x + center_x - pad_x * 4, off_y + center_y - pad_y * 4, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .white,       off_x + center_x - pad_x * 2, off_y + center_y - pad_y * 4, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .black,       off_x + center_x + pad_x * 0, off_y + center_y - pad_y * 4, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .bat,         off_x + center_x + pad_x * 2, off_y + center_y - pad_y * 4, mouse_x, mouse_y, &show_tooltip_for);

    process_trophy(ctx, .fennec,      off_x + center_x - pad_x * 3, off_y + center_y - pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .sand,        off_x + center_x - pad_x * 1, off_y + center_y - pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .corsac,      off_x + center_x + pad_x * 1, off_y + center_y - pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .robin,       off_x + center_x + pad_x * 3, off_y + center_y - pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);

    process_trophy(ctx, .fire,        off_x + center_x - pad_x * 4, off_y + center_y + pad_y * 0, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .@"8bit",     off_x + center_x - pad_x * 2, off_y + center_y + pad_y * 0, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .news,        off_x + center_x + pad_x * 0, off_y + center_y + pad_y * 0, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .unfinished,  off_x + center_x + pad_x * 2, off_y + center_y + pad_y * 0, mouse_x, mouse_y, &show_tooltip_for);

    process_trophy(ctx, .umbryan,     off_x + center_x - pad_x * 3, off_y + center_y + pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .orange,      off_x + center_x - pad_x * 1, off_y + center_y + pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .orange,      off_x + center_x + pad_x * 1, off_y + center_y + pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);
    process_trophy(ctx, .orange,      off_x + center_x + pad_x * 3, off_y + center_y + pad_y * 2, mouse_x, mouse_y, &show_tooltip_for);

    // zig fmt: on

    if (show_tooltip_for) |fox| {
        const text = trophy.get_description_for(fox);
        const x = if (mouse_x <= constants.SIZE_WIDTH / 2) mouse_x + 24 else mouse_x - raylib.measureText(text, 24) - 8;

        raylib.drawText(text, x + 3, mouse_y + 3, 24, raylib.Color.black);
        raylib.drawText(text, x, mouse_y, 24, raylib.Color.white);
    }
}

pub fn process_trophy(ctx: *Context, comptime fox: trophy.Trophy.Tag, x: comptime_int, y: comptime_int, mouse_x: i32, mouse_y: i32, tooltip: *?trophy.Trophy.Tag) void {
    const tint = if (ctx.trophy_case.displays.getAssertContains(fox)) raylib.Color.white else raylib.Color.dark_gray;
    const texture = trophy.get_texture_for(ctx, fox);

    const width_diff = @divTrunc(texture.width - 128, 2);
    const height_diff = texture.height - 180;

    const start_x = x - width_diff;
    const start_y = y - height_diff;

    if (mouse_x >= start_x and mouse_x <= start_x + texture.width and
        mouse_y >= start_y and mouse_y <= start_y + texture.height and
        ctx.trophy_case.displays.getAssertContains(fox))
        tooltip.* = fox;

    raylib.drawTexture(texture, start_x, start_y, tint);
}
