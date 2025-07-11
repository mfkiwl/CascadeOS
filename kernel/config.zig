// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Lee Cannon <leecannon@leecannon.xyz>

// build system provided kernel options
pub const cascade_version = kernel_options.cascade_version;
pub const cascade_target = @import("cascade_target").arch;

// This must be kept in sync with the linker scripts.
pub const kernel_base_address: core.VirtualAddress = .fromInt(0xffffffff80000000);

/// The size of the usable region of a kernel stack.
pub const kernel_stack_size = kernel.arch.paging.standard_page_size.multiplyScalar(16);

pub const maximum_number_of_time_sources = 8;

pub const maximum_number_of_executors = 64;

pub const task_name_length = 32;
pub const resource_arena_name_length = 32;
pub const cache_name_length = 32;

pub const per_executor_interrupt_period = core.Duration.from(5, .millisecond);

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");
const builtin = @import("builtin");
const kernel_options = @import("kernel_options");
