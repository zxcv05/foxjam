const builtin = @import("builtin");

pub const SIZE_WIDTH = 800;
pub const SIZE_HEIGHT = 450;

/// is enscriptem
pub const is_web = builtin.os.tag == .emscripten;

/// coins per deck at start of game
pub const initial_coins = 5;

pub const max_shop_items = 4;

pub const starting_money = 10_00;
pub const work_money = 5_00;
