//# Put anything that needs to be tracked throughout the program here
//# Its prefered to have a default value for anything here but if not
//# Just add it to its initialization in main.zig

const Assets = @import("Assets.zig");
const State = @import("states/State.zig");

const Context = @This();

running: bool = true,
assets: Assets = .{},
driver: *const State = &State.states.Game,

pub fn switch_driver(this: *Context, driver: *const State) !void {
    try this.driver.leave(this);
    try driver.enter(this);

    this.driver = driver;
}
