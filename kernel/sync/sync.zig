// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");

pub const TicketSpinLock = @import("TicketSpinLock.zig");

pub fn getInterruptExclusion() Exclusion {
    kernel.arch.interrupts.disableInterrupts();

    const cpu = kernel.arch.rawGetCpu();

    cpu.interrupt_disable_count += 1;

    return .{ .cpu = cpu };
}

pub const Exclusion = struct {
    cpu: *kernel.Cpu,

    pub fn release(self: Exclusion) void {
        core.debugAssert(!kernel.arch.interrupts.interruptsEnabled());

        const old_interrupt_disable_count = self.cpu.interrupt_disable_count;
        core.debugAssert(old_interrupt_disable_count != 0);

        self.cpu.interrupt_disable_count -= 1;

        if (old_interrupt_disable_count == 1) kernel.arch.interrupts.enableInterrupts();
    }
};
