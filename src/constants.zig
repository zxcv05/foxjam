const builtin = @import("builtin");

pub const SIZE_WIDTH = 900;
pub const SIZE_HEIGHT = 600;

/// is enscriptem
pub const is_web = builtin.os.tag == .emscripten;

/// coins per deck at start of game
pub const initial_coins = 5;

pub const max_shop_items = 4;

// v units are still cents / $0.01 v //
pub const starting_money = 10_00;

pub const work_money_min = 15;
pub const work_money_max = 40;

pub const fox_texture_width = 96;
pub const fox_texture_height = 104;
