const std = @import("std");
const LineReaderAnyReader = @import("LineReaderAnyReader.zig");
const LineReaderMemoryMapped = @import("LineReaderMemoryMapped.zig");
const LineReader = @import("LineReader.zig").LineReader;

fn readUntilDelimiterOrEof(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    const reader = file.reader();
    var buffer: [1024]u8 = undefined;

    var lineCount: usize = 0;
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        _ = line;
        lineCount += 1;
    }
}

fn readUntilDelimiterOrEofBuffered(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    const reader = file.reader();
    var buffered_reader = std.io.bufferedReader(reader);
    var buffer: [1024]u8 = undefined;

    var lineCount: usize = 0;
    while (try buffered_reader.reader().readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        _ = line;
        lineCount += 1;
    }
}

fn lineReaderAnyReaderRead(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    const reader = file.reader().any();
    var lineReader = try LineReaderAnyReader.init(reader, allocator, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

fn lineReaderMemoryMappedRead(allocator: std.mem.Allocator) !void {
    var file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    var lineReader = try LineReaderMemoryMapped.init(&file, allocator, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

fn lineReaderAnyReaderInterface(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    const reader = file.reader().any();
    var lineReader = try LineReader.initReader(reader, allocator, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

fn lineReaderMemoryMappedInterface(allocator: std.mem.Allocator) !void {
    var file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    var lineReader = try LineReader.initFile(&file, allocator, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

const hpa = std.heap.page_allocator;

pub const Bench = *const fn (std.mem.Allocator) anyerror!void;

fn bench(function: Bench, name: []const u8, allocator: std.mem.Allocator) !void {
    std.debug.print("{s}:\n", .{name});
    var times: [5]u64 = undefined;

    var timer = try std.time.Timer.start();
    for (0..5) |i| {
        try function(allocator);
        times[i] = timer.lap();
    }

    var sum: f64 = 0;
    for (times, 1..) |time, i| {
        std.debug.print("{d}: {d}ms\n", .{ i, @as(f64, @floatFromInt(time)) / 1000000.0 });
        sum += @floatFromInt(time);
    }
    std.debug.print("average: {d}ms\n\n", .{sum / 5 / 1000000.0});
}

test "readUntilDelimiterOrEof" {
    try bench(readUntilDelimiterOrEof, "readUntilDelimiterOrEof", hpa);
}

test "readUntilDelimiterOrEofBuffered" {
    try bench(readUntilDelimiterOrEofBuffered, "readUntilDelimiterOrEofBuffered", hpa);
}

test "lineReaderAnyReaderRead" {
    try bench(lineReaderAnyReaderRead, "lineReaderAnyReaderRead", hpa);
}

test "lineReaderAnyReaderInterface" {
    try bench(lineReaderAnyReaderInterface, "lineReaderAnyReaderInterface", hpa);
}

test "lineReaderMemoryMappedRead" {
    try bench(lineReaderMemoryMappedRead, "lineReaderMemoryMappedRead", hpa);
}

test "lineReaderMemoryMappedInterface" {
    try bench(lineReaderMemoryMappedInterface, "lineReaderMemoryMappedInterface", hpa);
}
