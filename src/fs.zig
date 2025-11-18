const std = @import("std");
const testing = @import("std").testing;

/// Check if a file or directory is existing or not.
pub fn isExisting(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch {
        return false;
    };
    return true;
}

test "isFileExisting" {
    try testing.expect(isExisting("testdata/test_file"));
    try testing.expect(!isExisting("testdata/non_existing_file"));
}

/// Check if a file or directory is a symbol link
pub fn isSymLink(path: []const u8) !bool {
    const flags: std.posix.O = switch (@import("builtin").target.os.tag) {
        .macos => .{
            .SYMLINK = true,
        },
        .linux => .{
            .NOFOLLOW = true,
            .PATH = true,
        },
        else => @compileError("Unsupported platform"),
    };
    const fd = try std.posix.open(path, flags, 0o600);
    defer std.posix.close(fd);

    const stat = try std.posix.fstat(fd);

    return std.posix.S.ISLNK(stat.mode);
}

test "isSymLink" {
    const alloc = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realpathAlloc(alloc, ".");
    defer alloc.free(path);

    try tmp.dir.makeDir("./some_dir");

    const dir_abs = try toAbsolutePathAlloc(alloc, "./some_dir", path);
    defer alloc.free(dir_abs);
    const link_abs = try toAbsolutePathAlloc(alloc, "./a_link", path);
    defer alloc.free(link_abs);

    try std.fs.symLinkAbsolute(dir_abs, link_abs, .{});

    try testing.expect(!try isSymLink(dir_abs));
    try testing.expect(try isSymLink(link_abs));
}

/// Expand tidle to home directory
pub fn expandTildeAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (!std.mem.startsWith(u8, path, "~")) {
        return try allocator.dupe(u8, path);
    }

    const home_dir = if (std.process.getEnvVarOwned(allocator, "HOME")) |home|
        home
    else |err|
        return err;
    defer allocator.free(home_dir);

    return try std.fs.path.join(allocator, &[_][]const u8{
        home_dir, path[1..],
    });
}

test "expandTildeAlloc" {
    const alloc = std.testing.allocator;
    {
        const path = try expandTildeAlloc(alloc, "/test.txt");
        defer alloc.free(path);
        try testing.expectEqualStrings("/test.txt", path);
    }

    {
        const path = try expandTildeAlloc(alloc, "~/test.txt");
        defer alloc.free(path);

        const home = try std.process.getEnvVarOwned(alloc, "HOME");
        defer alloc.free(home);

        const expected = try std.fs.path.join(alloc, &[_][]const u8{
            home, "test.txt",
        });
        defer alloc.free(expected);

        try testing.expectEqualStrings(expected, path);
    }
}

/// Converts an absolute path to use tilde notation for the home directory if applicable
pub fn contractTildeAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const home_dir = if (std.process.getEnvVarOwned(allocator, "HOME")) |home|
        home
    else |err|
        return err;
    defer allocator.free(home_dir);

    if (std.mem.startsWith(u8, path, home_dir)) {
        const buf = try allocator.alloc(u8, path.len - home_dir.len + 1);
        buf[0] = '~';
        std.mem.copyBackwards(u8, buf[1..], path[home_dir.len..]);
        return buf;
    } else {
        return allocator.dupe(u8, path);
    }
}

test "contractTildeAlloc" {
    const alloc = std.testing.allocator;
    {
        const path = try contractTildeAlloc(alloc, "/test.txt");
        defer alloc.free(path);
        try testing.expectEqualStrings("/test.txt", path);
    }

    {
        const home = try std.process.getEnvVarOwned(alloc, "HOME");
        defer alloc.free(home);

        const path = try std.fs.path.join(alloc, &[_][]const u8{ home, "test.txt" });
        defer alloc.free(path);

        const contracted = try contractTildeAlloc(alloc, path);
        defer alloc.free(contracted);

        try testing.expectEqualStrings("~/test.txt", contracted);
    }
}

