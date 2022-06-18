/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0: &Timer
@ r1:  Period (in cycles)
@ r2: &CbFunc
@ r3: &CbUser

ASM_FUNC_GLOBAL(NK_Timer_CreatePeriodic)
ASM_FUNC_BEG   (NK_Timer_CreatePeriodic, ASM_MODE_THUMB;ASM_SECTION_TEXT)

NK_Timer_CreatePeriodic:
	PUSH	{r0-r4,lr}
	BL	NK_Tick_Poll
	MOV	r4, r0
	MOV	lr, r1
	POP	{r0-r3}   @ Restore arguments
	PUSH	{r4,lr}   @ Push PreBurstTick = Tick()
	BL	NK_Timer_CreatePeriodicEx
	ADD	sp, #0x08 @ Pop PreBurstTick
#if __ARM_ARCH >= 5
	POP	{r4,pc}
#else
	POP	{r2-r3}
	MOV	r4, r2
	BX	r3
#endif

ASM_FUNC_END(NK_Timer_CreatePeriodic)

/**************************************/
//! EOF
/**************************************/
