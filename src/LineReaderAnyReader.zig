const std = @import("std");
const Options = @import("LineReader.zig").Options;
const LineReaderError = @import("LineReader.zig").LineReaderError;

reader: std.io.AnyReader,
allocator: std.mem.Allocator,
size: usize,
read_size: usize,
buffer: []u8,
start: usize = 0,
next: usize = 0,
end: usize = 0,
eof: bool = false,
includeEol: bool,

const Self = @This();

pub fn init(reader: std.io.AnyReader, allocator: std.mem.Allocator, options: Options) !Self {
    if (options.size == 0) {
        return LineReaderError.OptionError;
    }
    var read_size: usize = options.size;
    if (read_size == 0) {
        read_size = 4096;
    }
    const alloc_size = read_size * 2;
    var lineReader: Self = .{
        .reader = reader,
        .allocator = allocator,
        .size = alloc_size,
        .read_size = read_size,
        .buffer = try allocator.alloc(u8, alloc_size),
        .includeEol = options.includeEol,
    };
    errdefer deinit(&lineReader);
    _ = try lineReader.fillBuffer();
    return lineReader;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buffer);
}

pub fn readLine(self: *Self) !?[]const u8 {
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

inline fn fillBuffer(self: *Self) !usize {
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

pub fn reset(self: *Self) !void {
    _ = self;
    return error.Unsupported;
}
