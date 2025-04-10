const std = @import("std");

pub const Event = union(enum) {
    char: Char,
    function: Function,
    special: SpecialKey,
    mouse: Mouse,
    resize,
    unknown,

    pub const Char = struct {
        value: u21,
        ctrl: bool,
        alt: bool,

        pub fn format(
            value: Char,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            var is_escaped = switch (value.value) {
                '\r', '\t', ' ' => true,
                else => value.ctrl or value.alt,
            };

            const lower_char: ?u8 = switch (value.value) {
                'A'...'Z' => |c| blk: {
                    is_escaped = true;
                    break :blk std.ascii.toLower(@intCast(c));
                },
                else => null,
            };

            if (is_escaped) {
                try std.fmt.format(writer, "<", .{});
            }

            if (value.ctrl) {
                try std.fmt.format(writer, "C-", .{});
            }

            if (value.alt) {
                try std.fmt.format(writer, "M-", .{});
            }

            if (lower_char) |ch| {
                try std.fmt.format(writer, "S-{u}", .{ch});
            } else switch (value.value) {
                '\r' => try std.fmt.format(writer, "Enter", .{}),
                '\t' => try std.fmt.format(writer, "Tab", .{}),
                ' ' => try std.fmt.format(writer, "Space", .{}),
                else => try std.fmt.format(writer, "{u}", .{value.value}),
            }

            if (is_escaped) {
                try std.fmt.format(writer, ">", .{});
            }
        }
    };

    pub const Function = struct {
        value: u8,
        modifiers: Modifiers,

        pub fn format(
            value: Function,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            try std.fmt.format(writer, "<{}F{d}>", .{ value.modifiers, value.value });
        }
    };

    pub const Modifiers = struct {
        ctrl: bool,
        alt: bool,
        shift: bool,

        const mod_none = Modifiers{ .ctrl = false, .alt = false, .shift = false };
        const mod_ctrl = Modifiers{ .ctrl = true, .alt = false, .shift = false };
        const mod_alt = Modifiers{ .ctrl = false, .alt = true, .shift = false };
        const mod_shift = Modifiers{ .ctrl = false, .alt = false, .shift = true };

        pub fn format(
            value: Modifiers,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            if (value.ctrl) {
                try std.fmt.format(writer, "C-", .{});
            }

            if (value.alt) {
                try std.fmt.format(writer, "M-", .{});
            }

            if (value.shift) {
                try std.fmt.format(writer, "S-", .{});
            }
        }
    };

    pub const SpecialKey = struct {
        key: enum {
            up,
            down,
            left,
            right,
            esc,
            backspace,
            delete,
            insert,
            page_up,
            page_down,
            home,
            end,
        },
        modifiers: Modifiers,

        pub fn format(
            value: SpecialKey,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            const s = switch (value.key) {
                .up => "Up",
                .down => "Down",
                .left => "Left",
                .right => "Right",
                .esc => "Esc",
                .backspace => "BS",
                .delete => "Del",
                .insert => "Insert",
                .page_up => "PageUp",
                .page_down => "PageDown",
                .home => "Home",
                .end => "End",
            };

            try std.fmt.format(writer, "<{}{s}>", .{ value.modifiers, s });
        }
    };

    pub const Mouse = struct {
        x: u16,
        y: u16,
        button: Button,
        modifiers: Modifiers,

        pub fn format(
            value: Mouse,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            const s = switch (value.button) {
                .left => "LeftMouse",
                .middle => "MiddleMouse",
                .right => "RightMouse",
                .release => "ReleaseMouse",
                .scroll_up => "ScrollUp",
                .scroll_down => "ScrollDown",
                .move => "MouseMove",
                .move_rightclick => "MouseRightClick",
                else => "UnknownMouseEvent",
            };

            try std.fmt.format(writer, "<{}{s}> @ ({}, {})", .{ value.modifiers, s, value.x, value.y });
        }

        pub const Button = enum(u8) {
            left,
            middle,
            right,
            release,
            scroll_up,
            scroll_down,
            move,
            move_rightclick,
            _, // TODO: drag
        };

        pub fn parseCsi(action: u8, x: u8, y: u8) !Mouse {
            return Mouse{
                // low 2 bits of `action` encode the button
                // if the 7th bit is set, alternate buttons are used
                .button = if (action & 0b0100_0000 != 0) switch (action & 0b0000_0011) {
                    0 => Button.scroll_up,
                    1 => Button.scroll_down,
                    2 => Button.move_rightclick,
                    3 => Button.move,
                    else => unreachable,
                } else switch (action & 0b0000_0011) {
                    0 => Button.left,
                    1 => Button.middle,
                    2 => Button.right,
                    3 => Button.release,
                    else => unreachable,
                },
                .modifiers = .{
                    // the 3rd bit indicates shift
                    .shift = action & 0b0000_0100 != 0,
                    // the 4th bit indicates alt
                    .alt = action & 0b0000_1000 != 0,
                    // the 5th bit indicates ctrl
                    .ctrl = action & 0b0001_0000 != 0,
                },
                // x and y are 1-indexed
                .x = x - 1,
                .y = y - 1,
            };
        }
    };

    pub fn parseModifiers(ch: u8) !Modifiers {
        return switch (ch) {
            '2' => Modifiers.mod_shift,
            '3' => Modifiers.mod_alt,
            '4' => Modifiers{ .ctrl = false, .shift = true, .alt = true },
            '5' => Modifiers.mod_ctrl,
            '6' => Modifiers{ .ctrl = true, .shift = true, .alt = false },
            '7' => Modifiers{ .ctrl = true, .shift = false, .alt = true },
            '8' => Modifiers{ .ctrl = true, .shift = true, .alt = false },
            else => return error.UnknownModifier,
        };
    }

    pub fn parseCsi(buf: []u8) Event {
        if (buf.len <= 0) {
            return Event.unknown;
        }

        if (buf[buf.len - 1] == '~') {
            var it = std.mem.tokenizeAny(u8, buf, "~;");
            const first = it.next() orelse return Event.unknown;
            const n = std.fmt.parseInt(u8, first, 10) catch return Event.unknown;

            const modifiers = if (it.next()) |mod_buf|
                if (mod_buf.len == 1) parseModifiers(mod_buf[0]) catch Modifiers.mod_none else Modifiers.mod_none
            else
                Modifiers.mod_none;

            return switch (n) {
                1, 7 => Event{ .special = .{ .key = .home, .modifiers = modifiers } },
                2 => Event{ .special = .{ .key = .insert, .modifiers = modifiers } },
                3 => Event{ .special = .{ .key = .delete, .modifiers = modifiers } },
                4, 8 => Event{ .special = .{ .key = .end, .modifiers = modifiers } },
                5 => Event{ .special = .{ .key = .page_up, .modifiers = modifiers } },
                6 => Event{ .special = .{ .key = .page_down, .modifiers = modifiers } },
                11...15 => |c| Event{ .function = .{ .value = c - 10, .modifiers = modifiers } },
                17...21 => |c| Event{ .function = .{ .value = c - 11, .modifiers = modifiers } },
                23...26 => |c| Event{ .function = .{ .value = c - 12, .modifiers = modifiers } },
                28...29 => |c| Event{ .function = .{ .value = c - 15, .modifiers = modifiers } },
                31...34 => |c| Event{ .function = .{ .value = c - 17, .modifiers = modifiers } },
                else => Event.unknown,
            };
        }

        switch (buf[0]) {
            'A' => return Event{ .special = .{ .key = .up, .modifiers = Modifiers.mod_none } },
            'B' => return Event{ .special = .{ .key = .down, .modifiers = Modifiers.mod_none } },
            'C' => return Event{ .special = .{ .key = .left, .modifiers = Modifiers.mod_none } },
            'D' => return Event{ .special = .{ .key = .right, .modifiers = Modifiers.mod_none } },
            'F' => return Event{ .special = .{ .key = .end, .modifiers = Modifiers.mod_none } },
            'H' => return Event{ .special = .{ .key = .home, .modifiers = Modifiers.mod_none } },
            'P' => return Event{ .function = .{ .value = 1, .modifiers = Modifiers.mod_none } },
            'Q' => return Event{ .function = .{ .value = 2, .modifiers = Modifiers.mod_none } },
            'R' => return Event{ .function = .{ .value = 3, .modifiers = Modifiers.mod_none } },
            'S' => return Event{ .function = .{ .value = 4, .modifiers = Modifiers.mod_none } },
            '1' => {
                if (buf.len < 2) {
                    return Event.unknown;
                }

                switch (buf[1]) {
                    ';' => {
                        if (buf.len != 4) {
                            return Event.unknown;
                        }

                        const modifier = parseModifiers(buf[2]) catch return Event.unknown;

                        return switch (buf[3]) {
                            'A' => Event{ .special = .{ .key = .up, .modifiers = modifier } },
                            'B' => Event{ .special = .{ .key = .down, .modifiers = modifier } },
                            'C' => Event{ .special = .{ .key = .left, .modifiers = modifier } },
                            'D' => Event{ .special = .{ .key = .right, .modifiers = modifier } },
                            'F' => Event{ .special = .{ .key = .end, .modifiers = modifier } },
                            'H' => Event{ .special = .{ .key = .home, .modifiers = modifier } },
                            'P' => Event{ .function = .{ .value = 1, .modifiers = modifier } },
                            'Q' => Event{ .function = .{ .value = 2, .modifiers = modifier } },
                            'R' => Event{ .function = .{ .value = 3, .modifiers = modifier } },
                            'S' => Event{ .function = .{ .value = 4, .modifiers = modifier } },
                            else => Event.unknown,
                        };
                    },
                    else => {},
                }
            },

            'M' => {
                if (buf.len < 4) {
                    return Event.unknown;
                }

                const mouse = Mouse.parseCsi(buf[1], buf[2], buf[3]) catch return Event.unknown;
                return Event{ .mouse = mouse };
            },

            else => {},
        }

        return Event.unknown;
    }

    pub const ReadError = std.fs.File.ReadError || error{EmptyRead};

    pub fn next(in: anytype) ReadError!Event {
        var buf: [20]u8 = undefined;
        const len = try in.read(&buf);
        if (len == 0) {
            return error.EmptyRead;
        }

        if (len >= 1) switch (buf[0]) {
            '\x1b' => if (len >= 2) switch (buf[1]) {
                // CSI
                '[' => if (len >= 3) {
                    return parseCsi(buf[2..len]);
                },
                // F1-F4
                '\x4f' => if (len >= 3) {
                    return Event{ .function = .{ .value = (1 + buf[2] - '\x50'), .modifiers = Modifiers.mod_none } };
                } else {
                    return Event.unknown;
                },
                '\x00' => return Event{ .char = .{ .value = ' ', .ctrl = true, .alt = true } },
                '\x09' => return Event{ .char = .{ .value = '\t', .ctrl = false, .alt = true } },
                // <C-M-{}>
                '\x01'...'\x08', '\x0A'...'\x0C', '\x0E'...'\x1A' => |c| if (len >= 2) {
                    return Event{ .char = .{ .value = @as(u21, c) + '\x60', .ctrl = true, .alt = true } };
                },
                // <M-{}>
                else => return Event{ .char = .{ .value = buf[1], .ctrl = false, .alt = true } },
            } else {
                return Event{ .special = .{ .key = .esc, .modifiers = Modifiers.mod_none } };
            },
            '\x7f' => return Event{ .special = .{ .key = .backspace, .modifiers = Modifiers.mod_none } },
            '\x00' => return Event{ .char = .{ .value = ' ', .ctrl = true, .alt = false } },
            '\x09' => return Event{ .char = .{ .value = '\t', .ctrl = false, .alt = false } },
            // <C-{}>
            '\x01'...'\x08', '\x0A'...'\x0C', '\x0E'...'\x1A' => |c| return Event{ .char = .{ .value = @as(u21, c) + '\x60', .ctrl = true, .alt = false } },
            else => {
                const view = std.unicode.Utf8View.init(buf[0..len]) catch return Event.unknown;
                var it = view.iterator();
                return Event{ .char = .{ .value = it.nextCodepoint() orelse return Event.unknown, .ctrl = false, .alt = false } };
            },
        };

        return Event.unknown;
    }
};
