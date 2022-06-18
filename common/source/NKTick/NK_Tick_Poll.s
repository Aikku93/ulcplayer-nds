/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "NK_Tick.h"
/**************************************/

//! Number of ticks to guard for overflow edge cases
//! Halfway through should be /way/ more than enough,
//! as in reality, we will likely only have a value
//! in the low hundreds, nevermind thousands.
#define TIMER_GUARD 0xFF00

/**************************************/

ASM_FUNC_GLOBAL(NK_Tick_Poll)
ASM_FUNC_BEG   (NK_Tick_Poll, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

NK_Tick_Poll:
	LDR	r0, =NK_Tick_HighTick
	MOVS	r1, #0x04000002                                       @ [C=0] (adding an offset lets us reach REG_TIMERD(0) with 8bit #IMM)
	MRS	ip, cpsr                                              @ [cpsr -> ip]
	ORR	r2, ip, #0x80                                         @ [I=1]
	MSR	cpsr, r2                                              @ CriticalSection {
	LDMIA	r0, {r2-r3}                                           @   HighTick -> r2,r3
	LDRH	r0, [r1, #0x04000100+0x04*NK_TICK_HWTIMER-0x04000002] @   *TMR_D(=LowTick) -> r0. Must use LDRH for compatibility with older DeSmuME
	LDR	r1, [r1, #0x04000214                     -0x04000002] @   *IF -> r1
	MSR	cpsr, ip                                              @ }
	RSCS	ip, r0, #TIMER_GUARD                                  @ CNT < GUARD? (only trigger when timer has already overflowed)
	MOVCSS	ip, r1, lsr #0x03+NK_TICK_HWTIMER+1                   @  IF&TMR(TickTimer)?
	ADDCSS	r2, r2, #0x01                                         @   HighTick++
	ADDCS	r3, r3, #0x01<<16                                     @ [H1 is already shifted up - pointless to maintain an 80bit counter]
1:	ORR	r0, r0, r2, lsl #0x10                                 @ (LO|H0<<16) -> r0
	ORR	r1, r3, r2, lsr #0x10                                 @ (H1|H0>>16) -> r1
	BX	lr

ASM_FUNC_END(NK_Tick_Poll)

/**************************************/
//! EOF
/**************************************/
