// SPDX-License-Identifier: MIT

const std = @import("std");
const Step = std.Build.Step;

const helpers = @import("helpers.zig");

const CascadeTarget = @import("CascadeTarget.zig").CascadeTarget;
const Library = @import("Library.zig");
const Options = @import("Options.zig");
const StepCollection = @import("StepCollection.zig");

const Kernel = @This();

b: *std.Build,

target: CascadeTarget,
options: Options,

install_step: *Step.InstallArtifact,

/// only used for generating a dependency graph
dependencies: []const *const Library,

pub const Collection = std.AutoHashMapUnmanaged(CascadeTarget, Kernel);

pub fn getKernels(
    b: *std.Build,
    step_collection: StepCollection,
    libraries: Library.Collection,
    options: Options,
    targets: []const CascadeTarget,
) !Collection {
    var kernels: Collection = .{};
    try kernels.ensureTotalCapacity(b.allocator, @intCast(targets.len));

    const source_file_modules = try getSourceFileModules(b, libraries);

    for (targets) |target| {
        const kernel = try Kernel.create(b, target, libraries, options, source_file_modules);
        kernels.putAssumeCapacityNoClobber(target, kernel);
        step_collection.registerKernel(target, &kernel.install_step.step);
    }

    return kernels;
}

fn create(
    b: *std.Build,
    target: CascadeTarget,
    libraries: Library.Collection,
    options: Options,
    source_file_modules: []const SourceFileModule,
) !Kernel {
    const kernel_exe = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = helpers.pathJoinFromRoot(b, &.{ "kernel", "root.zig" }) },
        .target = target.getKernelCrossTarget(),
        .optimize = options.optimize,
    });

    kernel_exe.setLinkerScriptPath(.{ .path = target.linkerScriptPath(b) });

    const declared_dependencies: []const []const u8 = @import("../kernel/dependencies.zig").dependencies;
    var dependencies = try std.ArrayListUnmanaged(*const Library).initCapacity(b.allocator, declared_dependencies.len);
    defer dependencies.deinit(b.allocator);

    const kernel_module = blk: {
        const kernel_module = b.createModule(.{
            .source_file = .{ .path = helpers.pathJoinFromRoot(b, &.{ "kernel", "kernel.zig" }) },
        });

        // self reference
        try kernel_module.dependencies.put("kernel", kernel_module);

        // target options
        try kernel_module.dependencies.put("cascade_target", options.target_specific_kernel_options_modules.get(target).?);

        // kernel options
        try kernel_module.dependencies.put("kernel_options", options.kernel_option_module);

        // dependencies

        for (declared_dependencies) |dependency| {
            const library = libraries.get(dependency).?;
            const library_module = library.cascade_modules.get(target) orelse continue;
            try kernel_module.dependencies.put(library.name, library_module);
            dependencies.appendAssumeCapacity(library);
        }

        // source file modules
        for (source_file_modules) |module| {
            try kernel_module.dependencies.put(module.name, module.module);
        }

        break :blk kernel_module;
    };

    kernel_exe.addModule("kernel", kernel_module);

    addAcpica(b, kernel_exe);

    kernel_exe.want_lto = false;
    kernel_exe.pie = true;
    kernel_exe.omit_frame_pointer = false;

    target.targetSpecificSetup(kernel_exe);

    // Add assembly files
    assembly_files_blk: {
        const assembly_files_dir_path = helpers.pathJoinFromRoot(b, &.{
            "kernel",
            "arch",
            @tagName(target),
            "asm",
        });

        var assembly_files_dir = std.fs.cwd().openDir(assembly_files_dir_path, .{ .iterate = true }) catch break :assembly_files_blk;
        defer assembly_files_dir.close();

        var iter = assembly_files_dir.iterateAssumeFirstIteration();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) {
                std.debug.panic(
                    "found entry '{s}' with unexpected type '{s}' in assembly directory '{s}'\n",
                    .{ entry.name, @tagName(entry.kind), assembly_files_dir_path },
                );
            }

            const file_path = b.pathJoin(&.{ assembly_files_dir_path, entry.name });
            kernel_exe.addAssemblyFile(.{ .path = file_path });
        }
    }

    const install_step = b.addInstallArtifact(
        kernel_exe,
        .{ .dest_dir = .{ .override = .{ .custom = b.pathJoin(&.{@tagName(target)}) } } },
    );

    return Kernel{
        .b = b,
        .target = target,
        .options = options,
        .install_step = install_step,

        .dependencies = try dependencies.toOwnedSlice(b.allocator),
    };
}

