// SPDX-License-Identifier: MIT

//! Represents a single execution resource.
//!
//! Even though this is called `Processor` it represents a single core in a multi-core system.

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");

const Processor = @This();

id: usize,

panicked: bool = false,

/// The stack used for interrupts and idle.
///
/// Also used for the time between moving away from the bootloader provided stack until we start scheduling.
idle_and_interrupt_stack: kernel.Stack,

_arch: kernel.arch.ArchProcessor,

pub inline fn arch(self: *Processor) *kernel.arch.ArchProcessor {
    return &self._arch;
}

pub const format = core.formatStructIgnoreReservedAndHiddenFields;
