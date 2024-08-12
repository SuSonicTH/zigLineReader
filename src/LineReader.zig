const std = @import("std");
const MemMapper = @import("MemMapper").MemMapper;

const LineReaderError = error{
    OptionError,
};
pub const Options = struct {
    size: usize = 4096,
    includeEol: bool = false,
};

pub const LineReader = struct {
    reader: std.fs.File.Reader,
    allocator: std.mem.Allocator,
    size: usize,
    read_size: usize,
    buffer: []u8,
    start: usize = 0,
    next: usize = 0,
    end: usize = 0,
    eof: bool = false,
    includeEol: bool,

    pub fn init(reader: std.fs.File.Reader, allocator: std.mem.Allocator, options: Options) !LineReader {
        if (options.size == 0) {
            return LineReaderError.OptionError;
        }
        var read_size: usize = options.size;
        if (read_size == 0) {
            read_size = 4096;
        }
        const alloc_size = read_size * 2;
        var line_reader: LineReader = .{
            .reader = reader,
            .allocator = allocator,
            .size = alloc_size,
            .read_size = read_size,
            .buffer = try allocator.alloc(u8, alloc_size),
            .includeEol = options.includeEol,
        };
        errdefer free(&line_reader);
        _ = try line_reader.fillBuffer();
        return line_reader;
    }

    pub fn free(self: *LineReader) void {
        self.allocator.free(self.buffer);
    }

    pub fn readLine(self: *LineReader) !?[]const u8 {
        var pos: usize = 0;
        var eol_characters: usize = 0;
        self.start = self.next;

        if (self.start > self.end) {
            return null;
        }

        var window = self.buffer[self.start..self.end];
        while (true) {
            if (pos == window.len) {
                if (try self.fillBuffer() == 0) {
                    if (pos == 0) {
                        return null;
                    }
                    break;
                }
                window = self.buffer[self.start..self.end];
            }
            const current = window[pos];
            if (current == '\r') {
                eol_characters = 1;
                if (pos == window.len - 1) {
                    if (try self.fillBuffer() == 0) {
                        break;
                    }
                    window = self.buffer[self.start..self.end];
                }
                if (window[pos + 1] == '\n') {
                    eol_characters = 2;
                }
                break;
            } else if (current == '\n') {
                eol_characters = 1;
                break;
            }
            pos += 1;
        }
        self.next = self.start + pos + eol_characters;
        if (self.includeEol) {
                return self.buffer[self.start .. self.start + pos + eol_characters];
        }else {
            return self.buffer[self.start .. self.start + pos];
        }
    }

    fn fillBuffer(self: *LineReader) !usize {
        if (self.eof) {
            return 0;
        }

        var space: usize = self.size - self.end;
        if (space < self.read_size) {
            if (self.start > 0) {
                std.mem.copyBackwards(u8, self.buffer, self.buffer[self.start..self.end]);
                self.end = self.end - self.start;
                self.start = 0;
                space = self.size - self.end;
            }
            if (space < self.read_size) {
                self.size += self.read_size;
                self.buffer = try self.allocator.realloc(self.buffer, self.size);
            }
        }
        const read = try self.reader.read(self.buffer[self.end .. self.end + self.read_size]);
        if (read < self.read_size) {
            self.eof = true;
        }
        self.end += read;
        return read;
    }
};

test "init" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 43 });
    defer line_reader.free();

    try testing.expectEqual(0, line_reader.start);
    try testing.expectEqual(43, line_reader.end);
    try testing.expectEqual(43, line_reader.read_size);
    try testing.expectEqual(86, line_reader.size);

    try testing.expectEqualStrings(test_lf_txt, line_reader.buffer[line_reader.start..line_reader.end]);
}

fn expectLinesMatching(line_reader: *LineReader) !void {
    try testing.expectEqualStrings("The 1st line", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "read lines all in buffer" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.free();
    try expectLinesMatching(&line_reader);
}

test "read lines partial lines in buffer" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 1 });
    defer line_reader.free();

    try expectLinesMatching(&line_reader);
    try testing.expectEqual(null, try line_reader.readLine());
    try testing.expectEqual(16, line_reader.size);
}

test "read lines no last eol" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.free();
    try expectLinesMatching(&line_reader);
}

test "read lines with cr as eol" {
    try test_init();
    const file = try open_file("test/test_cr.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.free();
    try expectLinesMatching(&line_reader);
}

test "read lines with crlf as eol" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.free();
    try expectLinesMatching(&line_reader);
}

test "read lines with includeEol crlf at end" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30, .includeEol = true});
    defer line_reader.free();

    try testing.expectEqualStrings("The 1st line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "read lines with includeEol has lf at end" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 , .includeEol = true});
    defer line_reader.free();

    try testing.expectEqualStrings("The 1st line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
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