/// Resolve a file path to absolute path
pub fn toAbsolutePathAlloc(alloc: std.mem.Allocator, path: []const u8, base_path: ?[]const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(path)) {
        return alloc.dupe(u8, path);
    }

    const expanded_path = try expandTildeAlloc(alloc, path);
    defer alloc.free(expanded_path);

    const expanded_base = try expandTildeAlloc(alloc, base_path orelse "./");
    defer alloc.free(expanded_base);

    const absolute_dir = try std.fs.cwd().realpathAlloc(alloc, expanded_base);
    defer alloc.free(absolute_dir);

    return try std.fs.path.resolve(alloc, &[_][]const u8{
        absolute_dir,
        expanded_path,
    });
}

test "toAbsolutePathAlloc" {
    const alloc = std.testing.allocator;

    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);

    const home = try std.process.getEnvVarOwned(alloc, "HOME");
    defer alloc.free(home);

    {
        const p = try toAbsolutePathAlloc(alloc, "/tmp/test.txt", cwd);
        defer alloc.free(p);

        try testing.expectEqualStrings("/tmp/test.txt", p);
    }
    {
        const p = try toAbsolutePathAlloc(alloc, "test.txt", cwd);
        defer alloc.free(p);

        const expected = try std.fs.path.join(alloc, &[_][]const u8{
            cwd,
            "test.txt",
        });
        defer alloc.free(expected);

        try testing.expectEqualStrings(expected, p);
    }
    {
        const p = try toAbsolutePathAlloc(alloc, "~/test.txt", cwd);
        defer alloc.free(p);

        const expected = try std.fs.path.join(alloc, &[_][]const u8{
            home,
            "test.txt",
        });
        defer alloc.free(expected);

        try testing.expectEqualStrings(expected, p);
    }
    {
        const p = try toAbsolutePathAlloc(alloc, "test.txt", "~");
        defer alloc.free(p);

        const expected = try std.fs.path.join(alloc, &[_][]const u8{
            home,
            "test.txt",
        });
        defer alloc.free(expected);

        try testing.expectEqualStrings(expected, p);
    }
}

/// Calculate sha256 sum of a file. The caller owns the memory.
pub fn sha256Alloc(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const fullpath = try toAbsolutePathAlloc(alloc, path, ".");
    defer alloc.free(fullpath);

    const file = try std.fs.cwd().openFile(fullpath, .{});
    defer file.close();

    var hash = std.crypto.hash.sha2.Sha256.init(.{});

    var reader_buffer: [8192]u8 = undefined;
    var reader = file.reader(&reader_buffer);

    var buffer: [8192]u8 = undefined;
    while (true) {
        const len = try reader.interface.readSliceShort(&buffer);
        if (len == 0) {
            break;
        }
        hash.update(buffer[0..len]);
    }

    var digest = hash.finalResult();
    return try std.fmt.allocPrint(
        alloc,
        "{x}",
        .{&digest},
    );
}

test "sha256Alloc" {
    const expected = "bc56c0a8f422bf289fa8345a121574f93f594152bf2948ffd92c40a471203d9a";

    const sha256sum = try sha256Alloc(std.testing.allocator, "testdata/test_file");
    defer std.testing.allocator.free(sha256sum);

    try testing.expectEqualStrings(expected, sha256sum);
}

/// Compare two files
pub fn isDifferent(alloc: std.mem.Allocator, path_a: []const u8, path_b: []const u8) bool {
    const checksum_a = sha256Alloc(alloc, path_a) catch "";
    defer alloc.free(checksum_a);

    const checksum_b = sha256Alloc(alloc, path_b) catch "";
    defer alloc.free(checksum_b);

    return !std.mem.eql(u8, checksum_a, checksum_b);
}

test "isDifferent" {
    const alloc = std.testing.allocator;

    try testing.expect(!isDifferent(alloc, "testdata/test_file", "testdata/test_file"));
    try testing.expect(!isDifferent(alloc, "", ""));
    try testing.expect(isDifferent(alloc, "testdata/test_file", ""));
    try testing.expect(isDifferent(alloc, "testdata/test_file", "testdata/test_file2"));
}
