const std = @import("std");
const RawTerm = @import("RawTerm");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    var raw_term = try RawTerm.enable(stdin, stdout, true);
    defer raw_term.disable() catch {};

    var listener = try raw_term.eventListener(allocator);
    defer listener.deinit();

    while (true) {
        const event = try listener.queue.wait();
        std.debug.print("{any}\n\r", .{event});
        switch (event) {
            .special => |special| switch (special.key) {
                .esc => break,
                else => {},
            },
            .resize => {
                std.debug.print("Size: {}\n\r", .{try raw_term.size()});
            },
            else => {},
        }
    }
}
