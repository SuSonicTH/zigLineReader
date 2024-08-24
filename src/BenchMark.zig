const std = @import("std");
const LineReader = @import("LineReader.zig").LineReader;
const MemMappedLineReader = @import("LineReader.zig").MemMappedLineReader;

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

fn lineReaderRead(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    const reader = file.reader();
    var lineReader = try LineReader.init(reader, allocator, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

fn memMappedLineReaderRead(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const file = try std.fs.cwd().openFile("test/world192.txt", .{});
    defer file.close();

    var lineReader = try MemMappedLineReader.init(file, .{});
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
        std.debug.print("{d}: {d}\n", .{ i, @as(f64, @floatFromInt(time)) / 1000000.0 });
        sum += @floatFromInt(time);
    }
    std.debug.print("average: {d}\n\n", .{sum / 5 / 1000000.0});
}

test "readUntilDelimiterOrEof" {
    //try bench(readUntilDelimiterOrEof, "readUntilDelimiterOrEof", hpa);
}

test "readUntilDelimiterOrEofBuffered" {
    try bench(readUntilDelimiterOrEofBuffered, "readUntilDelimiterOrEofBuffered", hpa);
}

test "lineReaderRead" {
    try bench(lineReaderRead, "lineReaderRead", hpa);
}

test "memMappedLineReaderRead" {
    try bench(memMappedLineReaderRead, "memMappedLineReaderRead", hpa);
}
