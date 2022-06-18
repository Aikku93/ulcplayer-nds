/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "NK_Tick.h"
#include "NK_Timer.h"
/**************************************/

//! Translation for cycles-per-tick to TMxCNT
#if   NK_TICK_CYCLES_PER_TICK == 64
# define TIMER_DIV 1
#elif NK_TICK_CYCLES_PER_TICK == 256
# define TIMER_DIV 2
#elif NK_TICK_CYCLES_PER_TICK == 1024
# define TIMER_DIV 3
#endif

/**************************************/

@ r0,r1: Delta

ASM_FUNC_GLOBAL(NK_Timer_Schedule)
ASM_FUNC_BEG   (NK_Timer_Schedule, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

NK_Timer_Schedule:
	ORRS	r1, r1, r1, asr #0x20 @ [D < 0: Z=0,C=1. D >= 2^32: Z=0,C=0]
	MOVCS	r1, r1, lsr #0x10     @ D<0? CNT = (u16)(-1) [fastest]
	RSCEQS	r1, r0, #0x010000     @ else CNT = (u16)(-D-1) [-1 to avoid overflow when Delta==0, and to account for overhead]
	MOVCC	r1, #0x00             @      CNT>0xFFFF? CNT = 0 [slowest]
0:	MOV	r0, #0x04000000
	ADD	r1, r1, #(0x80 | 0x40 | TIMER_DIV) << 16
	STR	r0, [r0, #0x04000100+0x04*NK_TIMER_HWTIMER - 0x04000000] @ Stop HW timer (safety)
	STR	r1, [r0, #0x04000100+0x04*NK_TIMER_HWTIMER - 0x04000000] @ Reset and start HW timer
	BX	lr

ASM_FUNC_END(NK_Timer_Schedule)

/**************************************/
//! EOF
/**************************************/
