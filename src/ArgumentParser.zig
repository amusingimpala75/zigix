const std = @import("std");

pub const Option = struct {
    flag: u8,
    argument: Argument = .none,
    excludes: []const u8 = "",

    pub const Argument = union(enum) {
        str: []const u8,
        i32: i32,
        none,

        fn str() Argument {
            return .{ .str = "" };
        }

        fn @"i32"() Argument {
            return .{ .i32 = 0 };
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
            const excluded = options[0..idx] ++ if (idx + 1 >= options.len) "" else options[idx + 1 ..];
            self.put(Option{ .flag = option, .excludes = excluded });
        }
    }

    fn clear(self: *OptionMap, char: u8) void {
        self.options[char] = null;
    }

    // You must make sure that the option exists first
    fn get(self: OptionMap, char: u8) Option {
        return self.options[char].?;
    }

    pub fn contains(self: OptionMap, option: u8) bool {
        return self.options[option] != null;
    }
};

pub const Operands = std.ArrayList([]const u8);

pub const ParsedOptions = struct {
    options: OptionMap,
    operands: Operands,

    fn init(allocator: std.mem.Allocator) ParsedOptions {
        return .{ .options = OptionMap{}, .operands = Operands.init(allocator) };
    }

    pub fn deinit(self: *ParsedOptions) void {
        self.operands.deinit();
    }
};

pub fn parse(options: OptionMap, args: *std.process.ArgIterator, allocator: std.mem.Allocator) !ParsedOptions {
    var ret = ParsedOptions.init(allocator);
    for (options.options) |option| {
        if (option) |o| {
            ret.options.clear(o.flag);
        }
    }

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--")) {
            break;
        } else if (arg[0] != '-') {
            try ret.operands.append(arg);
            continue;
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
                const next = args.next() orelse return error.OptionArgumentMissing;
                switch (opt.argument) {
                    .str => |_| ret.options.put(Option{ .flag = char, .argument = .{ .str = next } }),
                    .i32 => |_| ret.options.put(Option{ .flag = char, .argument = .{ .i32 = try std.fmt.parseInt(i32, next, 10) } }),
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
