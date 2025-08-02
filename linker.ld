/* RISC-V Linker Script for simple processor */
/* Memory layout starts at address 0x0 */

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 64K
    RAM (rwx)  : ORIGIN = 0x10000000, LENGTH = 64K
}

ENTRY(_start)

SECTIONS
{
    . = 0x0;
    
    .text : {
        KEEP(*(.text.init))
        *(.text*)
        *(.text.startup)
        *(.text.*)
    } > FLASH
    
    .rodata : {
        *(.rodata*)
    } > FLASH
    
    .data : {
        *(.data*)
    } > RAM AT > FLASH
    
    .bss : {
        *(.bss*)
        *(COMMON)
    } > RAM
    
    /* Stack pointer at end of RAM */
    PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM));
}