fn addAcpica(b: *std.Build, exe: *Step.Compile) void {
    const acpica_dep = b.dependency("acpica", .{});

    const c_flags: []const []const u8 = &[_][]const u8{
        "-std=c99",
        "-D__CASCADEOS__",
        "-DACPI_MACHINE_WIDTH=64",
        "-DACPI_USE_LOCAL_CACHE=1",
        "-DACPI_NO_ERROR_MESSAGES",
        "-fno-sanitize=undefined", // FIXME
    };

    exe.addIncludePath(.{ .dependency = .{ .dependency = acpica_dep, .sub_path = "source/include" } });

    exe.addCSourceFiles(.{
        .dependency = acpica_dep,
        .files = &.{
            // dispatcher
            "source/components/dispatcher/dsargs.c",
            "source/components/dispatcher/dscontrol.c",
            "source/components/dispatcher/dsdebug.c",
            "source/components/dispatcher/dsfield.c",
            "source/components/dispatcher/dsinit.c",
            "source/components/dispatcher/dsmethod.c",
            "source/components/dispatcher/dsmthdat.c",
            "source/components/dispatcher/dsobject.c",
            "source/components/dispatcher/dsopcode.c",
            "source/components/dispatcher/dspkginit.c",
            "source/components/dispatcher/dsutils.c",
            "source/components/dispatcher/dswexec.c",
            "source/components/dispatcher/dswload2.c",
            "source/components/dispatcher/dswload.c",
            "source/components/dispatcher/dswscope.c",
            "source/components/dispatcher/dswstate.c",
            // events
            "source/components/events/evevent.c",
            "source/components/events/evglock.c",
            "source/components/events/evgpeblk.c",
            "source/components/events/evgpe.c",
            "source/components/events/evgpeinit.c",
            "source/components/events/evgpeutil.c",
            "source/components/events/evhandler.c",
            "source/components/events/evmisc.c",
            "source/components/events/evregion.c",
            "source/components/events/evrgnini.c",
            "source/components/events/evsci.c",
            "source/components/events/evxface.c",
            "source/components/events/evxfevnt.c",
            "source/components/events/evxfgpe.c",
            "source/components/events/evxfregn.c",
            // executer
            "source/components/executer/exconcat.c",
            "source/components/executer/exconfig.c",
            "source/components/executer/exconvrt.c",
            "source/components/executer/excreate.c",
            "source/components/executer/exdebug.c",
            "source/components/executer/exdump.c",
            "source/components/executer/exfield.c",
            "source/components/executer/exfldio.c",
            "source/components/executer/exmisc.c",
            "source/components/executer/exmutex.c",
            "source/components/executer/exnames.c",
            "source/components/executer/exoparg1.c",
            "source/components/executer/exoparg2.c",
            "source/components/executer/exoparg3.c",
            "source/components/executer/exoparg6.c",
            "source/components/executer/exprep.c",
            "source/components/executer/exregion.c",
            "source/components/executer/exresnte.c",
            "source/components/executer/exresolv.c",
            "source/components/executer/exresop.c",
            "source/components/executer/exserial.c",
            "source/components/executer/exstore.c",
            "source/components/executer/exstoren.c",
            "source/components/executer/exstorob.c",
            "source/components/executer/exsystem.c",
            "source/components/executer/extrace.c",
            "source/components/executer/exutils.c",
            // hardware
            "source/components/hardware/hwacpi.c",
            "source/components/hardware/hwesleep.c",
            "source/components/hardware/hwgpe.c",
            "source/components/hardware/hwpci.c",
            "source/components/hardware/hwregs.c",
            "source/components/hardware/hwsleep.c",
            "source/components/hardware/hwtimer.c",
            "source/components/hardware/hwvalid.c",
            "source/components/hardware/hwxface.c",
            "source/components/hardware/hwxfsleep.c",
            // namespace
            "source/components/namespace/nsaccess.c",
            "source/components/namespace/nsalloc.c",
            "source/components/namespace/nsarguments.c",
            "source/components/namespace/nsconvert.c",
            "source/components/namespace/nsdump.c",
            "source/components/namespace/nsdumpdv.c",
            "source/components/namespace/nseval.c",
            "source/components/namespace/nsinit.c",
            "source/components/namespace/nsload.c",
            "source/components/namespace/nsnames.c",
            "source/components/namespace/nsobject.c",
            "source/components/namespace/nsparse.c",
            "source/components/namespace/nspredef.c",
            "source/components/namespace/nsprepkg.c",
            "source/components/namespace/nsrepair2.c",
            "source/components/namespace/nsrepair.c",
            "source/components/namespace/nssearch.c",
            "source/components/namespace/nsutils.c",
            "source/components/namespace/nswalk.c",
            "source/components/namespace/nsxfeval.c",
            "source/components/namespace/nsxfname.c",
            "source/components/namespace/nsxfobj.c",
            // parser
            "source/components/parser/psargs.c",
            "source/components/parser/psloop.c",
            "source/components/parser/psobject.c",
            "source/components/parser/psopcode.c",
            "source/components/parser/psopinfo.c",
            "source/components/parser/psparse.c",
            "source/components/parser/psscope.c",
            "source/components/parser/pstree.c",
            "source/components/parser/psutils.c",
            "source/components/parser/pswalk.c",
            "source/components/parser/psxface.c",
            // resources
            "source/components/resources/rsaddr.c",
            "source/components/resources/rscalc.c",
            "source/components/resources/rscreate.c",
            // "source/components/resources/rsdump.c",
            "source/components/resources/rsdumpinfo.c",
            "source/components/resources/rsinfo.c",
            "source/components/resources/rsio.c",
            "source/components/resources/rsirq.c",
            "source/components/resources/rslist.c",
            "source/components/resources/rsmemory.c",
            "source/components/resources/rsmisc.c",
            "source/components/resources/rsserial.c",
            "source/components/resources/rsutils.c",
            "source/components/resources/rsxface.c",
            // tables
            "source/components/tables/tbdata.c",
            "source/components/tables/tbfadt.c",
            "source/components/tables/tbfind.c",
            "source/components/tables/tbinstal.c",
            "source/components/tables/tbprint.c",
            "source/components/tables/tbutils.c",
            "source/components/tables/tbxface.c",
            "source/components/tables/tbxfload.c",
            "source/components/tables/tbxfroot.c",
            // utilities
            "source/components/utilities/utaddress.c",
            "source/components/utilities/utalloc.c",
            "source/components/utilities/utascii.c",
            "source/components/utilities/utbuffer.c",
            "source/components/utilities/utcache.c",
            "source/components/utilities/utcksum.c",
            "source/components/utilities/utclib.c",
            "source/components/utilities/utcopy.c",
            "source/components/utilities/utdebug.c",
            "source/components/utilities/utdecode.c",
            "source/components/utilities/utdelete.c",
            "source/components/utilities/uterror.c",
            "source/components/utilities/uteval.c",
            "source/components/utilities/utexcep.c",
            "source/components/utilities/utglobal.c",
            "source/components/utilities/uthex.c",
            "source/components/utilities/utids.c",
            "source/components/utilities/utinit.c",
            "source/components/utilities/utlock.c",
            "source/components/utilities/utmath.c",
            "source/components/utilities/utmisc.c",
            "source/components/utilities/utmutex.c",
            "source/components/utilities/utnonansi.c",
            "source/components/utilities/utobject.c",
            "source/components/utilities/utosi.c",
            "source/components/utilities/utownerid.c",
            "source/components/utilities/utpredef.c",
            "source/components/utilities/utprint.c",
            "source/components/utilities/utresdecode.c",
            "source/components/utilities/utresrc.c",
            "source/components/utilities/utstate.c",
            "source/components/utilities/utstring.c",
            "source/components/utilities/utstrsuppt.c",
            "source/components/utilities/utstrtoul64.c",
            "source/components/utilities/uttrack.c",
            "source/components/utilities/utuuid.c",
            "source/components/utilities/utxface.c",
            "source/components/utilities/utxferror.c",
            "source/components/utilities/utxfinit.c",
            "source/components/utilities/utxfmutex.c",
        },
        .flags = c_flags,
    });
}

