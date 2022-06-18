/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "NK_Tick.h"
/**************************************/

@ r0:     &Timer
@ r2,r3:   Delta
@ sp+00h: &CbFunc
@ sp+04h: &CbUser

ASM_FUNC_GLOBAL(NK_Timer_Create)
ASM_FUNC_BEG   (NK_Timer_Create, ASM_MODE_ARM;ASM_SECTION_TEXT)

NK_Timer_Create:
	STMFD	sp!, {r0,r2-r3,lr}
	BL	NK_Tick_Poll
	LDMIB	sp, {r2-r3}
	MOVS	r2, r2, lsr #NK_TICK_LOG2_CYCLES_PER_TICK
	ORR	r2, r2, r3, lsl #0x20-NK_TICK_LOG2_CYCLES_PER_TICK
	ADCS	r2, r0, r2      @ BurstTick = Tick() + Delta/CYCLES_PER_TICK -> r2,r3
	ADC	r3, r1, r3, lsr #NK_TICK_LOG2_CYCLES_PER_TICK
#if __ARM_ARCH >= 5
	LDR	r0, [sp], #0x08
#else
	LDR	r0, [sp], #0x0C
#endif
	BL	NK_Timer_CreateEx
#if __ARM_ARCH >= 5
	LDMFD	sp!, {ip,pc}
#else
	LDR	lr, [sp], #0x04
	BX	lr
#endif

ASM_FUNC_END(NK_Timer_Create)

/**************************************/
//! EOF
/**************************************/
