// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Lee Cannon <leecannon@leecannon.xyz>

/// Stage 1 of kernel initialization, entry point from bootloader specific code.
///
/// Only the bootstrap executor executes this function, using the bootloader provided stack.
pub fn initStage1() !noreturn {
    // we need the direct map to be available as early as possible
    try kernel.vmm.init.determineOffsets();

    // initialize ACPI tables early to allow discovery of debug output mechanisms
    kernel.acpi.init.initializeACPITables();

    Output.registerOutputs();

    try Output.writer.writeAll(comptime "starting CascadeOS " ++ kernel.config.cascade_version ++ "\n");

    kernel.vmm.init.logOffsets();

    var bootstrap_init_task: kernel.Task = .{
        .id = @enumFromInt(0),
        ._name = kernel.Task.Name.fromSlice("bootstrap init") catch unreachable,
        .state = undefined, // set after declaration of `bootstrap_executor`
        .stack = undefined, // never used
        .spinlocks_held = 0, // init tasks don't start with the scheduler locked
    };

    var bootstrap_executor: kernel.Executor = .{
        .id = .bootstrap,
        .current_task = &bootstrap_init_task,
        .arch = undefined, // set by `arch.init.prepareBootstrapExecutor`
        .idle_task = undefined, // never used
    };

    bootstrap_init_task.state = .{ .running = &bootstrap_executor };

    kernel.executors = @as([*]kernel.Executor, @ptrCast(&bootstrap_executor))[0..1];

    log.debug("loading bootstrap executor", .{});
    kernel.arch.init.prepareBootstrapExecutor(
        &bootstrap_executor,
        kernel.boot.bootstrapArchitectureProcessorId(),
    );
    kernel.arch.init.loadExecutor(&bootstrap_executor);

    log.debug("initializing early interrupts", .{});
    kernel.arch.interrupts.init.initializeEarlyInterrupts();

    log.debug("capturing early system information", .{});
    kernel.arch.init.captureEarlySystemInformation();

    log.debug("configuring per-executor system features", .{});
    kernel.arch.init.configurePerExecutorSystemFeatures(&bootstrap_executor);

    log.debug("building memory layout", .{});
    try kernel.vmm.init.buildMemoryLayout();

    log.debug("initializing physical memory", .{});
    try kernel.pmm.init.initializePhysicalMemory();

    log.debug("building core page table", .{});
    try kernel.vmm.init.buildAndLoadCorePageTable();

    log.debug("initializing kernel and special heap", .{});
    try kernel.heap.init.initializeHeaps(&bootstrap_init_task);

    log.debug("remapping init outputs", .{});
    try Output.remapOutputs(&bootstrap_init_task);

    log.debug("initializing kernel stacks", .{});
    try kernel.Stack.init.initializeStacks(&bootstrap_init_task);

    log.debug("capturing system information", .{});
    try kernel.arch.init.captureSystemInformation(switch (kernel.config.cascade_target) {
        .x64 => .{ .x2apic_enabled = kernel.boot.x2apicEnabled() },
        else => .{},
    });

    log.debug("configuring global system features", .{});
    try kernel.arch.init.configureGlobalSystemFeatures();

    log.debug("initializing time", .{});
    try kernel.time.init.initializeTime();

    log.debug("initializing interrupt routing", .{});
    try kernel.arch.interrupts.init.initializeInterruptRouting(&bootstrap_init_task);

    log.debug("initializing kernel executors", .{});
    kernel.executors = try createExecutors();

    // ensure the bootstrap executor is re-loaded before we change panic and log modes
    kernel.arch.init.loadExecutor(kernel.getExecutor(.bootstrap));

    kernel.debug.setPanicMode(.init_panic);
    kernel.debug.log.setLogMode(.init_log);

    log.debug("booting non-bootstrap executors", .{});
    try bootNonBootstrapExecutors();

    try initStage2(kernel.Task.getCurrent());
}

/// Stage 2 of kernel initialization.
///
/// This function is executed by all executors, including the bootstrap executor.
///
/// All executors are using the bootloader provided stack.
fn initStage2(current_task: *kernel.Task) !noreturn {
    kernel.vmm.globals.core_page_table.load();
    const executor = current_task.state.running;
    kernel.arch.init.loadExecutor(executor);

    log.debug("configuring per-executor system features on {}", .{executor.id});
    kernel.arch.init.configurePerExecutorSystemFeatures(executor);

    log.debug("configuring local interrupt controller on {}", .{executor.id});
    kernel.arch.init.initLocalInterruptController();

    log.debug("enabling per-executor interrupt on {}", .{executor.id});
    kernel.time.per_executor_periodic.enableInterrupt(kernel.config.per_executor_interrupt_period);

    try kernel.arch.scheduling.callOneArgs(
        null,
        current_task.stack,
        current_task,
        struct {
            fn initStage3Wrapper(inner_current_task: *kernel.Task) callconv(.C) noreturn {
                initStage3(inner_current_task) catch |err| {
                    std.debug.panic(
                        "unhandled error: {s}",
                        .{@errorName(err)},
                    );
                };
            }
        }.initStage3Wrapper,
    );
    unreachable;
}

