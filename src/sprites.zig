const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");

const Sprites = @This();

// zxcv_pfp is a stub to show how this workflow works
// it matches "zxcv_pfp.png" and will be a 2d texture
// the type just needs to have an init fn that takes a [*:0]u8 file name

// is this overly complex? yes
// does it save me having to update three or four lines for every sprite i wanna add? also yes

zxcv_pfp: raylib.Texture2D = undefined,

/// loads all the sprites in place
pub fn init(this: *Sprites) !void {
    if (constants.is_web) return try this.init_emscripten();

    var buffer: [128]u8 = undefined;

    const res_dir = try std.fs.cwd().openDir("res", .{ .iterate = true });
    var res_files = res_dir.iterate();

    const fields = @typeInfo(Sprites).@"struct".fields;

    inline for (fields) |field| {
        defer res_files.reset();

        const file_name = while (try res_files.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, field.name)) continue;

            break entry.name;
        } else return error.CouldntFindTextureFile;

        const file_path = try std.fmt.bufPrintZ(buffer[0..], "res/{s}", .{file_name});
        const sprite = @FieldType(Sprites, field.name).init(file_path);

        const field_ptr = &@field(this, field.name);
        field_ptr.* = sprite;
    }
}

/// loads all the sprites in place, emscripten specific
fn init_emscripten(this: *Sprites) !void {
    var buffer: [128]u8 = undefined;

    const res_list = @embedFile("res.txt");
    const entry_count = comptime std.mem.count(u8, res_list, "\n");

    const files = comptime split: {
        var files: [entry_count][]const u8 = undefined;
        var files_index: comptime_int = 0;

        var file_start: comptime_int = 0;
        var index: comptime_int = 0;
        while (index < res_list.len) : (index += 1) {
            if (res_list[index] == '\n') {
                defer files_index += 1;
                defer file_start = index + 1;

                files[files_index] = res_list[file_start..index];
            }
        }

        std.debug.assert(files_index == entry_count);

        break :split files;
    };

    const fields = @typeInfo(Sprites).@"struct".fields;

    inline for (fields) |field| {
        const file_name = for (files) |file| {
            if (!std.mem.startsWith(u8, file, field.name)) continue;
            break file;
        } else return error.CouldntFindTextureFile;

        const file_path = try std.fmt.bufPrintZ(buffer[0..], "res/{s}", .{file_name});
        const sprite = @FieldType(Sprites, field.name).init(file_path);

        const field_ptr = &@field(this, field.name);
        field_ptr.* = sprite;
    }
}

/// unloads all the sprites
pub fn deinit(this: Sprites) void {
    const fields = @typeInfo(Sprites).@"struct".fields;

    inline for (fields) |field| {
        @field(this, field.name).unload();
    }
}
