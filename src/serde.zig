const std = @import("std");

pub fn serialize(root: anytype, writer: std.io.AnyWriter) !void {
    const Root = @TypeOf(root);

    var zlib = try std.compress.zlib.compressor(writer, .{ .level = .level_7 });
    try zlib.writer().writeAll(std.mem.asBytes(&@field(Root, "SAVE_ID")));

    try root.serialize(zlib.writer().any());
    try zlib.flush();
    try zlib.finish();
}

pub fn deserialize(Root: type, alloc: std.mem.Allocator, reader: std.io.AnyReader) !Root {
    var zlib = std.compress.zlib.decompressor(reader);

    var save_id: @TypeOf(@field(Root, "SAVE_ID")) = undefined;
    _ = try zlib.reader().readAll(std.mem.asBytes(&save_id));

    if (save_id != @field(Root, "SAVE_ID")) return error.IncompatibleSave;

    return try Root.deserialize(alloc, zlib.reader().any());
}

pub fn write(root: anytype, to: std.io.AnyWriter) !void {
    const Root = @TypeOf(root);
    const root_info: std.builtin.Type = @typeInfo(Root);

    switch (root_info) {
        .@"opaque",
        .@"anyframe",
        .@"fn",
        .enum_literal,
        .error_set,
        .error_union,
        .frame,
        .noreturn,
        .null,
        .type,
        .undefined,
        .comptime_int,
        .comptime_float,
        .void,
        => @compileError("Can't write data with type of \"" ++ @typeName(Root) ++ "\""),

        .array => {
            try to.writeAll(std.mem.sliceAsBytes(root[0..]));
        },

        .@"enum" => |info| {
            const tag: info.tag_type = @intFromEnum(root);
            try to.writeAll(std.mem.asBytes(&tag));
        },

        .@"struct", .@"union" => {
            if (@hasDecl(Root, "serialize"))
                try root.serialize(to)
            else
                try to.writeAll(std.mem.asBytes(&root));
        },

        .optional => {
            if (root) |root_not_null| {
                try to.writeAll(&.{1});
                try to.writeAll(std.mem.asBytes(&root_not_null));
            } else try to.writeAll(&.{0});
        },

        .pointer => |info| {
            switch (info.size) {
                .many, .c => @compileError("Unsupported pointer size"),
                .one => {
                    std.log.warn("Serializing a pointer: {*}", .{root});
                    try write(root.*, to);
                },
                .slice => {
                    try write(root.len, to);
                    try to.writeAll(std.mem.sliceAsBytes(root));
                },
            }
        },

        .bool,
        .int,
        .float,
        .vector,
        => {
            try to.writeAll(std.mem.asBytes(&root));
        },
    }
}

pub fn read(Root: type, alloc: ?std.mem.Allocator, from: std.io.AnyReader) !Root {
    const root_info: std.builtin.Type = @typeInfo(Root);

    switch (root_info) {
        .@"opaque",
        .@"anyframe",
        .@"fn",
        .enum_literal,
        .error_set,
        .error_union,
        .frame,
        .noreturn,
        .null,
        .type,
        .undefined,
        .comptime_float,
        .comptime_int,
        .void,
        => @compileError("Can't read data with type of \"" ++ @typeName(Root) ++ "\""),

        .array => |info| {
            var array: [info.len]info.child = undefined;
            if (try from.readAll(std.mem.sliceAsBytes(array[0..])) != @sizeOf(info.child) * info.len) return error.EndOfStream;
            return array;
        },

        .@"enum" => |info| {
            var tag: info.tag_type = undefined;
            if (try from.readAll(std.mem.asBytes(&tag)) != @sizeOf(info.tag_type)) return error.EndOfStream;
            return @enumFromInt(tag);
        },

        .@"struct", .@"union" => {
            if (@hasDecl(Root, "serialize")) {
                if (alloc) |allocator| return try Root.deserialize(allocator, from);

                return error.NeedAllocator;
            } else {
                var root: Root = undefined;
                if (try from.readAll(std.mem.asBytes(&root)) != @sizeOf(Root)) return error.EndOfStream;
                return root;
            }
        },

        .optional => |info| {
            const has_value = try from.readByte();
            if (has_value == 0) return null;

            var root: info.child = undefined;
            if (try from.readAll(std.mem.asBytes(&root)) != @sizeOf(info.child)) return error.EndOfStream;
            return root;
        },

        .pointer => |info| {
            switch (info.size) {
                .many, .c => @compileError("Unsupported pointer size"),
                .one => {
                    if (alloc) |allocator| {
                        std.log.warn("Deserializing a pointer, make sure that the original memory was alloc.create()'d", .{});
                        const root = try allocator.create(info.child);

                        if (try from.readAll(std.mem.asBytes(root)) != @sizeOf(info.child)) return error.EndOfStream;
                        return root;
                    } else return error.NeedAllocator;
                },
                .slice => {
                    if (alloc) |allocator| {
                        const length = try from.readInt(usize, .big);
                        const root = try allocator.alloc(info.child, length);

                        if (try from.readAll(std.mem.asBytes(root)) != @sizeOf(info.child) * length) return error.EndOfStream;
                        return root;
                    } else return error.NeedAllocator;
                },
            }
        },

        .int,
        .float,
        => {
            const size = @sizeOf(Root);
            var bytes: [size]u8 = undefined;

            if (try from.readAll(bytes[0..]) != size) return error.EndOfStream;
            return std.mem.bytesToValue(Root, bytes[0..]);
        },

        .bool => {
            return try from.readByte() > 0;
        },

        .vector => |info| {
            var root: Root = undefined;
            if (try from.readAll(std.mem.asBytes(&root)) != @sizeOf(info.child) * info.len) return error.EndOfStream;
            return root;
        },
    }
}

