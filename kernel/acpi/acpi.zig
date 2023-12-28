// SPDX-License-Identifier: MIT

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");

const log = kernel.debug.log.scoped(.acpi);

const acpica = @import("acpica.zig");

pub const init = struct {
    var early_tables: [16]acpica.ACPI_TABLE_DESC linksection(kernel.info.init_data) = undefined;

    pub fn earlyInitAcpiTables() linksection(kernel.info.init_code) void {
        const result = acpica.AcpiInitializeTables(&early_tables, 16, 1);
        log.debug("AcpiInitializeTables result: {}", .{result});
    }
};

comptime {
    _ = &@import("acpica_os_layer.zig");
}
