# zigLineReader

a small zig library to read lines from a (text) file in a fast manner
There are 2 readers implemented:
* LineReader accepts a std.io.AnyReader
* MemMappedLineReader that accepts a file and reads it as a memory mapped file

Both can be used tranparently from outside with the LineReader interface 