/// Module created from a source file.
const SourceFileModule = struct {
    /// The file name and also the name of the module.
    name: []const u8,
    module: *std.Build.Module,
};

/// Build the data for a source file map.
///
/// Returns a `std.Build.Module` per source file with the name of the file as the module import name,
/// with a `embedded_source_files` module containing an array of the file names.
///
/// This allows combining `ComptimeStringHashMap` and `@embedFile(file_name)`, providing access to the contents of
/// source files by file path key, which is exactly what is needed for printing source code in stacktraces.
fn getSourceFileModules(b: *std.Build, libraries: Library.Collection) ![]const SourceFileModule {
    var modules = std.ArrayList(SourceFileModule).init(b.allocator);
    errdefer modules.deinit();

    var file_paths = std.ArrayList([]const u8).init(b.allocator);
    defer file_paths.deinit();

    const root_path = std.fmt.allocPrint(
        b.allocator,
        comptime "{s}" ++ std.fs.path.sep_str,
        .{b.build_root.path.?},
    ) catch unreachable;

    // add the kernel's files
    try addFilesRecursive(b, &modules, &file_paths, root_path, helpers.pathJoinFromRoot(b, &.{"kernel"}));

    // add each dependencies files
    const kernel_dependencies: []const []const u8 = @import("../kernel/dependencies.zig").dependencies;
    var processed_libraries = std.AutoHashMap(*Library, void).init(b.allocator);

    for (kernel_dependencies) |library_name| {
        const library: *Library = libraries.get(library_name).?;
        try addFilesFromLibrary(b, &modules, &file_paths, root_path, libraries, library, &processed_libraries);
    }

    const files_option = b.addOptions();
    files_option.addOption([]const []const u8, "file_paths", file_paths.items);
    try modules.append(.{ .name = "embedded_source_files", .module = files_option.createModule() });

    return try modules.toOwnedSlice();
}

