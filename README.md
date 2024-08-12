# zigLineReader

a small zig library to read lines from a (text) file in a fast manner
There are 2 readers implemented:
* LineReader accepts a std.File.Reader
* MemMappedLineReader that accepts a file and reads it as a memory mapped file
