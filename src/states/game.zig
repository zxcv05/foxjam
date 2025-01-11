const raylib = @import("raylib");
const State  = @import("../state.zig");

pub fn update(state: *State) !void {
    if (raylib.isMouseButtonPressed(.left)) {
        raylib.playSound(state.audios.click8a);
    }
    if (raylib.isKeyPressed(.escape)) {
        state.activateState(State.game_flags.pause_menu);
    }
}
pub fn render(state: *State) !void {
    raylib.drawText("yippie", 0, 0, 32, raylib.Color.white);
    raylib.drawTexture(state.sprites.zxcv_pfp, 64, 64, raylib.Color.white);
}
