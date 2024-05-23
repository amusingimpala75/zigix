const std = @import("std");

pub const Option = struct {
    flag: u8,
    argument: Argument = .none,
    excludes: []const u8 = "",

    pub const Argument = union(enum) {
        str: []const u8,
        usize: usize,
        none,

        pub fn str() Argument {
            return .{ .str = "" };
        }

        pub fn @"usize"() Argument {
            return .{ .usize = 0 };
        }
    };
};

pub const OptionMap = struct {
    options: [256]?Option = [1]?Option{null} ** 256,

    pub fn put(self: *OptionMap, option: Option) void {
        self.options[option.flag] = option;
    }

    pub fn putAllNoArgument(self: *OptionMap, options: []const u8) void {
        for (options) |option| {
            self.put(Option{ .flag = option });
        }
    }

    pub fn putAllMutex(self: *OptionMap, comptime options: []const u8) void {
        inline for (options, 0..) |option, idx| {
            const pre = options[0..idx];
            const post = if (idx + 1 >= options.len)
                ""
            else
                options[idx + 1 ..];
            self.put(Option{ .flag = option, .excludes = pre ++ post });
        }
    }

    fn clear(self: *OptionMap, option: u8) void {
        self.options[option] = null;
    }

    // You must make sure that the option exists first
    pub fn get(self: OptionMap, char: u8) Option {
        return self.options[char].?;
    }

    pub fn contains(self: OptionMap, option: u8) bool {
        return self.options[option] != null;
    }

    pub fn isEmpty(self: OptionMap) bool {
        for (self.options) |option| {
            if (option != null) {
                return false;
            }
        }
        return true;
    }
};

pub const Operands = std.ArrayList([]const u8);

pub const ParsedOptions = struct {
    options: OptionMap,
    operands: Operands,

    fn init(allocator: std.mem.Allocator) ParsedOptions {
        return .{
            .options = OptionMap{},
            .operands = Operands.init(allocator),
        };
    }

    pub fn deinit(self: ParsedOptions) void {
        self.operands.deinit();
    }
};

pub fn parse(
    options: OptionMap,
    args: *std.process.ArgIterator,
    allocator: std.mem.Allocator,
) !ParsedOptions {
    var ret = ParsedOptions.init(allocator);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--")) {
            break;
        } else if (arg[0] != '-') {
            try ret.operands.append(arg);
            break;
        }

        for (arg[1..]) |char| {
            if (!options.contains(char)) {
                return error.NoSuchOption;
            }

            const opt = options.get(char);

            for (opt.excludes) |exclude| {
                ret.options.clear(exclude);
            }

            if (opt.argument == .none) {
                ret.options.put(Option{ .flag = char });
            } else {
                if (arg.len > 2) {
                    return error.OptionWithArgumentMustBeAlone;
                }

                const next =
                    args.next() orelse return error.OptionArgumentMissing;

                switch (opt.argument) {
                    .str => |_| ret.options.put(
                        Option{ .flag = char, .argument = .{ .str = next } },
                    ),
                    .usize => |_| ret.options.put(
                        Option{ .flag = char, .argument = .{
                            .usize = try std.fmt.parseInt(usize, next, 10),
                        } },
                    ),
                    else => unreachable,
                }
            }
        }
    }

    while (args.next()) |operand| {
        try ret.operands.append(operand);
    }

    return ret;
}
