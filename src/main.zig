const std = @import("std");
const raylib = @import("raylib");
const raygui = @import("raygui");

const constants = @import("constants.zig");
const Context = @import("Context.zig");
const State = @import("states/State.zig");
const serde = @import("serde.zig");

var outer = std.heap.GeneralPurposeAllocator(.{}).init;
var alloc = outer.allocator();

pub fn main() !void {
    defer _ = outer.deinit();

    const config_dir_path = try std.fs.getAppDataDir(alloc, "foxjam");
    defer alloc.free(config_dir_path);
    std.fs.makeDirAbsolute(config_dir_path) catch {};

    var config_dir = try std.fs.openDirAbsolute(config_dir_path, .{});
    defer config_dir.close();

// the below code breaks my code, so bye bye :3
// if i read the code correctly, what you need to do fix it is make it so the shop items and refreshes also get serialized
//    var ctx = get_ctx: {
//        const file = config_dir.openFile("ctx.sav", .{ .mode = .read_only }) catch {
//            break :get_ctx try Context.init(alloc);
//        };
//        defer file.close();
//
//        break :get_ctx serde.deserialize(Context, alloc, file.reader().any()) catch |e| {
//            std.log.err("failed loading ctx: {s}", .{@errorName(e)});
//            break :get_ctx try Context.init(alloc);
//        };
//    };
    var ctx = try Context.init(alloc);
    defer ctx.deinit();

    raylib.initWindow(constants.SIZE_WIDTH, constants.SIZE_HEIGHT, "minijam - fox theme");
    defer raylib.closeWindow();

    raygui.guiLoadStyle("res/style_dark.rgs");
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_size, 32);
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_alignment_vertical, @intFromEnum(raygui.GuiTextAlignmentVertical.text_align_middle));
    raygui.guiSetStyle(.default, raygui.GuiDefaultProperty.text_wrap_mode, @intFromEnum(raygui.GuiTextWrapMode.text_wrap_word));

    raylib.initAudioDevice();
    defer raylib.closeAudioDevice();

    try ctx.assets.init();
    defer ctx.assets.deinit();

    raylib.setTargetFPS(60);
    raylib.setExitKey(.null);

    try State.states.init(&ctx);
    defer State.states.deinit(&ctx);

    defer _ = blk: {
        const file = config_dir.createFile("ctx.sav", .{}) catch |e| {
            std.log.err("failed to open ctx.sav: {s}", .{@errorName(e)});
            break :blk;
        };

        defer file.close();
        serde.serialize(ctx, file.writer().any()) catch |e| std.log.err("failed to save ctx: {s}", .{@errorName(e)});
    };

    try ctx.driver.enter(&ctx);

    while (ctx.running and !raylib.windowShouldClose()) {
        if (raylib.isKeyPressed(.h) and ctx.driver != &State.states.Help) try ctx.switch_driver(&State.states.Help);
        if (raylib.isKeyPressed(.i) and ctx.driver != &State.states.Stats) try ctx.switch_driver(&State.states.Stats);

        try ctx.driver.update(&ctx);

        raylib.beginDrawing();
        defer raylib.endDrawing();
        raylib.clearBackground(raylib.Color.black);

        try ctx.driver.render(&ctx);
    }
}

test {
    std.testing.refAllDecls(serde);
}
