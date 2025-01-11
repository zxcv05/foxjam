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

    // Texture loading code has to be after initWindow, will segfault if not
    try state.sprites.init();
    defer state.sprites.deinit();

    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        try update(&state);
        try render(&state);
    }
}

fn update(state: *State) !void {
    _ = state;
}

fn render(state: *State) !void {
    raylib.beginDrawing();
    defer raylib.endDrawing();

    raylib.clearBackground(raylib.Color.black);
    raylib.drawText("yippie", 0, 0, 32, raylib.Color.white);

    raylib.drawTexture(state.sprites.zxcv_pfp, 64, 64, raylib.Color.white);
}
