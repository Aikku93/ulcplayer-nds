/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0:     &Timer
@ r2,r3:   BurstTick
@ sp+00h: &CbFunc
@ sp+04h: &CbUser

ASM_FUNC_GLOBAL(NK_Timer_CreateEx)
ASM_FUNC_BEG   (NK_Timer_CreateEx, ASM_MODE_ARM;ASM_SECTION_TEXT)

NK_Timer_CreateEx:
	MOV	ip, #0x00
#if __ARM_ARCH >= 5
	STRD	r2, [r0], #0x0C  @ Store Target = BurstTick
	STR	ip, [r0], #0x04  @ Store Period = 0
#else
	STMIA	r0!, {r2-r3}
	STR	ip, [r0, #0x04]!
#endif
	LDMFD	sp, {r2-r3}
#if __ARM_ARCH >= 5
	STRD	r2, [r0], #-0x18 @ Store {CbFunc,CbUser} and queue the timer
#else
	STMIB	r0!, {r2-r3}
	SUB	r0, r0, #0x14
#endif
	B	NK_Timer_Enqueue

ASM_FUNC_END(NK_Timer_CreateEx)

/**************************************/
//! EOF
/**************************************/
