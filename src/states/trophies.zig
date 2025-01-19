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
var show_golden: bool = false;

pub fn init(ctx: *Context) !void {
    _ = ctx;
}

pub fn deinit(ctx: *Context) void {
    _ = ctx;
}

pub fn enter(ctx: *Context) !void {
    just_entered = true;
    show_golden = has_all_trophies(ctx);
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
    const pad_x = constants.fox_texture_width + 12;
    const pad_y = @divFloor(constants.fox_texture_height, 2.25);

    const off_y = -32;

    const center_x = constants.SIZE_WIDTH / 2;
    const center_y = constants.SIZE_HEIGHT / 2;

    // zig fmt: off

    const mouse_x = raylib.getMouseX();
    const mouse_y = raylib.getMouseY();

    var tooltip: ?Tooltip = null;

    process_trophy(ctx, .red,         center_x - pad_x * 4, off_y + center_y - pad_y * 5, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .arctic,      center_x - pad_x * 2, off_y + center_y - pad_y * 5, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .black,       center_x + pad_x * 1, off_y + center_y - pad_y * 5, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .fennec,      center_x + pad_x * 3, off_y + center_y - pad_y * 5, mouse_x, mouse_y, &tooltip);

    process_trophy(ctx, .sand,        center_x - pad_x * 3, off_y + center_y - pad_y * 3, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .corsac,      center_x + pad_x * 2, off_y + center_y - pad_y * 3, mouse_x, mouse_y, &tooltip);

    if (show_golden)
        process_trophy(ctx, .golden,  center_x - constants.fox_texture_width / 2, off_y + center_y - pad_y * 2, mouse_x, mouse_y, &tooltip);

    process_trophy(ctx, .real,        center_x - pad_x * 4, off_y + center_y - pad_y * 1, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .@"8bit",     center_x - pad_x * 2, off_y + center_y - pad_y * 1, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .fire,        center_x + pad_x * 1, off_y + center_y - pad_y * 1, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .unfinished,  center_x + pad_x * 3, off_y + center_y - pad_y * 1, mouse_x, mouse_y, &tooltip);

    process_trophy(ctx, .kitsune,     center_x - pad_x * 3, off_y + center_y + pad_y * 1, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .news,        center_x + pad_x * 2, off_y + center_y + pad_y * 1, mouse_x, mouse_y, &tooltip);

    process_trophy(ctx, .bat,         center_x - pad_x * 4, off_y + center_y + pad_y * 3, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .robin,       center_x - pad_x * 2, off_y + center_y + pad_y * 3, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .umbryan,     center_x + pad_x * 1, off_y + center_y + pad_y * 3, mouse_x, mouse_y, &tooltip);
    process_trophy(ctx, .dog,         center_x + pad_x * 3, off_y + center_y + pad_y * 3, mouse_x, mouse_y, &tooltip);

    // zig fmt: on

    if (tooltip) |tt| switch (tt) {
        .name => |fox| {
            const text = if (ctx.trophy_case.displays.getAssertContains(fox)) @tagName(fox) else "???";
            const x = if (mouse_x <= constants.SIZE_WIDTH / 2) mouse_x + 16 else mouse_x - raylib.measureText(text, 24) - 8;

            raylib.drawText(text, x + 2, mouse_y + 2, 24, raylib.Color.black);
            raylib.drawText(text, x, mouse_y, 24, raylib.Color.white);
        },
        .description => |fox| {
            const text = if (ctx.trophy_case.displays.getAssertContains(fox)) trophy.get_description_for(fox) else "???";
            const x = if (mouse_x <= constants.SIZE_WIDTH / 2) mouse_x + 16 else mouse_x - raylib.measureText(text, 24) - 8;

            if (fox == .golden)
                raygui.guiDrawIcon(186, center_x - 32, center_y - pad_y * 4, 4, raylib.Color.red);

            raylib.drawText(text, x + 2, mouse_y + 2, 24, raylib.Color.black);
            raylib.drawText(text, x, mouse_y, 24, raylib.Color.white);
        },
    };
}

fn process_trophy(ctx: *Context, comptime fox: trophy.Trophy.Tag, x: comptime_int, y: comptime_int, mouse_x: i32, mouse_y: i32, tooltip: *?Tooltip) void {
    const tint = if (ctx.trophy_case.displays.getAssertContains(fox)) raylib.Color.white else raylib.Color.black;
    const texture = trophy.get_texture_for(ctx, fox);

    const stand_height = 80;
    const stand_width = 128;

    const stand_x = x - (stand_width - constants.fox_texture_width) / 2;
    const stand_y = y + constants.fox_texture_height - 5;

    if (mouse_x >= x and mouse_x <= x + constants.fox_texture_width and
        mouse_y >= y and mouse_y <= y + constants.fox_texture_height)
        tooltip.* = .{ .description = fox }
    else if (mouse_x >= stand_x and mouse_x <= stand_x + stand_width and
        mouse_y >= stand_y and mouse_y <= stand_y + stand_height)
        tooltip.* = .{ .name = fox };

    raylib.drawTexture(texture, x, y, tint);
    raylib.drawTexture(ctx.assets.fox_stand, stand_x, stand_y, raylib.Color.white);
}

fn has_all_trophies(ctx: *Context) bool {
    inline for (@typeInfo(trophy.Trophy.Tag).@"enum".fields) |field_info| {
        const value: trophy.Trophy.Tag = @enumFromInt(field_info.value);
        if (comptime value == .golden) continue;

        if (!ctx.trophy_case.displays.getAssertContains(value)) return false;
    }

    return true;
}

const Tooltip = union(enum) {
    name: trophy.Trophy.Tag,
    description: trophy.Trophy.Tag,
};
