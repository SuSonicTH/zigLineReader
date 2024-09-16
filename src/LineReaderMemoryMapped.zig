const std = @import("std");
const MemMapper = @import("MemMapper").MemMapper;
const Options = @import("LineReader.zig").Options;

allocator: std.mem.Allocator,
memMapper: MemMapper,
includeEol: bool,
data: []u8 = undefined,
next: usize = 0,

const Self = @This();

pub fn init(file: *std.fs.File, allocator: std.mem.Allocator, options: Options) !Self {
    var lineReader: Self = .{
        .allocator = allocator,
        .memMapper = try MemMapper.init(file.*, false),
        .includeEol = options.includeEol,
    };
    errdefer lineReader.deinit();
    lineReader.data = try lineReader.memMapper.map(u8, .{});
    return lineReader;
}

pub fn deinit(self: *Self) void {
    self.memMapper.unmap(self.data);
    self.memMapper.deinit();
}

pub fn readLine(self: *Self) !?[]const u8 {
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