test {
    const TestEnum = enum { a, b, c };

    const TestStruct = packed struct(u16) {
        a: u1,
        b: u7,
        c: u8,
    };

    const TestUnion = union(enum) {
        a: u8,
        b: u16,
        c: u32,
    };

    const TestStructCustom = struct {
        a: u8,
        b: u8,

        pub fn serialize(this: *const @This(), writer: std.io.AnyWriter) !void {
            try write(this.b, writer);
            try write(this.a, writer);
        }

        pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !@This() {
            const b = try read(u8, alloc, reader);
            const a = try read(u8, alloc, reader);

            return .{ .a = a, .b = b };
        }
    };

    const test_enum_a: TestEnum = .a;
    const test_enum_b: TestEnum = .b;

    const test_struct: TestStruct = .{
        .a = 1,
        .b = 0b1010101,
        .c = 0x55,
    };

    const test_union_a: TestUnion = .{ .a = 0x55 };
    const test_union_b: TestUnion = .{ .b = 0x6677 };

    const test_struct_custom: TestStructCustom = .{
        .a = 0x12,
        .b = 0x89,
    };

    const test_array: [4]u8 = .{ 1, 2, 3, 4 };
    const test_optional_value: ?u8 = 0x50;
    const test_optional_null: ?u8 = null;
    const test_int: u32 = 0x12345678;
    const test_float: f64 = 1234.5678;
    const test_bool_true: bool = true;
    const test_bool_false: bool = false;
    const test_vector: @Vector(4, u8) = .{ 1, 2, 3, 4 };

    var buffer: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(buffer[0..]);

    const writer = fbs.writer().any();
    const reader = fbs.reader().any();

    try write(test_enum_a, writer);
    try write(test_enum_b, writer);
    try write(test_struct, writer);
    try write(test_union_a, writer);
    try write(test_union_b, writer);
    try write(test_struct_custom, writer);
    try write(test_array, writer);
    try write(test_optional_value, writer);
    try write(test_optional_null, writer);
    try write(test_int, writer);
    try write(test_float, writer);
    try write(test_bool_true, writer);
    try write(test_bool_false, writer);
    try write(test_vector, writer);
    try write(void{}, writer);

    fbs.reset();

    try std.testing.expectEqual(test_enum_a, try read(TestEnum, std.testing.allocator, reader));
    try std.testing.expectEqual(test_enum_b, try read(TestEnum, std.testing.allocator, reader));
    try std.testing.expectEqual(test_struct, try read(TestStruct, std.testing.allocator, reader));
    try std.testing.expectEqual(test_union_a, try read(TestUnion, std.testing.allocator, reader));
    try std.testing.expectEqual(test_union_b, try read(TestUnion, std.testing.allocator, reader));
    try std.testing.expectEqual(test_struct_custom, try read(TestStructCustom, std.testing.allocator, reader));
    try std.testing.expectEqual(test_array, try read([4]u8, std.testing.allocator, reader));
    try std.testing.expectEqual(test_optional_value, try read(?u8, std.testing.allocator, reader));
    try std.testing.expectEqual(test_optional_null, try read(?u8, std.testing.allocator, reader));
    try std.testing.expectEqual(test_int, try read(u32, std.testing.allocator, reader));
    try std.testing.expectEqual(test_float, try read(f64, std.testing.allocator, reader));
    try std.testing.expectEqual(test_bool_true, try read(bool, std.testing.allocator, reader));
    try std.testing.expectEqual(test_bool_false, try read(bool, std.testing.allocator, reader));
    try std.testing.expectEqual(test_vector, try read(@Vector(4, u8), std.testing.allocator, reader));
}
