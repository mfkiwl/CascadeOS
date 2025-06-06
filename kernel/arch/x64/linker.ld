/* SPDX-License-Identifier: CC0-1.0 */
/* SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz> */

OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)

PHDRS
{
    null         PT_NULL    FLAGS(0) ;                   /* Null segment */
    text         PT_LOAD    FLAGS((1 << 0) | (1 << 2)) ; /* Execute + Read */
    rodata       PT_LOAD    FLAGS((1 << 2)) ;            /* Read only */
    data         PT_LOAD    FLAGS((1 << 1) | (1 << 2)) ; /* Write + Read */
    dynamic      PT_DYNAMIC FLAGS((1 << 2)) ;            /* Read only */

    sdf          PT_LOAD    FLAGS((1 << 2)) ;            /* Read only */
}

SECTIONS
{
    /* This must be kept in sync with `kernel.config.kernel_base_address` */
    . = 0xffffffff80000000;

    __text_start = .;

    .text : {
        *(.text .text.*)
    } :text

     __text_end = .;

    . = ALIGN(CONSTANT(MAXPAGESIZE));

     __rodata_start = .;

    .rodata : {
        *(.rodata .rodata.*)
    } :rodata

    .eh_frame_hdr : {
        *(.eh_frame_hdr)
    } :rodata

    .dynsym : {
        *(.dynsym)
    } :rodata

    .gnu.hash : {
        *(.gnu.hash)
    } :rodata

    .hash : {
        *(.hash)
    } :rodata

    .dynstr : {
        *(.dynstr)
    } :rodata

    .rela.dyn : {
        *(.rela.dyn)
    } :rodata

    __rodata_end = .;

    . = ALIGN(CONSTANT(MAXPAGESIZE));

    __data_start = .;

    .data : {
        *(.data .data.*)
    } :data

    .dynamic : {
        *(.dynamic)
    } :data :dynamic

    .bss : {
        *(COMMON)
        *(.bss .bss.*)
        *(.sbss .sbss.*)
    } :data

    __data_end = .;

    . = ALIGN(CONSTANT(MAXPAGESIZE));

    .sdf : { /* sdf_builder embeds the SDF data into this section */
        __sdf_start = .;
        . += 0x1000;
    } :sdf

    /DISCARD/ : {
        *(.eh_frame)
        *(.note .note.*)
        *(.comment)
    }
}