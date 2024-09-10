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
        errdefer deinit(&line_reader);
        _ = try line_reader.fillBuffer();
        return line_reader;
    }

    pub fn reset(self: *LineReader) !void {
        _ = self;
        return error.Unsupported;
    }

    pub fn readAllLines(self: *LineReader, allocator: std.mem.Allocator) ![][]const u8 {
        _ = self;
        _ = allocator;
        return error.Unsupported;
    }

    pub fn deinit(self: *LineReader) void {
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
        } else {
            return self.buffer[self.start .. self.start + pos];
        }
    }

    inline fn fillBuffer(self: *LineReader) !usize {
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

pub const MemMappedLineReader = struct {
    memMapper: MemMapper,
    includeEol: bool,
    data: []u8 = undefined,
    next: usize = 0,

    pub fn init(file: std.fs.File, options: Options) !MemMappedLineReader {
        var lineReader: MemMappedLineReader = .{
            .memMapper = try MemMapper.init(file, false),
            .includeEol = options.includeEol,
        };
        errdefer lineReader.deinit();
        lineReader.data = try lineReader.memMapper.map(u8, .{});
        return lineReader;
    }

    pub fn reset(self: *MemMappedLineReader) void {
        self.next = 0;
    }

    pub fn deinit(self: *MemMappedLineReader) void {
        self.memMapper.unmap(self.data);
        self.memMapper.deinit();
    }

    pub fn readLine(self: *MemMappedLineReader) !?[]const u8 {
        const data = self.data[self.next..];
        var pos: usize = 0;
        var eol_characters: usize = 0;

        if (pos >= data.len) {
            return null;
        }

        while (pos < data.len and data[pos] != '\r' and data[pos] != '\n') {
            pos += 1;
        }
        if (pos < data.len) {
            if (data[pos] == '\r') {
                eol_characters = 1;
                if (pos + 1 < data.len and data[pos + 1] == '\n') {
                    eol_characters = 2;
                }
            } else if (data[pos] == '\n') {
                eol_characters = 1;
            }
        }
        self.next += pos + eol_characters;
        if (self.includeEol) {
            return data[0 .. pos + eol_characters];
        } else {
            return data[0..pos];
        }
    }

    pub fn readAllLines(self: *MemMappedLineReader, allocator: std.mem.Allocator) ![][]const u8 {
        var reserved: usize = 1024;
        var lines: [][]const u8 = try allocator.alloc([]u8, reserved);
        var i: usize = 0;
        while ((try self.readLine())) |line| {
            if (i == reserved) {
                reserved *= 2;
                lines = try allocator.realloc(lines, reserved);
            }
            lines[i] = line;
            i += 1;
        }
        return lines[0..i];
    }
};

test "init" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 43 });
    defer line_reader.deinit();

    try testing.expectEqual(0, line_reader.start);
    try testing.expectEqual(43, line_reader.end);
    try testing.expectEqual(43, line_reader.read_size);
    try testing.expectEqual(86, line_reader.size);

    try testing.expectEqualStrings(test_lf_txt, line_reader.buffer[line_reader.start..line_reader.end]);
}

fn expectLinesMatching(line_reader: anytype) !void {
    try testing.expectEqualStrings("The 1st line", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "LineReader: read lines all in buffer" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "LineReader: read lines partial lines in buffer" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 1 });
    defer line_reader.deinit();

    try expectLinesMatching(&line_reader);
    try testing.expectEqual(null, try line_reader.readLine());
    try testing.expectEqual(16, line_reader.size);
}

test "LineReader: read lines no last eol" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "LineReader: read lines with cr as eol" {
    try test_init();
    const file = try open_file("test/test_cr.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "LineReader: read lines with crlf as eol" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30 });
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "LineReader: read lines with includeEol crlf at end" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30, .includeEol = true });
    defer line_reader.deinit();

    try testing.expectEqualStrings("The 1st line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "LineReader: read lines with includeEol has lf at end" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try LineReader.init(file.reader(), hpa, .{ .size = 30, .includeEol = true });
    defer line_reader.deinit();

    try testing.expectEqualStrings("The 1st line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "MemMappedLineReader: read lines no last eol" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{});
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "MemMappedLineReader: read lines with cr as eol" {
    try test_init();
    const file = try open_file("test/test_cr.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{});
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "MemMappedLineReader: read lines with crlf as eol" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{});
    defer line_reader.deinit();
    try expectLinesMatching(&line_reader);
}

test "MemMappedLineReader: read lines with includeEol crlf at end" {
    try test_init();
    const file = try open_file("test/test_cr_lf.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{ .includeEol = true });
    defer line_reader.deinit();

    try testing.expectEqualStrings("The 1st line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line\r\n", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "MemMappedLineReader: read lines with includeEol has lf at end" {
    try test_init();
    const file = try open_file("test/test_lf_no_last.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{ .includeEol = true });
    defer line_reader.deinit();

    try testing.expectEqualStrings("The 1st line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The middle line\n", (try line_reader.readLine()).?);
    try testing.expectEqualStrings("The last line", (try line_reader.readLine()).?);
    try testing.expectEqual(null, try line_reader.readLine());
}

test "MemMappedLineReader: read all lines" {
    try test_init();
    const file = try open_file("test/test_lf.txt");
    defer file.close();

    var line_reader = try MemMappedLineReader.init(file, .{ .includeEol = true });
    defer line_reader.deinit();

    const lines = try line_reader.readAllLines(hpa);
    try testing.expectEqualStrings("The 1st line\n", lines[0]);
    try testing.expectEqualStrings("The middle line\n", lines[1]);
    try testing.expectEqualStrings("The last line\n", lines[2]);
    try testing.expectEqual(3, lines.len);
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
