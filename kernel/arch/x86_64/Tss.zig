// SPDX-License-Identifier: MIT

const core = @import("core");
const interrupts = x86_64.interrupts;
const InterruptStackSelector = interrupts.InterruptStackSelector;
const kernel = @import("kernel");
const PrivilegeLevel = x86_64.PrivilegeLevel;
const std = @import("std");
const task = kernel.task;
const VirtualAddress = kernel.VirtualAddress;
const x86_64 = @import("x86_64.zig");

/// The x86_64 Task State Segment structure.
pub const Tss = extern struct {
    _reserved_1: u32 align(1) = 0,

    /// Stack pointers (RSP) for privilege levels 0-2.
    privilege_stack_table: [3]VirtualAddress align(1) = [_]VirtualAddress{VirtualAddress.zero} ** 3,

    _reserved_2: u64 align(1) = 0,

    /// Interrupt stack table (IST) pointers.
    interrupt_stack_table: [7]VirtualAddress align(1) = [_]VirtualAddress{VirtualAddress.zero} ** 7,

    _reserved_3: u64 align(1) = 0,

    _reserved_4: u16 align(1) = 0,

    /// The 16-bit offset to the I/O permission bit map from the 64-bit TSS base.
    iomap_base: u16 align(1) = 0,

    /// Sets the stack for the given stack selector.
    pub fn setInterruptStack(self: *Tss, stack_selector: InterruptStackSelector, stack: task.Stack) void {
        self.interrupt_stack_table[@intFromEnum(stack_selector)] = stack.stack_pointer;
    }

    /// Sets the stack for the given privilege level.
    pub fn setPrivilegeStack(self: *Tss, privilege_level: PrivilegeLevel, stack: task.Stack) void {
        core.assert(privilege_level != .user);
        self.privilege_stack_table[@intFromEnum(privilege_level)] = stack.stack_pointer;
    }

    comptime {
        core.testing.expectSize(@This(), 104);
    }
};
