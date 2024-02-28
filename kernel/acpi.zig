// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");

const acpi = @import("acpi");

const log = kernel.debug.log.scoped(.acpi);

pub const init = struct {
    /// Initialized during `initializeACPITables`.
    var sdt_header: *const acpi.SharedHeader linksection(kernel.info.init_data) = undefined;

    /// Initializes access to the ACPI tables.
    pub fn initializeACPITables() linksection(kernel.info.init_code) void {
        const rsdp_address = kernel.boot.rsdp() orelse core.panic("RSDP not provided by bootloader");
        const rsdp = rsdp_address.toPtr(*const acpi.RSDP);

        log.debug("ACPI revision: {d}", .{rsdp.revision});

        log.debug("validating rsdp", .{});
        if (!rsdp.isValid()) core.panic("invalid RSDP");

        sdt_header = kernel.physicalToDirectMap(rsdp.sdtAddress()).toPtr(*const acpi.SharedHeader);

        log.debug("validating sdt", .{});
        if (!sdt_header.isValid()) core.panic("invalid SDT");

        if (kernel.debug.log.loggingEnabledFor(.acpi, .debug)) {
            var iterator = acpi.tableIterator(sdt_header);

            log.debug("ACPI tables:", .{});

            while (iterator.next()) |physical_address| {
                const table = core.PhysicalAddress
                    .fromInt(physical_address)
                    .toDirectMap()
                    .toPtr(*const acpi.SharedHeader);

                log.debug("  {s}", .{table.signatureAsString()});
            }
        }
    }

    /// Get the ACPI table if present.
    ///
    /// Uses the `SIGNATURE_STRING: *const [4]u8` decl on the given `T` to find the table.
    ///
    /// If the table is not valid, returns `null`.
    pub fn getTable(comptime T: type) linksection(kernel.info.init_code) ?*const T {
        const helper = struct {
            fn physicalToValidVirtualAddress(phys_addr: core.PhysicalAddress) core.VirtualAddress {
                return kernel.physicalToDirectMap(phys_addr);
            }
        };

        var iter = acpi.tableIterator(
            sdt_header,
            helper.physicalToValidVirtualAddress,
        );

        while (iter.next()) |header| {
            if (!header.signatureIs(T.SIGNATURE_STRING)) continue;

            if (!header.isValid()) {
                log.warn("invalid table: {s}", .{header.signatureAsString()});
                return null;
            }

            return @ptrCast(header);
        }

        return null;
    }
};
