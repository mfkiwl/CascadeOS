// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

/// Queues a task to be run by the scheduler.
pub fn queueTask(scheduler_held: SchedulerHeld, task: *kernel.Task) void {
    scheduler_held.validate();
    std.debug.assert(task.next_task_node.next == null);

    task.state = .ready;
    ready_to_run.push(&task.next_task_node);
}

/// Yield execution to the scheduler.
///
/// This function must be called with the scheduler lock held.
pub fn yield(scheduler_held: SchedulerHeld, comptime mode: enum { requeue, drop }) void {
    scheduler_held.validate();

    const executor = scheduler_held.held.exclusion.executor;

    const new_task_node = ready_to_run.pop() orelse {
        switch (mode) {
            .requeue => return, // no tasks to run
            .drop => {
                if (executor.current_task) |current_task| {
                    std.debug.assert(current_task.state == .running);
                    log.debug("dropping {}", .{current_task});
                    current_task.state = .dropped;
                }

                switchToIdle(executor, executor.current_task);
                return;
            },
        }
    };

    const new_task = kernel.Task.fromNode(new_task_node);
    std.debug.assert(new_task.state == .ready);

    if (executor.current_task) |current_task| {
        std.debug.assert(current_task != new_task);
        std.debug.assert(current_task.state == .running);
        // TODO: reinstate these
        // std.debug.assert(current_task.preemption_disable_count == 0);
        // std.debug.assert(current_task.preemption_skipped == false);

        switch (mode) {
            .requeue => {
                log.debug("yielding {}", .{current_task});
                queueTask(scheduler_held, current_task);
            },
            .drop => {
                log.debug("dropping {}", .{current_task});
                current_task.state = .dropped;
            },
        }

        switchToTaskFromTask(executor, current_task, new_task);
    } else {
        switchToTaskFromIdle(executor, new_task);
        core.panic("task returned to idle", null);
    }
}

pub const SchedulerHeld = struct {
    held: kernel.sync.TicketSpinLock.Held,

    pub fn unlock(self: *SchedulerHeld) void {
        self.held.unlock();
    }

    fn validate(scheduler_held: SchedulerHeld) void {
        std.debug.assert(scheduler_held.held.spinlock == &lock);
        std.debug.assert(lock.isLockedBy(arch.rawGetCurrentExecutor().id));
    }
};

/// Lock the scheduler and produces a `SchedulerHeld`.
///
/// It is the caller's responsibility to call `SchedulerHeld.held.release()` when done.
pub fn lockScheduler(exclusion: kernel.sync.InterruptExclusion) SchedulerHeld {
    return .{
        .held = lock.lock(exclusion),
    };
}

/// Unlock the scheduler lock and produces a `kernel.sync.InterruptExclusion`.
///
/// Intended to only be called in idle or a new task.
pub fn unlockSchedulerFromOtherTask() kernel.sync.InterruptExclusion {
    const exclusion = kernel.sync.assertInterruptExclusion(true);

    std.debug.assert(lock.isLockedBy(exclusion.executor.id));

    lock.unsafeRelease();

    return exclusion;
}

fn switchToIdle(executor: *kernel.Executor, opt_current_task: ?*kernel.Task) void {
    log.debug("no tasks to run, switching to idle", .{});

    executor.current_task = null;

    if (opt_current_task) |current_task| {
        arch.scheduling.prepareForJumpToIdleFromTask(executor, current_task);
    }

    arch.scheduling.callZeroArgs(opt_current_task, executor.scheduler_stack, idle) catch |err| {
        switch (err) {
            // the scheduler stack should be big enough
            error.StackOverflow => core.panic("insufficent space on the scheduler stack", null),
        }
    };
}

fn switchToTaskFromIdle(executor: *kernel.Executor, new_task: *kernel.Task) noreturn {
    log.debug("switching to {} from idle", .{new_task});

    std.debug.assert(new_task.next_task_node.next == null);

    executor.current_task = new_task;
    new_task.state = .running;

    arch.scheduling.prepareForJumpToTaskFromIdle(executor, new_task);
    arch.scheduling.jumpToTaskFromIdle(new_task);
    core.panic("task returned to idle", null);
}

fn switchToTaskFromTask(executor: *kernel.Executor, current_task: *kernel.Task, new_task: *kernel.Task) void {
    log.debug("switching to {} from {}", .{ new_task, current_task });

    std.debug.assert(new_task.next_task_node.next == null);

    executor.current_task = new_task;
    new_task.state = .running;

    arch.scheduling.prepareForJumpToTaskFromTask(executor, current_task, new_task);
    arch.scheduling.jumpToTaskFromTask(current_task, new_task);
}

fn idle() callconv(.C) noreturn {
    var entry_exclusion = unlockSchedulerFromOtherTask();
    log.debug("entering idle", .{});
    entry_exclusion.release();

    while (true) {
        if (!ready_to_run.isEmpty()) {
            var exclusion = kernel.sync.acquireInterruptExclusion();
            defer exclusion.release();

            var held = lockScheduler(exclusion);
            defer held.unlock();

            if (!ready_to_run.isEmpty()) {
                yield(held, .requeue);
            }
        }

        arch.halt();
    }
}

var lock: kernel.sync.TicketSpinLock = .{};
var ready_to_run: containers.SinglyLinkedFIFO = .{};

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");
const arch = @import("arch");
const containers = @import("containers");
const log = kernel.log.scoped(.scheduler);
