// SPDX-License-Identifier: MIT

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");

const log = kernel.debug.log.scoped(.acpi);

const acpica = @import("acpica.zig");

export fn AcpiOsInitialize() acpica.ACPI_STATUS {
    core.panic("TODO: AcpiOsInitialize");
}

export fn AcpiOsTerminate() acpica.ACPI_STATUS {
    core.panic("TODO: AcpiOsTerminate");
}

/// Obtain the Root ACPI table pointer (RSDP).
export fn AcpiOsGetRootPointer() kernel.PhysicalAddress {
    const higher_half_address = kernel.boot.rsdp() orelse core.panic("no rsdp pointer");
    return higher_half_address.toPhysicalFromDirectMap() catch core.panic("rsdp pointer is not in the direct map");
}

export fn AcpiOsPredefinedOverride(InitVal: [*c]const acpica.ACPI_PREDEFINED_NAMES, NewVal: [*c][*:0]u8) acpica.ACPI_STATUS {
    _ = InitVal;
    _ = NewVal;

    core.panic("TODO: AcpiOsPredefinedOverride");
}

export fn AcpiOsTableOverride(ExistingTable: [*c]acpica.ACPI_TABLE_HEADER, NewTable: [*c][*c]acpica.ACPI_TABLE_HEADER) acpica.ACPI_STATUS {
    _ = ExistingTable;
    _ = NewTable;

    core.panic("TODO: AcpiOsTableOverride");
}

export fn AcpiOsPhysicalTableOverride(ExistingTable: [*c]acpica.ACPI_TABLE_HEADER, NewAddress: [*c]kernel.PhysicalAddress, NewTableLength: [*c]acpica.UINT32) acpica.ACPI_STATUS {
    _ = ExistingTable;
    _ = NewAddress;
    _ = NewTableLength;

    core.panic("TODO: AcpiOsPhysicalTableOverride");
}

export fn AcpiOsCreateLock(OutHandle: [*c]?*anyopaque) acpica.ACPI_STATUS {
    _ = OutHandle;

    core.panic("TODO: AcpiOsCreateLock");
}

export fn AcpiOsDeleteLock(Handle: ?*anyopaque) void {
    _ = Handle;

    core.panic("TODO: AcpiOsDeleteLock");
}

export fn AcpiOsAcquireLock(Handle: ?*anyopaque) acpica.ACPI_SIZE {
    _ = Handle;

    core.panic("TODO: AcpiOsAcquireLock");
}

export fn AcpiOsReleaseLock(Handle: ?*anyopaque, Flags: acpica.ACPI_SIZE) void {
    _ = Handle;
    _ = Flags;

    core.panic("TODO: AcpiOsReleaseLock");
}

export fn AcpiOsCreateSemaphore(MaxUnits: acpica.UINT32, InitialUnits: acpica.UINT32, OutHandle: [*c]?*anyopaque) acpica.ACPI_STATUS {
    _ = MaxUnits;
    _ = InitialUnits;
    _ = OutHandle;

    core.panic("TODO: AcpiOsCreateSemaphore");
}

export fn AcpiOsDeleteSemaphore(Handle: ?*anyopaque) acpica.ACPI_STATUS {
    _ = Handle;

    core.panic("TODO: AcpiOsDeleteSemaphore");
}

export fn AcpiOsWaitSemaphore(Handle: ?*anyopaque, Units: acpica.UINT32, Timeout: acpica.UINT16) acpica.ACPI_STATUS {
    _ = Handle;
    _ = Units;
    _ = Timeout;

    core.panic("TODO: AcpiOsWaitSemaphore");
}

export fn AcpiOsSignalSemaphore(Handle: ?*anyopaque, Units: acpica.UINT32) acpica.ACPI_STATUS {
    _ = Handle;
    _ = Units;

    core.panic("TODO: AcpiOsSignalSemaphore");
}

export fn AcpiOsAllocate(Size: acpica.ACPI_SIZE) ?*anyopaque {
    _ = Size;

    core.panic("TODO: AcpiOsAllocate");
}

export fn AcpiOsFree(Memory: ?*anyopaque) void {
    _ = Memory;

    core.panic("TODO: AcpiOsFree");
}

/// Map physical memory into the caller’s address space
export fn AcpiOsMapMemory(Where: kernel.PhysicalAddress, Length: acpica.ACPI_SIZE) kernel.VirtualAddress {
    _ = Length;

    // Just use the higher half direct map

    return Where.toDirectMap();
}

/// Remove a physical to logical memory mapping
export fn AcpiOsUnmapMemory(LogicalAddress: ?*anyopaque, Size: acpica.ACPI_SIZE) void {
    _ = LogicalAddress;
    _ = Size;

    // As we are using the higher half direct map, we don't need to do anything
}

export fn AcpiOsGetPhysicalAddress(LogicalAddress: ?*anyopaque, PhysicalAddress: [*c]kernel.PhysicalAddress) acpica.ACPI_STATUS {
    _ = LogicalAddress;
    _ = PhysicalAddress;

    core.panic("TODO: AcpiOsGetPhysicalAddress");
}

