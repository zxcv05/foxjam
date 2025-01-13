const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");

const Assets = @This();

// zxcv_pfp is a stub to show how this workflow works
// it matches "zxcv_pfp.png" and will be a 2d texture
// the type just needs to have an init fn that takes a [*:0]u8 file name

// is this overly complex? yes
// does it save me having to update three or four lines for every sprite i wanna add? also yes

zxcv_pfp: raylib.Texture2D = undefined,
click8a: raylib.Sound = undefined,

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
