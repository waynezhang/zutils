const std = @import("std");
const net = std.net;

const require = @import("protest").require;

/// Send message to TCP port
pub fn sendTCPMessage(host: []const u8, message: []const u8) !void {
    const addr = try parseAddrPort(host);

    const stream = try net.tcpConnectToAddress(addr);
    defer stream.close();

    var writer = stream.writer();
    _ = try writer.write(message);
}

/// Parses an address:port string. If only :port is provided, uses 127.0.0.1 as address
pub fn parseAddrPort(str: []const u8) !net.Address {
    const localhost = "127.0.0.1";

    const colon_idx = std.mem.indexOf(u8, str, ":");
    if (colon_idx == null) {
        return net.IPv4ParseError.Incomplete;
    }

    const ip_part = if (colon_idx.? == 0)
        localhost
    else
        str[0..colon_idx.?];

    const port_part = str[colon_idx.? + 1 ..];

    const port = std.fmt.parseInt(u16, port_part, 10) catch {
        return net.IPv4ParseError.Incomplete;
    };

    return net.Address.parseIp4(ip_part, port);
}

test "parseAddrPort" {
    var ipAddrBuffer: [16]u8 = undefined;

    {
        const addr = try parseAddrPort("192.168.1.1:8080");
        const ipv4 = try std.fmt.bufPrint(ipAddrBuffer[0..], "{}", .{addr});
        try require.equal("192.168.1.1:8080", ipAddrBuffer[0..ipv4.len]);
    }
    {
        const addr = try parseAddrPort(":8080");
        const ipv4 = try std.fmt.bufPrint(ipAddrBuffer[0..], "{}", .{addr});
        try require.equal("127.0.0.1:8080", ipAddrBuffer[0..ipv4.len]);
    }
    {
        const err = parseAddrPort("192.168.1.1:invalid");
        try require.equalError(net.IPv4ParseError.Incomplete, err);
    }
    {
        const err = parseAddrPort("300.168.1.1:8080");
        try require.equalError(net.IPv4ParseError.Overflow, err);
    }
    {
        const err = parseAddrPort("invalid");
        try require.equalError(net.IPv4ParseError.Incomplete, err);
    }
}
