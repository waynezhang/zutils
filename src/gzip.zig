const std = @import("std");
const fs = @import("fs.zig");
const require = @import("protest").require;

const gzip = std.compress.gzip;

/// Unarchive a Gzip file to dst path
pub fn unarchive(src: []const u8, dst: []const u8) !void {
    const src_file = try std.fs.cwd().openFile(src, .{});
    defer src_file.close();

    const dst_file = try std.fs.cwd().createFile(dst, .{ .truncate = true });
    defer dst_file.close();

    var buffered_reader = std.io.bufferedReader(src_file.reader());
    const reader = buffered_reader.reader();

    var buffered_writer = std.io.bufferedWriter(dst_file.writer());
    const writer = buffered_writer.writer();

    try gzip.decompress(reader, writer);

    try buffered_writer.flush();
}

test "unarchive" {
    const src_file = "testdata/test_file.gz";

    var tmp = std.testing.tmpDir(.{});

    const tmp_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(tmp_path);

    const dst_path = try std.fs.path.join(std.testing.allocator, &[_][]const u8{
        tmp_path, "unarchived_file",
    });
    defer std.testing.allocator.free(dst_path);

    try unarchive(src_file, dst_path);

    const original_checksum = "bc56c0a8f422bf289fa8345a121574f93f594152bf2948ffd92c40a471203d9a";

    const checksum = try fs.sha256Alloc(std.testing.allocator, dst_path);
    defer std.testing.allocator.free(checksum);

    try require.equal(original_checksum, checksum);
}

/// Extract a tarball to dst directory
pub fn extractTarball(src: []const u8, dst_dir: []const u8) !void {
    const src_file = try std.fs.cwd().openFile(src, .{});
    defer src_file.close();

    var buffered_reader = std.io.bufferedReader(src_file.reader());
    const reader = buffered_reader.reader();

    var gzip_stream = std.compress.gzip.decompressor(reader);
    const gzip_reader = gzip_stream.reader();

    var dir = try std.fs.cwd().openDir(dst_dir, .{});
    defer dir.close();
    try std.tar.pipeToFileSystem(dir, gzip_reader, .{});
}

test "extractTarball" {
    const alloc = std.testing.allocator;

    const src_file = "testdata/test_file.tar.gz";

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dst_path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(dst_path);

    try extractTarball(src_file, dst_path);

    const expected_checksum = "bc56c0a8f422bf289fa8345a121574f93f594152bf2948ffd92c40a471203d9a";
    const file_path = try std.fs.path.join(alloc, &[_][]const u8{
        dst_path,
        "test_file",
    });
    defer alloc.free(file_path);

    const checksum = try fs.sha256Alloc(alloc, file_path);
    defer alloc.free(checksum);
    try require.equal(expected_checksum, checksum);
}