export fn AcpiOsInstallInterruptHandler(InterruptNumber: acpica.UINT32, ServiceRoutine: acpica.ACPI_OSD_HANDLER, Context: ?*anyopaque) acpica.ACPI_STATUS {
    _ = InterruptNumber;
    _ = ServiceRoutine;
    _ = Context;

    core.panic("TODO: AcpiOsInstallInterruptHandler");
}

export fn AcpiOsRemoveInterruptHandler(InterruptNumber: acpica.UINT32, ServiceRoutine: acpica.ACPI_OSD_HANDLER) acpica.ACPI_STATUS {
    _ = InterruptNumber;
    _ = ServiceRoutine;

    core.panic("TODO: AcpiOsRemoveInterruptHandler");
}

export fn AcpiOsGetThreadId() acpica.UINT64 {
    const interrupt_guard = kernel.arch.interrupts.interruptGuard();
    defer interrupt_guard.release();

    const processor = kernel.arch.getProcessor();

    if (processor.current_thread) |thread| return @intFromPtr(thread);

    return @intFromPtr(processor);
}

export fn AcpiOsExecute(Type: acpica.ACPI_EXECUTE_TYPE, Function: acpica.ACPI_OSD_EXEC_CALLBACK, Context: ?*anyopaque) acpica.ACPI_STATUS {
    _ = Type;
    _ = Function;
    _ = Context;

    core.panic("TODO: AcpiOsExecute");
}

export fn AcpiOsWaitEventsComplete() void {
    core.panic("TODO: AcpiOsWaitEventsComplete");
}

export fn AcpiOsSleep(Milliseconds: acpica.UINT64) void {
    _ = Milliseconds;

    core.panic("TODO: AcpiOsSleep");
}

export fn AcpiOsStall(Microseconds: acpica.UINT32) void {
    _ = Microseconds;

    core.panic("TODO: AcpiOsStall");
}

export fn AcpiOsReadPort(Address: acpica.ACPI_IO_ADDRESS, Value: [*c]acpica.UINT32, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = Address;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsReadPort");
}

export fn AcpiOsWritePort(Address: acpica.ACPI_IO_ADDRESS, Value: acpica.UINT32, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = Address;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsWritePort");
}

export fn AcpiOsReadMemory(Address: kernel.PhysicalAddress, Value: [*c]acpica.UINT64, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = Address;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsReadMemory");
}

export fn AcpiOsWriteMemory(Address: kernel.PhysicalAddress, Value: acpica.UINT64, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = Address;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsWriteMemory");
}

export fn AcpiOsReadPciConfiguration(PciId: [*c]acpica.ACPI_PCI_ID, Reg: acpica.UINT32, Value: [*c]acpica.UINT64, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = PciId;
    _ = Reg;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsReadPciConfiguration");
}

export fn AcpiOsWritePciConfiguration(PciId: [*c]acpica.ACPI_PCI_ID, Reg: acpica.UINT32, Value: acpica.UINT64, Width: acpica.UINT32) acpica.ACPI_STATUS {
    _ = PciId;
    _ = Reg;
    _ = Value;
    _ = Width;

    core.panic("TODO: AcpiOsWritePciConfiguration");
}

export fn AcpiOsReadable(Pointer: ?*anyopaque, Length: acpica.ACPI_SIZE) acpica.BOOLEAN {
    _ = Pointer;
    _ = Length;

    core.panic("TODO: AcpiOsReadable");
}

export fn AcpiOsWritable(Pointer: ?*anyopaque, Length: acpica.ACPI_SIZE) acpica.BOOLEAN {
    _ = Pointer;
    _ = Length;

    core.panic("TODO: AcpiOsWritable");
}

export fn AcpiOsGetTimer() acpica.UINT64 {
    core.panic("TODO: AcpiOsGetTimer");
}

export fn AcpiOsSignal(Function: acpica.UINT32, Info: ?*anyopaque) acpica.ACPI_STATUS {
    _ = Function;
    _ = Info;
    core.panic("TODO: AcpiOsSignal");
}

export fn AcpiOsEnterSleep(SleepState: u8, RegaValue: acpica.UINT32, RegbValue: acpica.UINT32) acpica.ACPI_STATUS {
    _ = SleepState;
    _ = RegaValue;
    _ = RegbValue;
    core.panic("TODO: AcpiOsEnterSleep");
}

export fn AcpiOsPrintf(Format: [*c]const u8, ...) void {
    _ = Format;
    core.panic("TODO: AcpiOsPrintf");
}

export fn AcpiOsVprintf(Format: [*c]const u8, Args: *anyopaque) void {
    _ = Format;
    _ = Args;
    core.panic("TODO: AcpiOsVprintf");
}

