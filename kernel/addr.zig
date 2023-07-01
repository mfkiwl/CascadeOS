// SPDX-License-Identifier: MIT

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");

pub const PhysAddr = extern struct {
    value: usize,

    const name = "PhysAddr";

    pub inline fn fromInt(value: usize) PhysAddr {
        // TODO: check that the address is valid (cannoical) https://github.com/CascadeOS/CascadeOS/issues/15
        return .{ .value = value };
    }

    pub inline fn toDirectMap(self: PhysAddr) VirtAddr {
        return .{ .value = self.value + kernel.info.direct_map.addr.value };
    }

    pub inline fn toNonCachedDirectMap(self: PhysAddr) VirtAddr {
        return .{ .value = self.value + kernel.info.non_cached_direct_map.addr.value };
    }

    pub usingnamespace AddrMixin(@This());

    comptime {
        core.testing.expectSize(@This(), @sizeOf(usize));
    }
};

pub const VirtAddr = extern struct {
    value: usize,

    const name = "VirtAddr";

    pub inline fn fromInt(value: usize) VirtAddr {
        // TODO: check that the address is valid (cannoical) https://github.com/CascadeOS/CascadeOS/issues/15
        return .{ .value = value };
    }

    pub inline fn fromPtr(ptr: *const anyopaque) VirtAddr {
        return fromInt(@intFromPtr(ptr));
    }

    pub inline fn toPtr(self: VirtAddr, comptime PtrT: type) PtrT {
        return @ptrFromInt(self.value);
    }

    /// Returns the physical address of the given diret map virtual address.
    ///
    /// ## Safety
    /// It is the caller's responsibility to ensure that the given virtual address is in the direct map.
    pub fn unsafeToPhysicalFromDirectMap(self: VirtAddr) PhysAddr {
        return .{ .value = self.value - kernel.info.direct_map.addr.value };
    }

    /// Returns the physical address of the given virtual address if it is in one of the direct maps.
    pub fn toPhysicalFromDirectMap(self: VirtAddr) error{AddressNotInAnyDirectMap}!PhysAddr {
        if (kernel.info.direct_map.contains(self)) {
            return .{ .value = self.value - kernel.info.direct_map.addr.value };
        }
        if (kernel.info.non_cached_direct_map.contains(self)) {
            return .{ .value = self.value - kernel.info.non_cached_direct_map.addr.value };
        }
        return error.AddressNotInAnyDirectMap;
    }

    pub usingnamespace AddrMixin(@This());

    comptime {
        core.testing.expectSize(@This(), @sizeOf(usize));
    }
};

fn AddrMixin(comptime Self: type) type {
    return struct {
        pub const zero: Self = .{ .value = 0 };

        pub inline fn isAligned(self: Self, alignment: core.Size) bool {
            return std.mem.isAligned(self.value, alignment.bytes);
        }

        pub inline fn moveForward(self: Self, size: core.Size) Self {
            return .{ .value = self.value + size.bytes };
        }

        pub inline fn moveForwardInPlace(self: *Self, size: core.Size) void {
            self.value += size.bytes;
        }

        pub inline fn moveBackward(self: Self, size: core.Size) Self {
            return .{ .value = self.value - size.bytes };
        }

        pub inline fn moveBackwardInPlace(self: *Self, size: core.Size) void {
            self.value -= size.bytes;
        }

        pub inline fn equal(self: Self, other: Self) bool {
            return self.value == other.value;
        }

        pub inline fn lessThan(self: Self, other: Self) bool {
            return self.value < other.value;
        }

        pub inline fn lessThanOrEqual(self: Self, other: Self) bool {
            return self.value <= other.value;
        }

        pub inline fn greaterThan(self: Self, other: Self) bool {
            return self.value > other.value;
        }

        pub inline fn greaterThanOrEqual(self: Self, other: Self) bool {
            return self.value >= other.value;
        }

        pub fn print(self: Self, writer: anytype) !void {
            try writer.writeAll(comptime Self.name ++ "{ 0x");
            try std.fmt.formatInt(self.value, 16, .lower, .{ .width = 16, .fill = '0' }, writer);
            try writer.writeAll(" }");
        }

        pub inline fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            return print(self, writer);
        }
    };
}

pub const PhysRange = struct {
    addr: PhysAddr,
    size: core.Size,

    const name = "PhysRange";

    pub inline fn toDirectMap(self: PhysRange) VirtRange {
        return .{
            .addr = self.addr.toDirectMap(),
            .size = self.size,
        };
    }

    pub usingnamespace RangeMixin(@This(), PhysAddr);
};

pub const VirtRange = struct {
    addr: VirtAddr,
    size: core.Size,

    const name = "VirtRange";

    pub fn fromSlice(slice: anytype) VirtRange {
        const info: std.builtin.Type = @typeInfo(@TypeOf(slice));
        if (info != .Pointer) @compileError(""); // TODO: Add error message
        const pointer_info: std.builtin.Type.Pointer = info.Pointer;
        if (pointer_info.size != .Slice) @compileError(""); // TODO: Add error message
        return .{
            .addr = VirtAddr.fromPtr(slice.ptr),
            .size = core.Size.from(@sizeOf(pointer_info.child) * slice.len, .byte),
        };
    }

    pub fn toSlice(self: VirtRange, comptime T: type) ![]T {
        const len = try std.math.divExact(usize, self.size.bytes, @sizeOf(T));
        return self.addr.toPtr([*]T)[0..len];
    }

    pub usingnamespace RangeMixin(@This(), VirtAddr);
};

fn RangeMixin(comptime Self: type, comptime AddrType: type) type {
    return struct {
        pub inline fn fromAddr(addr: AddrType, size: core.Size) Self {
            return .{
                .addr = addr,
                .size = size,
            };
        }

        pub inline fn end(self: Self) AddrType {
            return self.addr.moveForward(self.size);
        }

        pub inline fn moveForward(self: Self, size: core.Size) Self {
            return .{
                .addr = self.addr.moveForward(size),
                .size = self.size,
            };
        }

        pub inline fn moveForwardInPlace(self: *Self, size: core.Size) void {
            self.addr.moveForwardInPlace(size);
        }

        pub inline fn moveBackward(self: Self, size: core.Size) Self {
            return .{
                .addr = self.addr.moveBackward(size),
                .size = self.size,
            };
        }

        pub inline fn moveBackwardInPlace(self: *Self, size: core.Size) void {
            self.addr.moveBackwardInPlace(size);
        }

        pub fn contains(self: Self, addr: AddrType) bool {
            return addr.greaterThanOrEqual(self.addr) and addr.lessThan(self.end());
        }

        pub fn print(value: Self, writer: anytype) !void {
            try writer.writeAll(Self.name ++ "{ 0x");
            try std.fmt.formatInt(value.addr.value, 16, .lower, .{ .width = 16, .fill = '0' }, writer);

            try writer.writeAll(" - 0x");
            try std.fmt.formatInt(value.end().value, 16, .lower, .{ .width = 16, .fill = '0' }, writer);
            try writer.writeAll(" - ");

            try value.size.print(writer);
            try writer.writeAll(" }");
        }

        pub inline fn format(
            value: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            return print(value, writer);
        }
    };
}