fn addFilesFromLibrary(
    b: *std.Build,
    modules: *std.ArrayList(SourceFileModule),
    file_paths: *std.ArrayList([]const u8),
    root_path: []const u8,
    libraries: Library.Collection,
    library: *Library,
    processed_libraries: *std.AutoHashMap(*Library, void),
) !void {
    if (processed_libraries.contains(library)) return;

    try addFilesRecursive(b, modules, file_paths, root_path, library.directory_path);

    try processed_libraries.put(library, {});

    for (library.dependencies) |dep| {
        try addFilesFromLibrary(b, modules, file_paths, root_path, libraries, dep, processed_libraries);
    }
}

/// Adds all files recursively in the given target path to the build.
///
/// Creates a `SourceFileModule` for each `.zig` file found, and adds the file path to the `files` array.
fn addFilesRecursive(
    b: *std.Build,
    modules: *std.ArrayList(SourceFileModule),
    files: *std.ArrayList([]const u8),
    root_path: []const u8,
    target_path: []const u8,
) !void {
    var dir = try std.fs.cwd().openDir(target_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();

    while (try it.next()) |file| {
        switch (file.kind) {
            .file => {
                const extension = std.fs.path.extension(file.name);
                // for now only zig files should be included
                if (std.mem.eql(u8, extension, ".zig")) {
                    const path = b.pathJoin(&.{ target_path, file.name });

                    if (removeRootPrefixFromPath(path, root_path)) |name| {
                        try files.append(name);
                        const module = b.createModule(.{
                            .source_file = .{ .path = path },
                        });
                        try modules.append(.{ .name = name, .module = module });
                    } else {
                        // If the file does not start with the root path, what does that even mean?
                        std.debug.panic("file is not in root path: '{s}'", .{path});
                    }
                }
            },
            .directory => {
                if (file.name[0] == '.') continue; // skip hidden directories

                const path = b.pathJoin(&.{ target_path, file.name });
                try addFilesRecursive(b, modules, files, root_path, path);
            },
            else => {},
        }
    }
}

/// Returns the path without the root prefix, or `null` if the path did not start with the root prefix.
fn removeRootPrefixFromPath(path: []const u8, root_prefix: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, path, root_prefix)) {
        return path[(root_prefix.len)..];
    }
    return null;
}