export fn AcpiOsRedirectOutput(Destination: ?*anyopaque) void {
    _ = Destination;

    core.panic("TODO: AcpiOsRedirectOutput");
}

export fn AcpiOsGetLine(Buffer: [*c]u8, BufferLength: acpica.UINT32, BytesRead: [*c]acpica.UINT32) acpica.ACPI_STATUS {
    _ = Buffer;
    _ = BufferLength;
    _ = BytesRead;
    core.panic("TODO: AcpiOsGetLine");
}

export fn AcpiOsInitializeDebugger() acpica.ACPI_STATUS {
    core.panic("TODO: AcpiOsInitializeDebugger");
}

export fn AcpiOsTerminateDebugger() void {
    core.panic("TODO: AcpiOsTerminateDebugger");
}

export fn AcpiOsWaitCommandReady() acpica.ACPI_STATUS {
    core.panic("TODO: AcpiOsWaitCommandReady");
}

export fn AcpiOsNotifyCommandComplete() acpica.ACPI_STATUS {
    core.panic("TODO: AcpiOsNotifyCommandComplete");
}

export fn AcpiOsTracePoint(Type: acpica.ACPI_TRACE_EVENT_TYPE, Begin: acpica.BOOLEAN, Aml: [*c]u8, Pathname: [*c]u8) void {
    _ = Type;
    _ = Begin;
    _ = Aml;
    _ = Pathname;
    core.panic("TODO: AcpiOsTracePoint");
}

export fn AcpiOsGetTableByName(Signature: [*c]u8, Instance: acpica.UINT32, Table: [*c][*c]acpica.ACPI_TABLE_HEADER, Address: [*c]kernel.PhysicalAddress) acpica.ACPI_STATUS {
    _ = Signature;
    _ = Instance;
    _ = Table;
    _ = Address;
    core.panic("TODO: AcpiOsGetTableByName");
}

export fn AcpiOsGetTableByIndex(Index: acpica.UINT32, Table: [*c][*c]acpica.ACPI_TABLE_HEADER, Instance: [*c]acpica.UINT32, Address: [*c]kernel.PhysicalAddress) acpica.ACPI_STATUS {
    _ = Index;
    _ = Table;
    _ = Instance;
    _ = Address;
    core.panic("TODO: AcpiOsGetTableByIndex");
}

export fn AcpiOsGetTableByAddress(Address: kernel.PhysicalAddress, Table: [*c][*c]acpica.ACPI_TABLE_HEADER) acpica.ACPI_STATUS {
    _ = Address;
    _ = Table;
    core.panic("TODO: AcpiOsGetTableByAddress");
}

export fn AcpiOsOpenDirectory(Pathname: [*c]u8, WildcardSpec: [*c]u8, RequestedFileType: u8) ?*anyopaque {
    _ = Pathname;
    _ = WildcardSpec;
    _ = RequestedFileType;
    core.panic("TODO: AcpiOsOpenDirectory");
}

export fn AcpiOsGetNextFilename(DirHandle: ?*anyopaque) [*c]u8 {
    _ = DirHandle;
    core.panic("TODO: AcpiOsGetNextFilename");
}

export fn AcpiOsCloseDirectory(DirHandle: ?*anyopaque) void {
    _ = DirHandle;
    core.panic("TODO: AcpiOsCloseDirectory");
}

// export fn AcpiOsAllocateZeroed(Size: acpica.ACPI_SIZE) ?*anyopaque {
//     _ = Size;

//     core.panic("TODO: AcpiOsAllocateZeroed");
// }

// export fn AcpiOsCreateCache(CacheName: [*c]u8, ObjectSize: acpica.UINT16, MaxDepth: acpica.UINT16, ReturnCache: [*c][*c]acpica.ACPI_MEMORY_LIST) acpica.ACPI_STATUS {
//     _ = CacheName;
//     _ = ObjectSize;
//     _ = MaxDepth;
//     _ = ReturnCache;

//     core.panic("TODO: AcpiOsCreateCache");
// }

// export fn AcpiOsDeleteCache(Cache: [*c]acpica.ACPI_MEMORY_LIST) acpica.ACPI_STATUS {
//     _ = Cache;

//     core.panic("TODO: AcpiOsDeleteCache");
// }

// export fn AcpiOsPurgeCache(Cache: [*c]acpica.ACPI_MEMORY_LIST) acpica.ACPI_STATUS {
//     _ = Cache;

//     core.panic("TODO: AcpiOsPurgeCache");
// }

// export fn AcpiOsAcquireObject(Cache: [*c]acpica.ACPI_MEMORY_LIST) ?*anyopaque {
//     _ = Cache;

//     core.panic("TODO: AcpiOsAcquireObject");
// }

// export fn AcpiOsReleaseObject(Cache: [*c]acpica.ACPI_MEMORY_LIST, Object: ?*anyopaque) acpica.ACPI_STATUS {
//     _ = Cache;
//     _ = Object;

//     core.panic("TODO: AcpiOsReleaseObject");
// }
