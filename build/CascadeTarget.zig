// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Lee Cannon <leecannon@leecannon.xyz>

pub const CascadeTarget = enum {
    arm,
    riscv,
    x64,

    /// Returns a CrossTarget for building targeting the host system.
    pub fn getNonCascadeCrossTarget(self: CascadeTarget, b: *std.Build) std.Build.ResolvedTarget {
        const target_query: std.Target.Query = switch (self) {
            .arm => .{ .cpu_arch = .aarch64 },
            .riscv => .{ .cpu_arch = .riscv64 },
            .x64 => .{ .cpu_arch = .x86_64 },
        };

        return b.resolveTargetQuery(target_query);
    }

    /// Returns a CrossTarget for building targeting cascade.
    pub fn getCascadeCrossTarget(self: CascadeTarget, b: *std.Build) std.Build.ResolvedTarget {
        const target_query: std.Target.Query = switch (self) {
            .arm => .{ .cpu_arch = .aarch64, .os_tag = .other },
            .riscv => .{ .cpu_arch = .riscv64, .os_tag = .other },
            .x64 => .{ .cpu_arch = .x86_64, .os_tag = .other },
        };

        return b.resolveTargetQuery(target_query);
    }

    /// Returns true if the targets architecture is equal to the host systems.
    pub fn isNative(self: CascadeTarget, b: *std.Build) bool {
        return switch (b.graph.host.result.cpu.arch) {
            .aarch64 => self == .arm,
            .riscv64 => self == .riscv,
            .x86_64 => self == .x64,
            else => false,
        };
    }
};

const std = @import("std");
const Step = std.Build.Step;
