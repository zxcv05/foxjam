pub const Amount = enum(u5) {
    const Tag = @typeInfo(Amount).@"enum".tag_type;

    pub const STEPS = 20;
    pub const PERCENT_PER_STEP = 1.0 / @as(comptime_float, @floatFromInt(STEPS));

    @"5%" = 1,
    @"10%",
    @"15%",
    @"20%",
    @"25%",
    @"30%",
    @"35%",
    @"40%",
    @"45%",
    @"50%",
    @"55%",
    @"60%",
    @"65%",
    @"70%",
    @"75%",
    @"80%",
    @"85%",
    @"90%",
    @"95%",
    @"100%",

    pub inline fn fit_percentage(percent: f32) Amount {
        const as_int: Tag = @intFromFloat(@round(percent * STEPS));
        return @enumFromInt(as_int);
    }

    pub inline fn to_percentage(this: Amount) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(this))) * PERCENT_PER_STEP;
    }

    pub inline fn to_int(this: Amount) Tag {
        return @intFromEnum(this);
    }
};
