const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raylib");

const constants = @import("constants.zig");

const State = @import("state.zig");

// zig fmt: off
const game_states = struct {
    pub const Game      = @import("states/game.zig");
    pub const PauseMenu = @import("states/pause_menu.zig");
}; // zig fmt: on

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

        // zig fmt: off
        try switch (highest_active_state) {
            State.game_flags.game       => game_states.Game.update(&state),
            State.game_flags.pause_menu => game_states.PauseMenu.update(&state),
            else => unreachable,
        }; // zig fmt: on

        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.black);

        // zig fmt: off
        try switch (highest_active_state) {
            State.game_flags.game       => game_states.Game.render(&state),
            State.game_flags.pause_menu => game_states.PauseMenu.render(&state),
            else => unreachable,
        }; // zig fmt: on

    }
}
