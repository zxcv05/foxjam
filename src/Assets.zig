const std = @import("std");
const raylib = @import("raylib");

const Context = @import("Context.zig");
const constants = @import("constants.zig");

const Assets = @This();

coin: raylib.Sound = undefined,
click: raylib.Sound = undefined,
coin_bad: raylib.Sound = undefined,
click_bad: raylib.Sound = undefined,

burger: raylib.Texture2D = undefined,

coin_01: raylib.Texture2D = undefined,
coin_02: raylib.Texture2D = undefined,
coin_03: raylib.Texture2D = undefined,
coin_04: raylib.Texture2D = undefined,
coin_05: raylib.Texture2D = undefined,
coin_06: raylib.Texture2D = undefined,
coin_07: raylib.Texture2D = undefined,
coin_08: raylib.Texture2D = undefined,

/// loads all the assets in place
pub fn init(this: *Assets) !void {
    if (constants.is_web) return try this.init_emscripten();

    var buffer: [128]u8 = undefined;

    const res_dir = try std.fs.cwd().openDir("res", .{ .iterate = true });
    var res_files = res_dir.iterate();

    const fields = @typeInfo(Assets).@"struct".fields;

    inline for (fields) |field| {
        defer res_files.reset();

        const file_name = while (try res_files.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, field.name)) continue;

            break entry.name;
        } else return error.CouldntFindTextureFile;

        const file_path = try std.fmt.bufPrintZ(buffer[0..], "res/{s}", .{file_name});
        this.load_asset(field.name, file_path);
    }
}

/// loads all the assets in place, emscripten specific
fn init_emscripten(this: *Assets) !void {
    var buffer: [128]u8 = undefined;

    const res_list = @embedFile("res.txt");
    const entry_count = comptime std.mem.count(u8, res_list, "\n");

    const files = comptime split: {
        var files: [entry_count][]const u8 = undefined;
        var files_index: comptime_int = 0;

        var start: comptime_int = 0;
        for (res_list[0..], 0..) |chr, index| {
            if (chr != '\n') continue;

            defer files_index += 1;
            defer start = index + 1;
            files[files_index] = res_list[start..index];
        }

        std.debug.assert(files_index == entry_count);
        break :split files;
    };

    const fields = @typeInfo(Assets).@"struct".fields;

    inline for (fields) |field| {
        const file_name = for (files) |file| {
            if (!std.mem.startsWith(u8, file, field.name)) continue;
            break file;
        } else return error.CouldntFindTextureFile;

        const file_path = try std.fmt.bufPrintZ(buffer[0..], "res/{s}", .{file_name});
        this.load_asset(field.name, file_path);
    }
}

/// load a single asset in place
fn load_asset(this: *Assets, comptime field: [:0]const u8, file_path: [:0]const u8) void {
    const asset: @FieldType(Assets, field) = .init(file_path);

    const field_ptr = &@field(this, field);
    field_ptr.* = asset;
}

/// unloads all the assets
pub fn deinit(this: Assets) void {
    const fields = @typeInfo(Assets).@"struct".fields;

    inline for (fields) |field| {
        @field(this, field.name).unload();
    }
}

pub inline fn play_sound(assets: *Assets, comptime name: []const u8) void {
    const ctx: *Context = @alignCast(@fieldParentPtr("assets", assets));
    if (!ctx.settings.audio_muted) @field(assets, name).play();
}
