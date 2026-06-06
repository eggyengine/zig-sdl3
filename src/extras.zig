const log = @import("log.zig");
const message_box = @import("message_box.zig");
const options = @import("options");
const std = @import("std");
const timer = @import("timer.zig");

/// Initialization data that can be used for callbacks.
///
/// ## Remarks
/// Arguments and environment are not provided as the init function contains the arguments, and SDL provides a mechanism for interacting with environment variables.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const Init = @import("extras/Init.zig");

/// Capper for keeping the framerate within a given range.
///
/// ## Remarks
/// VSync can be a good limiter for framerates, but in case VSync is not desired having unlimited FPS may be a problem.
/// This framerate capper solves this issue.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub fn FramerateCapper(
    comptime Accuracy: type,
) type {
    return struct {
        /// Mode for the capper to run at.
        mode: Mode,
        /// Current frame number, maxes out and will not go past the size of a `usize`.
        frame_num: usize = 0,
        /// The number of elapsed nanoseconds present since last update.
        elapsed_ns: u64 = 0,
        /// Nanoseconds mark for the previous frame.
        prev_ns: u64 = 0,
        /// Delta time since the last frame.
        dt: u64 = 0,

        // Type check.
        comptime {
            if (@typeInfo(Accuracy) != .float)
                @compileError("Framerate capper accuracy only works on floating-point types.");
        }

        /// Framerate capper mode.
        ///
        /// ## Version
        /// This struct is provided by zig-sdl3.
        pub const Mode = union(enum) {
            /// Run at unlimited FPS.
            /// You may want to use this in case you have VSync in order to get dt.
            unlimited: void,
            /// Run at the given FPS.
            limited: Accuracy,
        };

        /// Delay to achieve the target FPS.
        ///
        /// ## Function Parameters
        /// * `self`: The FPS limiter.
        ///
        /// ## Return Value
        /// Returns the delta time since the last frame in seconds.
        ///
        /// ## Version
        /// This function is provided since zig-sdl3.
        pub fn delay(
            self: *@This(),
        ) Accuracy {

            // Useful for diagnostics.
            self.frame_num +|= 1; // If this duration is exceeded, overflow or panic probably not ideal?

            const curr_ns = timer.getNanosecondsSinceInit();
            self.dt = @max(curr_ns -% self.prev_ns, 1);
            switch (self.mode) {
                .unlimited => {},
                .limited => |fps| {
                    if (fps != 0) {
                        // Nanoseconds per frame. 1 / (Frames / Seconds) = Seconds / Frame -> Nanoseconds / Frame.
                        const expected_ns = @as(u64, @intFromFloat(timer.nanoseconds_per_second / fps));
                        const ns_diff = curr_ns -% self.elapsed_ns;
                        if (ns_diff < expected_ns) {
                            timer.delayNanoseconds(expected_ns -% ns_diff);
                        }
                    }
                },
            }
            self.prev_ns = curr_ns;
            self.elapsed_ns = timer.getNanosecondsSinceInit();
            return @as(Accuracy, @floatFromInt(self.dt)) / @as(Accuracy, @floatFromInt(timer.nanoseconds_per_second));
        }

        /// Get the actual FPS.
        ///
        /// ## Function Parameters
        /// * `self`: The framerate capper.
        ///
        /// ## Return Value
        /// Returns the FPS as observed (in contrast to the target FPS set).
        ///
        /// ## Version
        /// This function is provided by zig-sdl3.
        pub fn getObservedFps(
            self: @This(),
        ) Accuracy {
            // Frames / Second.
            // 1 Frame / (Nanoseconds / 1000).
            return 1 / (@as(Accuracy, @floatFromInt(@max(self.dt, 1))) / timer.nanoseconds_per_second);
        }
    };
}

const logger = std.log.scoped(.sdl3);

/// An example function to handle errors from SDL in a debug print.
///
/// ## Function Parameters
/// * `err`: A slice to an error message, or `null` if the error message is not known.
///
/// ## Remarks
/// Remember that the error callback is thread-local, thus you need to set it for each thread!
pub fn sdlErrDebugPrint(
    err: ?[]const u8,
) void {
    if (err) |val| {
        std.debug.print("******* [SDL3 Error! {s}] *******\n", .{val});
    } else {
        std.debug.print("******* [Unknown SDL3 Error!] *******\n", .{});
    }
}

/// An example function to handle errors from SDL as SDL error messages.
///
/// ## Function Parameters
/// * `err`: A slice to an error message, or `null` if the error message is not known.
///
/// ## Remarks
/// Remember that the error callback is thread-local, thus you need to set it for each thread!
pub fn sdlErrSdlLog(
    err: ?[]const u8,
) void {
    if (err) |val| {
        log.Category.errors.logError("{s}", .{val}) catch {};
    } else {
        log.Category.errors.logError("Unknown", .{}) catch {};
    }
}

/// An example function to handle errors from SDL in an SDL message box.
///
/// ## Function Parameters
/// * `err`: A slice to an error message, or `null` if the error message is not known.
///
/// ## Remarks
/// Remember that the error callback is thread-local, thus you need to set it for each thread!
pub fn sdlErrSdlMessageBox(
    err: ?[]const u8,
) void {
    var buf: [options.log_message_stack_size]u8 = undefined;
    const err_msg = if (err) |val| std.fmt.bufPrintZ(&buf, "{s}", .{val}) catch "SDL message too long, please increase the `log_message_stack_size` build option" else "Unknown SDL error";
    message_box.showSimple(.{ .error_dialog = true }, "SDL Error", err_msg, null) catch {};
}

