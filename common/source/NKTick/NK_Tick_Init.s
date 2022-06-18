/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "NK_Tick.h"
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

ASM_FUNC_GLOBAL(NK_Tick_Init)
ASM_FUNC_BEG   (NK_Tick_Init, ASM_MODE_THUMB;ASM_SECTION_TEXT)

NK_Tick_Init:
#if __ARM_ARCH >= 5
	PUSH	{r3,lr}
#else
	PUSH	{lr}
#endif
	LDR	r0, =NK_Tick_HighTick
	LDR	r1, =0x04000100+0x04*NK_TICK_HWTIMER
	MOV	r2, #0x00
	MOV	r3, #0x00
	STMIA	r0!, {r2-r3}    @ HighTick = 0
	MOV	r3, #0x80 | 0x40 | TIMER_DIV
	LSL	r3, #0x10
	STRH	r2, [r1, #0x02] @ Stop HW timer (safety)
	STR	r3, [r1]        @ Reset and start HW timer
	LDR	r0, =1<<(3+NK_TICK_HWTIMER)
	LDR	r1, =NK_Tick_HWTimerBurstIRQ
	BL	irqSet
	LDR	r0, =1<<(3+NK_TICK_HWTIMER)
	BL	irqEnable
#if __ARM_ARCH >= 5
	POP	{r3,pc}
#else
	POP	{r3}
	BX	r3
#endif

ASM_FUNC_END(NK_Tick_Init)

/**************************************/

ASM_FUNC_BEG(NK_Tick_Init, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

NK_Tick_HWTimerBurstIRQ:
	LDR	r0, =NK_Tick_HighTick
	LDMIA	r0, {r2-r3}
	ADDS	r2, r2, #0x01
	ADDCS	r3, r3, #0x01<<16
	STMIA	r0, {r2-r3}
	BX	lr

ASM_FUNC_END(NK_Tick_HWTimerBurstIRQ)

/**************************************/
//! EOF
/**************************************/
