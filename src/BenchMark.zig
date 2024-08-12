const std = @import("std");
const LineReader = @import("LineReader.zig").LineReader;
const MemMappedLineReader = @import("LineReader.zig").MemMappedLineReader;


fn readUntilDelimiterOrEof(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const file = try std.fs.cwd().openFile("world192.txt", .{});
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
    const file = try std.fs.cwd().openFile("world192.txt", .{});
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
    const file = try std.fs.cwd().openFile("world192.txt", .{});
    defer file.close();

    var lineReader = try MemMappedLineReader.init(file, .{});
    defer lineReader.deinit();

    var lineCount: usize = 0;
    while ((try lineReader.readLine()) != null) {
        lineCount += 1;
    }
}

const hpa = std.heap.page_allocator;

test "readUntilDelimiterOrEof" {
    try readUntilDelimiterOrEof(hpa);

    std.debug.print("readUntilDelimiterOrEof:\n", .{});
    var timer = try std.time.Timer.start();
    for (0..5) |i| {
        try readUntilDelimiterOrEof(hpa);
        const runtime: f64 = @floatFromInt(timer.lap());
        std.debug.print("{d}: {d}\n", .{ i + 1, runtime / 1000000.0 });
    }
}

test "lineReaderRead" {
    //try lineReaderRead(hpa);

    std.debug.print("lineReaderRead:\n", .{});
    var timer = try std.time.Timer.start();
    for (0..5) |i| {
        try lineReaderRead(hpa);
        const runtime: f64 = @floatFromInt(timer.lap());
        std.debug.print("{d}: {d}\n", .{ i + 1, runtime / 1000000.0 });
    }
}

test "memMappedLineReaderRead" {
    //try memMappedLineReaderRead(hpa);

    std.debug.print("memMappedLineReaderRead:\n", .{});
    var timer = try std.time.Timer.start();
    for (0..5) |i| {
        try memMappedLineReaderRead(hpa);
        const runtime: f64 = @floatFromInt(timer.lap());
        std.debug.print("{d}: {d}\n", .{ i + 1, runtime / 1000000.0 });
    }
}
