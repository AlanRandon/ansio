const csi = "\x1b[";

pub const mouse_tracking = struct {
    pub const enable = csi ++ "?1003h";
    pub const disable = csi ++ "?1003l";
};

pub const alternate_screen = struct {
    pub const enable = csi ++ "?1049h";
    pub const disable = csi ++ "?1049l";
};

pub const cursor = struct {
    pub const show = csi ++ "?25h";
    pub const hide = csi ++ "?25l";

    pub const goto_top_left = csi ++ "H";
};

pub const style = struct {
    pub const reset = csi ++ "0m";

    pub const bold = struct {
        pub const enable = csi ++ "1m";
        pub const disable = csi ++ "22m";
    };

    pub const dim = struct {
        pub const enable = csi ++ "2m";
        pub const disable = csi ++ "22m";
    };

    pub const reverse = struct {
        pub const enable = csi ++ "7m";
        pub const disable = csi ++ "27m";
    };
};

pub const clear = struct {
    pub const line_to_cursor = csi ++ "0K";
    pub const line_from_cursor = csi ++ "1K";
    pub const line = csi ++ "2K";

    pub const screen_to_cursor = csi ++ "0J";
    pub const screen_from_cursor = csi ++ "1J";
    pub const screen = csi ++ "2J";
};
