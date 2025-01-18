const std = @import("std");

pub fn serialize(root: anytype, writer: std.io.AnyWriter) !void {
    var compressor = try std.compress.zlib.compressor(writer, .{ .level = .level_7 });

    if (@typeInfo(@TypeOf(root)) != .@"struct") @compileError("Can only serialize structs");
    if (@hasDecl(@TypeOf(root), "serialize"))
        try root.serialize(compressor.writer().any())
    else
        @compileError("Root must have 'serialize(root, writer) !void' function");

    try compressor.flush();
    try compressor.finish();
}

pub fn deserialize(Parent: type, alloc: std.mem.Allocator, reader: std.io.AnyReader) !Parent {
    const data = try reader.readAllAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(data);

    var data_stream = std.io.fixedBufferStream(data);
    var decompressor = std.compress.zlib.decompressor(data_stream.reader());

    if (@typeInfo(Parent) != .@"struct") @compileError("Can only serialize structs");
    if (@hasDecl(Parent, "serialize"))
        return try Parent.deserialize(alloc, decompressor.reader().any())
    else
        @compileError("Root must have 'deserialize(allocator, reader) !Root' function");
}

test "serde" {
    const TestStruct = struct {
        a: u32 = 0,
        b: bool,
        c: struct {
            d: u16 = 1,
            e: u16,
            f: []const u8,
        },

        pub fn serialize(this: @This(), writer: std.io.AnyWriter) !void {
            const b: u8 = @intFromBool(this.b);

            try writer.writeInt(u8, b, .big);
            try writer.writeInt(u16, this.c.e, .big);
            try writer.writeInt(usize, this.c.f.len, .big);
            try writer.writeAll(this.c.f);
        }

        pub fn deserialize(alloc: std.mem.Allocator, reader: std.io.AnyReader) !@This() {
            const b = try reader.readInt(u8, .big);
            const e = try reader.readInt(u16, .big);

            const f = try alloc.alloc(u8, try reader.readInt(usize, .big));
            _ = try reader.readAll(f);

            return .{ .b = b > 0, .c = .{ .e = e, .f = f } };
        }
    };

    const root: TestStruct = .{
        .b = true,
        .c = .{ .e = 69, .f = "hello world" },
    };

    var buffer: [64]u8 = undefined;
    var buf_writer = std.io.fixedBufferStream(buffer[0..]);

    try serialize(root, buf_writer.writer().any());
    buf_writer.pos = 0;

    const root_deser = try deserialize(TestStruct, std.testing.allocator, buf_writer.reader().any());
    defer std.testing.allocator.free(root_deser.c.f);

    try std.testing.expectEqualDeep(root, root_deser);
}
