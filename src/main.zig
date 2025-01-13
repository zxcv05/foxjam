const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raylib");

const constants = @import("constants.zig");

const Context = @import("Context.zig");

// zig fmt: off
const states = struct {
    pub const Game      = @import("states/game.zig");
    pub const PauseMenu = @import("states/pause_menu.zig");
}; // zig fmt: on

var outer = std.heap.GeneralPurposeAllocator(.{}).init;
var alloc = outer.allocator();

pub fn main() !void {
    defer _ = outer.deinit();

    var ctx: Context = .{};

    raylib.initWindow(constants.SIZE_WIDTH, constants.SIZE_HEIGHT, "minijam - fox theme");
    defer raylib.closeWindow();

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    try ctx.assets.init();
    defer ctx.assets.deinit();

    raylib.setTargetFPS(60);
    raylib.setExitKey(.null);

    try ctx.driver.enter(&ctx);

    while (ctx.running and !raylib.windowShouldClose()) {
        try ctx.driver.update(&ctx);

        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.black);

        try ctx.driver.render(&ctx);
    }
}
