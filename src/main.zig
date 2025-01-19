const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const constants = @import("constants.zig");
const Context = @import("Context.zig");
const State = @import("states/State.zig");
const serde = @import("serde.zig");
const trophy = @import("trophy.zig");

var outer = std.heap.GeneralPurposeAllocator(.{}).init;
var alloc = outer.allocator();

pub fn main() !void {
    defer _ = outer.deinit();

    var ctx = try Context.load(alloc);
    defer ctx.deinit();

    raylib.initWindow(constants.SIZE_WIDTH, constants.SIZE_HEIGHT, "minijam - fox theme");
    defer raylib.closeWindow();

    raygui.guiLoadStyle("res/style_dark.rgs");
    raygui.guiSetStyle(.label, raygui.GuiDefaultProperty.text_size, 24);
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, 32);
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_alignment_vertical, @intFromEnum(raygui.GuiTextAlignmentVertical.text_align_middle));
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_wrap_mode, @intFromEnum(raygui.GuiTextWrapMode.text_wrap_word));

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    try ctx.assets.init();
    defer ctx.assets.deinit();

    raylib.setTargetFPS(60);
    raylib.setExitKey(.null);

    try State.states.init(&ctx);
    defer State.states.deinit(&ctx);

    defer ctx.save() catch |e| std.log.err("Failed to save game: {s}", .{@errorName(e)});

    try ctx.driver.enter(&ctx);

    while (ctx.running and !raylib.windowShouldClose()) {
        if (raylib.isKeyPressed(.h) and ctx.driver != &State.states.Help) try ctx.switch_driver(&State.states.Help);
        if (raylib.isKeyPressed(.i) and ctx.driver != &State.states.Stats) try ctx.switch_driver(&State.states.Stats);
        if (raylib.isKeyPressed(.t) and ctx.driver != &State.states.Trophies) try ctx.switch_driver(&State.states.Trophies);

        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.drawTexture(ctx.assets.background, 0, 0, raylib.Color.white);

        try ctx.driver.update(&ctx);
        try ctx.driver.render(&ctx);

        if (ctx.trophy_case.new_unlock) |fox| {
            var buffer: [64]u8 = undefined;
            const text = std.fmt.bufPrintZ(buffer[0..], "New trophy unlocked: {s} fox", .{@tagName(fox)}) catch unreachable;

            const width: f32 = @floatFromInt(raylib.measureText(text, 24));
            const bounds: raylib.Rectangle = .{
                .x = 24,
                .y = 60,
                .width = width + 24,
                .height = 40,
            };

            raylib.drawRectangleRounded(bounds, 0.25, 4, raylib.Color.black);
            raylib.drawText(text, @intFromFloat(bounds.x + 12), @intFromFloat(bounds.y + 8), 24, raylib.Color.white);

            if (std.time.milliTimestamp() >= ctx.trophy_case.new_unlock_ts) ctx.trophy_case.new_unlock = null;
        }
    }
}

test {
    std.testing.refAllDecls(serde);
}
