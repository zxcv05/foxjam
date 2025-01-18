const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const constants = @import("constants.zig");

const Context = @import("Context.zig");
const State = @import("states/State.zig");

var outer = std.heap.GeneralPurposeAllocator(.{}).init;
var alloc = outer.allocator();

pub fn main() !void {
    defer _ = outer.deinit();

    var ctx: Context = .{
        .allocator = alloc,
    };

    raylib.initWindow(constants.SIZE_WIDTH, constants.SIZE_HEIGHT, "minijam - fox theme");
    defer raylib.closeWindow();

    raygui.guiLoadStyle("res/style_dark.rgs");
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, 32);

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    try ctx.assets.init();
    defer ctx.assets.deinit();

    raylib.setTargetFPS(60);
    raylib.setExitKey(.null);

    try State.states.init(&ctx);
    defer State.states.deinit(&ctx);

    try ctx.driver.enter(&ctx);

    while (ctx.running and !raylib.windowShouldClose()) {
        if (raylib.isKeyPressed(.h) and ctx.driver != &State.states.Help) try ctx.switch_driver(&State.states.Help);
        if (raylib.isKeyPressed(.i) and ctx.driver != &State.states.Stats) try ctx.switch_driver(&State.states.Stats);

        try ctx.driver.update(&ctx);

        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.black);

        try ctx.driver.render(&ctx);
    }
}
