const builtin = @import("builtin");

pub const SIZE_WIDTH = 800;
pub const SIZE_HEIGHT = 450;

/// is enscriptem
pub const is_web = builtin.os.tag == .emscripten;
