const raylib = @import("raylib");
const State  = @import("../state.zig");

pub fn update(state: *State) !void {
    if (raylib.isKeyPressed(.escape)) {
        state.deactivateState(State.game_flags.pause_menu);
    }
    if (raylib.isKeyPressed(.enter)) {
        state.running = false;
    }
}
pub fn render(state: *State) !void {
    _ = state;

    raylib.drawText(
        \\pause menu :3
        \\
        \\press escape to go back to game
        \\press enter to exit game
        , 0, 0, 32, raylib.Color.white
    );
}
