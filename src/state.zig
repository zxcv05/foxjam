//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const Audios = @import("audios.zig");
const Sprites = @import("sprites.zig");

audios: Audios = .{},
sprites: Sprites = .{},
