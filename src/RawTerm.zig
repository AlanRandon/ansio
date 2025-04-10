const std = @import("std");
const Event = @import("event.zig").Event;

orig: std.posix.termios,
file: std.fs.File,
mouse_tracking: bool,

const RawTerm = @This();

pub const enable_mouse_tracking = "\x1b[?1003h";
pub const disable_mouse_tracking = "\x1b[?1003l";

pub fn enable(file: std.fs.File, mouse_tracking: bool) !RawTerm {
    const orig = try std.posix.tcgetattr(file.handle);
    var termios = orig;

    // https://refspecs.linuxfoundation.org/LSB_4.1.0/LSB-Core-generic/LSB-Core-generic/baselib-cfmakeraw-3.html

    termios.iflag.IGNBRK = false;
    termios.iflag.BRKINT = false;
    termios.iflag.PARMRK = false;
    termios.iflag.ISTRIP = false;
    termios.iflag.INLCR = false; // don't translate NL to CR
    termios.iflag.IGNCR = false; // don't ignore CR
    termios.iflag.ICRNL = false; // don't translate CR to NL
    termios.iflag.IXON = false;

    termios.oflag.OPOST = false; // disable implementation-defined output processing

    termios.lflag.ECHO = false; // disable echo input
    termios.lflag.ECHONL = false; // disable echo newlines
    termios.lflag.ICANON = false; // disable canonical mode (don't wait for line terminator, disable line editing)
    termios.lflag.ISIG = false; // disable signal generation for certain special characters
    termios.lflag.IEXTEN = false; // disable implemenation-defined input processing

    termios.cflag.PARENB = false;
    termios.cflag.CSIZE = .CS8;

    // read blocks until 1 byte is available and returns it
    termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;

    try std.posix.tcsetattr(file.handle, .FLUSH, termios);
    if (mouse_tracking) {
        try file.writeAll(enable_mouse_tracking);
    }

    return RawTerm{
        .orig = orig,
        .file = file,
        .mouse_tracking = mouse_tracking,
    };
}

pub fn disable(raw_term: *RawTerm) !void {
    if (raw_term.mouse_tracking) {
        try raw_term.file.writeAll(disable_mouse_tracking);
    }

    try std.posix.tcsetattr(raw_term.file.handle, .FLUSH, raw_term.orig);
}

const EventQueue = @import("EventQueue.zig");

pub const EventListener = struct {
    queue: EventQueue,

    pub fn deinit(l: *EventListener) void {
        l.queue.deinit();
        l.queue.allocator.destroy(l);
    }
};

pub fn eventListener(raw_term: *const RawTerm, allocator: std.mem.Allocator) !*EventListener {
    var queue = EventQueue.init(allocator);
    errdefer queue.deinit();

    // allocate space for the listener as `l.queue` MUST not move
    const l = try allocator.create(EventListener);
    errdefer allocator.destroy(l);

    l.* = .{
        .queue = queue,
    };

    try l.queue.listenStdin(raw_term.file);
    l.queue.listenSigwinch();

    return l;
}

const Size = struct {
    width: u16,
    height: u16,
};

pub fn size(raw_term: *const RawTerm) !Size {
    var ws: std.posix.winsize = undefined;

    const err = std.posix.system.ioctl(raw_term.file.handle, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (std.posix.errno(err) != .SUCCESS) {
        return error.IoctlError;
    }

    return Size{
        .width = ws.col,
        .height = ws.row,
    };
}
