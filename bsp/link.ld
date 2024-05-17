ENTRY(_start)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

/* CORE-V */
MEMORY
{
    ram (rwxai) : ORIGIN = 0x80000000, LENGTH = 0x400000 /* 4 MB RAM */
}

ENTRY(_start)

/* Configurable sizes for the heap, stack, and debugger stack */
_heap_size = DEFINED(_heap_size) ? _heap_size : 0x100000; /* Default heap size 1MB */
_stack_size = DEFINED(_stack_size) ? _stack_size : 0x40000; /* Default stack size 256KB */
_debugger_stack_size = DEFINED(_debugger_stack_size) ? _debugger_stack_size : 0x10000; /* Default debugger stack size 64KB */

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

  .heap : ALIGN(16)
  {
   PROVIDE(__heap_start = ORIGIN(ram) + LENGTH(ram) - _stack_size - _debugger_stack_size - _heap_size);
   . += _heap_size;
   PROVIDE(__heap_end = .);
  }

  .stack (__debugger_stack_start) : ALIGN(16)
  {
   PROVIDE(__debugger_stack_start = ORIGIN(ram) + LENGTH(ram) - _stack_size - _debugger_stack_size);
   . += _debugger_stack_size;
   PROVIDE(__debugger_stack_end = .);
  }

  .stack (__stack_start) : ALIGN(16)
  {
   PROVIDE(__stack_start = ORIGIN(ram) + LENGTH(ram) - _stack_size);
   . += _stack_size;
   PROVIDE(__stack_end = .);
  }

  /* End of uninitialized data segment */
  _end = .;
}

