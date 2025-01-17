const builtin = @import("builtin");

pub const SIZE_WIDTH = 800;
pub const SIZE_HEIGHT = 450;

/// is enscriptem
pub const is_web = builtin.os.tag == .emscripten;

/// coins per deck at start of game
pub const initial_coins = 25;