/// An example function to handle errors from SDL in a zig error log.
///
/// ## Function Parameters
/// * `err`: A slice to an error message, or `null` if the error message is not known.
///
/// ## Remarks
/// Remember that the error callback is thread-local, thus you need to set it for each thread!
pub fn sdlErrZigLog(
    err: ?[]const u8,
) void {
    if (err) |val| {
        logger.err("[Error:General] {s}", .{val});
    } else {
        logger.err("[Error:Unknown]", .{});
    }
}

/// An example function to log with SDL using debug prints.
///
/// ## Function Parameters
/// * `user_data`: User data provided to the logging function.
/// * `category`: Which category SDL is logging under, for example "video".
/// * `priority`: Which priority the log message is.
/// * `message`: Actual message to log. This should not be `null`.
pub fn sdlLogDebugPrint(
    user_data: ?*void,
    category: log.Category,
    priority: ?log.Priority,
    message: [:0]const u8,
) void {
    _ = user_data;
    const category_str: ?[]const u8 = switch (category) {
        .application => "Application",
        .errors => "Errors",
        .assert => "Assert",
        .system => "System",
        .audio => "Audio",
        .video => "Video",
        .render => "Render",
        .input => "Input",
        .testing => "Testing",
        .gpu => "Gpu",
        else => null,
    };
    const priority_str: [:0]const u8 = if (priority) |val| switch (val) {
        .trace => "Trace",
        .verbose => "Verbose",
        .debug => "Debug",
        .info => "Info",
        .warn => "Warn",
        .err => "Error",
        .critical => "Critical",
    } else "Unknown";
    if (category_str) |val| {
        std.debug.print("[{s}:{s}] {s}\n", .{ val, priority_str, message });
    } else {
        std.debug.print("[Custom_{d}:{s}] {s}\n", .{ @intFromEnum(category), priority_str, message });
    }
}

/// An example function to log with SDL using the SDL message box.
///
/// ## Function Parameters
/// * `user_data`: User data provided to the logging function.
/// * `category`: Which category SDL is logging under, for example "video".
/// * `priority`: Which priority the log message is.
/// * `message`: Actual message to log. This should not be `null`.
pub fn sdlLogSdlMessageBox(
    user_data: ?*void,
    category: log.Category,
    priority: ?log.Priority,
    message: [:0]const u8,
) void {
    _ = user_data;
    const category_str: ?[]const u8 = switch (category) {
        .application => "Application",
        .errors => "Errors",
        .assert => "Assert",
        .system => "System",
        .audio => "Audio",
        .video => "Video",
        .render => "Render",
        .input => "Input",
        .testing => "Testing",
        .gpu => "Gpu",
        else => null,
    };
    const priority_str: [:0]const u8 = if (priority) |val| switch (val) {
        .trace => "Trace",
        .verbose => "Verbose",
        .debug => "Debug",
        .info => "Info",
        .warn => "Warn",
        .err => "Error",
        .critical => "Critical",
    } else "Unknown";
    var buf: [options.log_message_stack_size]u8 = undefined;
    const too_long = "SDL message too long, please increase the `log_message_stack_size` build option";
    const text = if (category_str) |val| std.fmt.bufPrintZ(&buf, "{s}: {s}", .{ val, message }) catch too_long else message;
    message_box.showSimple(
        .{
            .information_dialog = priority == .info,
            .warning_dialog = priority == .warn,
            .error_dialog = priority == .err,
        },
        priority_str,
        text,
        null,
    ) catch {};
}

/// An example function to log with SDL using zig log.
///
/// ## Function Parameters
/// * `user_data`: User data provided to the logging function.
/// * `category`: Which category SDL is logging under, for example "video".
/// * `priority`: Which priority the log message is.
/// * `message`: Actual message to log. This should not be `null`.
pub fn sdlLogZigLog(
    user_data: ?*void,
    category: log.Category,
    priority: ?log.Priority,
    message: [:0]const u8,
) void {
    _ = user_data;
    const category_str: ?[]const u8 = switch (category) {
        .application => "Application",
        .errors => "Errors",
        .assert => "Assert",
        .system => "System",
        .audio => "Audio",
        .video => "Video",
        .render => "Render",
        .input => "Input",
        .testing => "Testing",
        .gpu => "Gpu",
        else => null,
    };
    const priority_str: [:0]const u8 = if (priority) |val| switch (val) {
        .trace => "Trace",
        .verbose => "Verbose",
        .debug => "Debug",
        .info => "Info",
        .warn => "Warn",
        .err => "Error",
        .critical => "Critical",
    } else "Unknown";
    const pri = priority orelse .info;
    if (category_str) |val| {
        const fmt = "[{s}:{s}] {s}";
        switch (pri) {
            .err, .critical => logger.err(fmt, .{ val, priority_str, message }),
            .warn => logger.warn(fmt, .{ val, priority_str, message }),
            .info => logger.info(fmt, .{ val, priority_str, message }),
            else => logger.debug(fmt, .{ val, priority_str, message }),
        }
    } else {
        const fmt = "[Custom_{d}:{s}] {s}";
        switch (pri) {
            .err, .critical => logger.err(fmt, .{ @intFromEnum(category), priority_str, message }),
            .warn => logger.warn(fmt, .{ @intFromEnum(category), priority_str, message }),
            .info => logger.info(fmt, .{ @intFromEnum(category), priority_str, message }),
            else => logger.debug(fmt, .{ @intFromEnum(category), priority_str, message }),
        }
    }
}

test "extra" {
    std.testing.refAllDecls(@This());
}
