/**************************************/
#pragma once
/**************************************/

//! Global helpers
#define ASM_ALIGN(x)               .balign x;
#define ASM_WEAK(...)              .weak __VA_ARGS__;
#define ASM_WEAKREF(Alias, Target) .weakref Alias, Target;

/**************************************/

//! Function helpers
#define ASM_MODE_ARM      .balign 4; .arm;
#define ASM_MODE_THUMB    .balign 2; .thumb_func;
#define ASM_SECTION_TEXT  .section .text;
#if __ARM_ARCH >= 5
# define ASM_SECTION_ITCM .section .itcm, "ax", %progbits;
#endif
#if __ARM_ARCH >= 5
# define ASM_SECTION_FASTCODE ASM_SECTION_ITCM
#else
# define ASM_SECTION_FASTCODE ASM_SECTION_TEXT
#endif

//! Function global macro
#define ASM_FUNC_GLOBAL(...) \
	.global __VA_ARGS__

//! Function begin macro
//! Usually pass a section in varg
#define ASM_FUNC_BEG(Name, Args) \
	Args;                    \
	.type Name, %function

//! Function end macro
#define ASM_FUNC_END(Name) \
	.size Name, . - Name

/**************************************/

//! Data helpers
#define ASM_SECTION_DATA   .section .data;
#define ASM_SECTION_RODATA .section .rodata;
#define ASM_SECTION_BSS    .section .bss;
#define ASM_SECTION_SBSS   .section .sbss;
#if __ARM_ARCH >= 5
# define ASM_SECTION_DTCM  .section .dtcm, "aw", %progbits;
#endif
#if __ARM_ARCH >= 5
# define ASM_SECTION_FASTDATA ASM_SECTION_DTCM
#else
# define ASM_SECTION_FASTDATA ASM_SECTION_DATA
#endif

//! Data global macro
#define ASM_DATA_GLOBAL(...) \
	.global __VA_ARGS__

//! Data begin macro
//! Usually pass a section in varg
#define ASM_DATA_BEG(Name, Args) \
	Args;                    \
	.type Name, %object

//! Data end macro
#define ASM_DATA_END(Name) \
	.size Name, . - Name

/**************************************/
//! EOF
/**************************************/
