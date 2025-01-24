// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Lee Cannon <leecannon@leecannon.xyz>

pub const interrupts = @import("interrupts.zig");
pub const paging = @import("paging.zig");
pub const PerExecutor = @import("PerExecutor.zig");
pub const scheduling = @import("scheduling.zig");

pub const init = @import("init.zig");

/// Get the current `Executor`.
///
/// Assumes that `init.loadExecutor()` has been called on the currently running CPU.
pub fn getCurrentExecutor() *kernel.Executor {
    return @ptrFromInt(lib_arm64.registers.TPIDR_EL1.read());
}

pub const spinLoopHint = lib_arm64.instructions.isb;

pub const io = struct {
    pub const Port = u64;
};

const std = @import("std");
const kernel = @import("kernel");
const lib_arm64 = @import("arm64");