/// Stage 3 of kernel initialization.
///
/// This function is executed by all executors, including the bootstrap executor.
///
/// All executors are using their init task's stack.
fn initStage3(current_task: *kernel.Task) !noreturn {
    const executor = current_task.state.running;

    if (executor.id == .bootstrap) {
        Barrier.waitForOthers();

        log.debug("loading standard interrupt handlers", .{});
        kernel.arch.interrupts.init.loadStandardInterruptHandlers();

        log.debug("initializing PCI ECAM", .{});
        try kernel.pci.init.initializeECAM();

        log.debug("initializing ACPI", .{});
        try kernel.acpi.init.initialize();

        try kernel.acpi.init.finializeInitialization();

        {
            Output.globals.lock.lock(current_task);
            defer Output.globals.lock.unlock(current_task);

            Output.writer.print("initialization complete - time since boot: {}\n", .{
                kernel.time.wallclock.elapsed(.zero, kernel.time.wallclock.read()),
            }) catch {};
        }
    }

    Barrier.executorReady();

    // enabling interrupts so we can service IPIs on non-bootstrap executors
    current_task.decrementInterruptDisable();

    Barrier.waitForAll();

    _ = kernel.scheduler.lockScheduler(current_task);

    kernel.scheduler.yield(current_task, .drop);
    @panic("scheduler returned to init");
}

fn createExecutors() ![]kernel.Executor {
    const current_task = kernel.Task.getCurrent();

    var descriptors = kernel.boot.cpuDescriptors() orelse return error.NoSMPFromBootloader;

    if (descriptors.count() > kernel.config.maximum_number_of_executors) {
        std.debug.panic(
            "number of executors '{d}' exceeds maximum '{d}'",
            .{ descriptors.count(), kernel.config.maximum_number_of_executors },
        );
    }

    log.debug("initializing {} executors", .{descriptors.count()});

    // TODO: these init tasks need to be freed after initialization
    const init_tasks = try kernel.heap.allocator.alloc(kernel.Task, descriptors.count());
    const executors = try kernel.heap.allocator.alloc(kernel.Executor, descriptors.count());

    var i: u32 = 0;
    var task_id: u32 = 1; // `1` as `0` is the bootstrap task

    while (descriptors.next()) |desc| : (i += 1) {
        if (i == 0) std.debug.assert(desc.acpiProcessorId() == 0);

        const executor = &executors[i];
        const id: kernel.Executor.Id = @enumFromInt(i);

        const init_task = &init_tasks[i];

        init_task.* = .{
            .id = @enumFromInt(task_id),
            ._name = .{}, // set below
            .state = .{ .running = executor },
            .stack = try kernel.Stack.createStack(current_task),
            .spinlocks_held = 0, // init tasks don't start with the scheduler locked
        };
        task_id += 1;

        try init_task._name.writer().print("init {}", .{i});

        executor.* = .{
            .id = id,
            .arch = undefined, // set by `arch.init.prepareExecutor`
            .current_task = init_task,
            .idle_task = .{
                .id = @enumFromInt(task_id),
                ._name = .{}, // set below
                .state = .ready,
                .stack = try kernel.Stack.createStack(current_task),
                .is_idle_task = true,
            },
        };
        task_id += 1;

        try executor.idle_task._name.writer().print("idle {}", .{i});

        kernel.arch.init.prepareExecutor(
            executor,
            desc.architectureProcessorId(),
            current_task,
        );
    }

    return executors;
}

fn bootNonBootstrapExecutors() !void {
    var descriptors = kernel.boot.cpuDescriptors() orelse return error.NoSMPFromBootloader;
    var i: u32 = 0;

    while (descriptors.next()) |desc| : (i += 1) {
        const executor = &kernel.executors[i];
        if (executor.id == .bootstrap) continue;

        desc.boot(
            executor.current_task,
            struct {
                fn bootFn(user_data: *anyopaque) noreturn {
                    initStage2(@as(*kernel.Task, @ptrCast(@alignCast(user_data)))) catch |err| {
                        std.debug.panic(
                            "unhandled error: {s}",
                            .{@errorName(err)},
                        );
                    };
                }
            }.bootFn,
        );
    }
}

pub const devicetree = @import("devicetree.zig");
pub const Output = @import("output/Output.zig");

const Barrier = struct {
    var executor_count = std.atomic.Value(usize).init(0);

    fn executorReady() void {
        _ = executor_count.fetchAdd(1, .release);
    }

    fn waitForOthers() void {
        while (executor_count.load(.acquire) != (kernel.executors.len - 1)) {
            kernel.arch.spinLoopHint();
        }
    }

    fn waitForAll() void {
        while (executor_count.load(.acquire) != kernel.executors.len) {
            kernel.arch.spinLoopHint();
        }
    }
};

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");
const log = kernel.debug.log.scoped(.init);
