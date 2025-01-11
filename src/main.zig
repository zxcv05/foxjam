const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raylib");

const constants = @import("constants.zig");

const State = @import("state.zig");

var outer = std.heap.GeneralPurposeAllocator(.{}).init;
var alloc = outer.allocator();

pub fn main() !void {
    defer _ = outer.deinit();

    var state: State = .{};

    raylib.initWindow(constants.SIZE_WIDTH, constants.SIZE_HEIGHT, "minijam - fox theme");
    defer raylib.closeWindow();

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    try state.audios.init();
    defer state.audios.deinit();

    try state.sprites.init();
    defer state.sprites.deinit();

    raylib.setTargetFPS(60);
    raylib.setExitKey(.null);

    while (state.running and !raylib.windowShouldClose()) {
        const highest_active_state = state.highestActiveState();
        switch (highest_active_state) {
            State.game_flags.pause_menu => try @import("states/pause_menu.zig").update(&state),
            State.game_flags.game       => try @import("states/game.zig").update(&state),
            else => unreachable,
        }
        raylib.beginDrawing();
        raylib.clearBackground(raylib.Color.black);
        switch (highest_active_state) {
            State.game_flags.pause_menu => try @import("states/pause_menu.zig").render(&state),
            State.game_flags.game       => try @import("states/game.zig").render(&state),
            else => unreachable,
        }
        raylib.endDrawing();
    }
}
