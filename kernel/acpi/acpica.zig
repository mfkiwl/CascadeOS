// SPDX-License-Identifier: MIT

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");

pub const UINT16 = c_ushort;
pub const UINT32 = c_uint;
pub const UINT64 = c_ulonglong;

pub const BOOLEAN = u8;
pub const ACPI_SIZE = UINT64;
pub const ACPI_IO_ADDRESS = UINT64;
pub const ACPI_OWNER_ID = UINT16;

pub const ACPI_TRACE_EVENT_TYPE = c_uint; // TODO - enum
pub const ACPI_EXECUTE_TYPE = c_uint; // TODO - enum

pub const ACPI_OSD_HANDLER = ?*const fn (?*anyopaque) callconv(.C) UINT32;
pub const ACPI_OSD_EXEC_CALLBACK = ?*const fn (?*anyopaque) callconv(.C) void;

pub const ACPI_STATUS = extern struct { // TODO - enum
    value: UINT32,
};

pub const ACPI_NAME_UNION = extern union {
    Integer: UINT32,
    Ascii: [4]u8,
};

pub const ACPI_PREDEFINED_NAMES = extern struct {
    Name: ?[*:0]const u8,
    Type: u8,
    Val: ?*u8,
};

pub const ACPI_TABLE_HEADER = extern struct {
    Signature: [4]u8,
    Length: UINT32,
    Revision: u8,
    Checksum: u8,
    OemId: [6]u8,
    OemTableId: [8]u8,
    OemRevision: UINT32,
    AslCompilerId: [4]u8,
    AslCompilerRevision: UINT32,
};

pub const ACPI_MEMORY_LIST = extern struct {
    ListName: [*:0]const u8,
    ListHead: ?*anyopaque,
    ObjectSize: UINT16,
    MaxDepth: UINT16,
    CurrentDepth: UINT16,
};

pub const ACPI_PCI_ID = extern struct {
    Segment: UINT16,
    Bus: UINT16,
    Device: UINT16,
    Function: UINT16,
};

pub const ACPI_TABLE_DESC = extern struct {
    Address: kernel.PhysicalAddress,
    Pointer: [*c]ACPI_TABLE_HEADER,
    Length: UINT32,
    Signature: ACPI_NAME_UNION,
    OwnerId: ACPI_OWNER_ID,
    Flags: u8,
    ValidationCount: UINT16,
};

pub extern fn AcpiInitializeTables(InitialStorage: [*c]ACPI_TABLE_DESC, InitialTableCount: UINT32, AllowResize: BOOLEAN) ACPI_STATUS;
