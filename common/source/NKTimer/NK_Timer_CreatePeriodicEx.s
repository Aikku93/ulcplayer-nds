/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "NK_Tick.h"
/**************************************/

@ r0: &Timer
@ r1:  Period (in cycles)
@ r2: &CbFunc
@ r3: &CbUser
@ sp+00h,sp+04h: PreBurstTick

ASM_FUNC_GLOBAL(NK_Timer_CreatePeriodicEx)
ASM_FUNC_BEG   (NK_Timer_CreatePeriodicEx, ASM_MODE_ARM;ASM_SECTION_TEXT)

NK_Timer_CreatePeriodicEx:
	MOV	ip, sp
	STMFD	sp!, {r4-r5}
	LDMIA	ip, {r4-r5}
	MOV	ip, r0
	ADDS	r4, r4, r1, lsr #NK_TICK_LOG2_CYCLES_PER_TICK  @ Target = PreBurstTick + Period/CYCLES_PER_TICK
	ADC	r5, r5, #0x00
	STMIA	ip!, {r4-r5}                                   @ Store Target
	MOV	r0, r1, lsl #0x20-NK_TICK_LOG2_CYCLES_PER_TICK @ Phase = Period%CYCLES_PER_TICK
	STMIA	ip!, {r0-r3}                                   @ Store {Phase,Period,CbFunc,CbUser}
	LDMFD	sp!, {r4-r5}
0:	SUB	r0, ip, #0x18 @ Queue the timer
	B	NK_Timer_Enqueue

ASM_FUNC_END(NK_Timer_CreatePeriodicEx)

/**************************************/
//! EOF
/**************************************/
