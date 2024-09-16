const std = @import("std");
const LineReaderAnyReader = @import("LineReaderAnyReader.zig");
const LineReaderMemoryMapped = @import("LineReaderMemoryMapped.zig");

pub const LineReaderError = error{
    OptionError,
};
pub const Options = struct {
    size: usize = 4096,
    includeEol: bool = false,
};

pub const LineReader = union(enum) {
    reader: LineReaderAnyReader,
    memmapped: LineReaderMemoryMapped,

    pub fn initReader(reader: std.io.AnyReader, allocator: std.mem.Allocator, options: Options) !LineReader {
        return .{ .reader = try LineReaderAnyReader.init(reader, allocator, options) };
    }

    pub fn initFile(file: *std.fs.File, allocator: std.mem.Allocator, options: Options) !LineReader {
        return .{ .memmapped = try LineReaderMemoryMapped.init(file, allocator, options) };
    }

    pub fn deinit(self: *LineReader) void {
        switch (self.*) {
            inline else => |*lineReader| lineReader.deinit(),
        }
    }

    pub fn readLine(self: *LineReader) !?[]const u8 {
        switch (self.*) {
            inline else => |*lineReader| return try lineReader.readLine(),
        }
    }
};

test "LineReaderAnyReader: init" {
    try test_init();
    var file = try open_file("test/test_lf.txt");
    defer file.close();

    var lineReader = try LineReaderAnyReader.init(file.reader().any(), hpa, .{ .size = 43 });
    defer lineReader.deinit();

    try testing.expectEqual(0, lineReader.start);
    try testing.expectEqual(43, lineReader.end);
    try testing.expectEqual(43, lineReader.read_size);
    try testing.expectEqual(86, lineReader.size);

    try testing.expectEqualStrings(test_lf_txt, lineReader.buffer[lineReader.start..lineReader.end]);
}

fn expectLinesMatching(lineReader: anytype) !void {
    try testing.expectEqualStrings("The 1st line", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The middle line", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try lineReader.readLine()).?);
    try testing.expectEqual(null, try lineReader.readLine());
}

test "LineReader: read lines all in buffer" {
    try test_init();
    var file = try open_file("test/test_lf.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30 });
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "LineReaderAnyReader: read lines partial lines in buffer" {
    try test_init();
    var file = try open_file("test/test_lf.txt");
    defer file.close();

    var lineReader = try LineReaderAnyReader.init(file.reader().any(), hpa, .{ .size = 1 });
    defer lineReader.deinit();

    try expectLinesMatching(&lineReader);
    try testing.expectEqual(null, try lineReader.readLine());
    try testing.expectEqual(16, lineReader.size);
}

test "LineReader: read lines no last eol" {
    try test_init();
    var file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30 });
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "LineReader: read lines with cr as eol" {
    try test_init();
    var file = try open_file("test/test_cr.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30 });
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "LineReader: read lines with crlf as eol" {
    try test_init();
    var file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30 });
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "LineReader: read lines with includeEol crlf at end" {
    try test_init();
    var file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30, .includeEol = true });
    defer lineReader.deinit();

    try testing.expectEqualStrings("The 1st line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The middle line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The last line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqual(null, try lineReader.readLine());
}

test "LineReader: read lines with includeEol has lf at end" {
    try test_init();
    var file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var lineReader = try LineReader.initReader(file.reader().any(), hpa, .{ .size = 30, .includeEol = true });
    defer lineReader.deinit();

    try testing.expectEqualStrings("The 1st line\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The middle line\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try lineReader.readLine()).?);
    try testing.expectEqual(null, try lineReader.readLine());
}

test "MemMappedLineReader: read lines no last eol" {
    try test_init();
    var file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var lineReader = try LineReader.initFile(&file, hpa, .{});
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "MemMappedLineReader: read lines with cr as eol" {
    try test_init();
    var file = try open_file("test/test_cr.txt");
    defer file.close();

    var lineReader = try LineReader.initFile(&file, hpa, .{});
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "MemMappedLineReader: read lines with crlf as eol" {
    try test_init();
    var file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var lineReader = try LineReader.initFile(&file, hpa, .{});
    defer lineReader.deinit();
    try expectLinesMatching(&lineReader);
}

test "MemMappedLineReader: read lines with includeEol crlf at end" {
    try test_init();
    var file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var lineReader = try LineReader.initFile(&file, hpa, .{ .includeEol = true });
    defer lineReader.deinit();

    try testing.expectEqualStrings("The 1st line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The middle line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The last line\r\n", (try lineReader.readLine()).?);
    try testing.expectEqual(null, try lineReader.readLine());
}

test "MemMappedLineReader: read lines with includeEol has lf at end" {
    try test_init();
    var file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var lineReader = try LineReader.initFile(&file, hpa, .{ .includeEol = true });
    defer lineReader.deinit();

    try testing.expectEqualStrings("The 1st line\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The middle line\n", (try lineReader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try lineReader.readLine()).?);
    try testing.expectEqual(null, try lineReader.readLine());
}

const hpa = std.heap.page_allocator;
const testing = std.testing;
const test_lf_txt =
    "The 1st line\n" ++
    "The middle line\n" ++
    "The last line\n";

const test_lf_no_last_txt =
    "The 1st line\n" ++
    "The middle line\n" ++
    "The last line";

const test_cr_txt =
    "The 1st line\r" ++
    "The middle line\r" ++
    "The last line\r";

const test_cr_lf_txt =
    "The 1st line\r\n" ++
    "The middle line\r\n" ++
    "The last line\r\n";

fn write_file(file_name: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_name, .{});
    defer file.close();
    _ = try file.write(data);
}

fn open_file(file_name: []const u8) !std.fs.File {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fs.realpath(file_name, &path_buffer);
    return try std.fs.openFileAbsolute(path, .{});
}

var test_initialized = false;
fn test_init() !void {
    if (!test_initialized) {
        test_initialized = true;
        try write_file("test/test_lf.txt", test_lf_txt);
        try write_file("test/test_cr.txt", test_cr_txt);
        try write_file("test/test_cr_lf.txt", test_cr_lf_txt);
        try write_file("test/test_lf_no_last.txt", test_lf_no_last_txt);
    }
}
