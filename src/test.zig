comptime {
    _ = @import("fs.zig");
    _ = @import("gzip.zig");
    _ = @import("http.zig");
    _ = @import("net.zig");
}

test {
    @import("std").testing.refAllDecls(@This());
}
