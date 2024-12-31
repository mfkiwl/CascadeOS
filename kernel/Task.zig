// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

const Task = @This();

_name: Name,

state: State,

/// The stack used by this task in kernel mode.
stack: kernel.Stack,

/// Tracks the depth of nested interrupt disables.
interrupt_disable_count: std.atomic.Value(u32),

/// Tracks the depth of nested preemption disables.
preemption_disable_count: std.atomic.Value(u32) = .init(0),

/// Whenever we skip preemption, we set this to true.
///
/// When we re-enable preemption, we check this flag.
preemption_skipped: std.atomic.Value(bool) = .init(false),

pub fn name(self: *const Task) []const u8 {
    return self._name.constSlice();
}

pub const State = union(enum) {
    ready,
    /// It is the accessors responsibility to ensure that the executor does not change.
    running: *kernel.Executor,
    blocked,
    dropped,
};

pub fn incrementInterruptDisable(self: *Task) void {
    kernel.arch.interrupts.disableInterrupts();

    _ = self.interrupt_disable_count.fetchAdd(1, .monotonic);

    const executor = self.state.running;
    std.debug.assert(executor == kernel.arch.rawGetCurrentExecutor());
    std.debug.assert(executor.current_task == self);
}

pub fn decrementInterruptDisable(self: *Task) void {
    std.debug.assert(!kernel.arch.interrupts.areEnabled());

    const executor = self.state.running;
    std.debug.assert(executor == kernel.arch.rawGetCurrentExecutor());
    std.debug.assert(executor.current_task == self);

    const previous = self.interrupt_disable_count.fetchSub(1, .monotonic);
    std.debug.assert(previous > 0);

    if (previous == 1) {
        kernel.arch.interrupts.enableInterrupts();
    }
}

pub fn incrementPreemptionDisable(self: *Task) void {
    _ = self.preemption_disable_count.fetchAdd(1, .monotonic);

    const executor = self.state.running;
    std.debug.assert(executor == kernel.arch.rawGetCurrentExecutor());
    std.debug.assert(executor.current_task == self);
}

pub fn decrementPreemptionDisable(self: *Task) void {
    const executor = self.state.running;
    std.debug.assert(executor == kernel.arch.rawGetCurrentExecutor());
    std.debug.assert(executor.current_task == self);

    const previous = self.preemption_disable_count.fetchSub(1, .monotonic);
    std.debug.assert(previous > 0);

    if (previous == 1 and self.preemption_skipped.load(.monotonic)) {
        core.panic("PRE-EMPTION NOT IMPLEMEMENTED", null);
    }
}

pub const Name = std.BoundedArray(u8, kernel.config.task_name_length);

pub fn print(task: *const Task, writer: std.io.AnyWriter, _: usize) !void {
    // Task(task.name)

    try writer.writeAll("Task(");
    try writer.writeAll(task.name());
    try writer.writeByte(')');
}

pub inline fn format(
    task: *const Task,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    return if (@TypeOf(writer) == std.io.AnyWriter)
        print(task, writer, 0)
    else
        print(task, writer.any(), 0);
}

fn __helpZls() void {
    Task.print(undefined, @as(std.fs.File.Writer, undefined), 0);
}

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");
