ENTRY(_start)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

/* CORE-V */
MEMORY
{
    /* Our testbench is a bit weird in that we initialize the RAM (thus
       allowing initialized sections to be placed there). Infact we dump all
       sections to ram. */

    ram (rwxai) : ORIGIN = 0x80000000, LENGTH = 0x400000
}

ENTRY(_start)

SECTIONS
{

  /* text: test code section */
  . = 0x80000000;
  .text.start : { *(.text.start) }

  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }

  /* CORE-V: interrupt vectors */
  .vectors : ALIGN(256)
  {
    PROVIDE(__vector_start = .);
    KEEP(*(.vectors));
  }

  . = ALIGN(0x1000);
  .text : { *(.text) }

  /* data segment */
  .data : { *(.data) }

  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  }
  . = ALIGN(0x1000);

  /* bss segment */
  .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  }
  .bss : { *(.bss) }

  /* thread-local data segment */
  .tdata :
  {
    _tdata_begin = .;
    *(.tdata)
    _tdata_end = .;
  }
  .tbss :
  {
    *(.tbss)
    _tbss_end = .;
  }

  /* Heap grows upward towards end of ram */
  .heap                    : ALIGN(16)
  {
   PROVIDE(__heap_start = .);
   /* If end of ram is not 16-byte aligned, align to previous 16-byte
      boundary */
   PROVIDE(__heap_end = ALIGN(ORIGIN(ram) + LENGTH(ram) - __heap_start - 15, 16));
   . = __heap_end;
  }

  /* Stack grows downward from end of ram */
  .stack (__heap_start)    : ALIGN(16) /* this is a requirement of the ABI(?) */
  {
   PROVIDE(__stack_start = __heap_start);
   . = __heap_end;
   PROVIDE(__stack_end = .);
  }

  /* End of uninitalized data segement */
  _end = .;
}
