/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0: &Timer

ASM_FUNC_GLOBAL(NK_Timer_Enqueue)
ASM_FUNC_BEG   (NK_Timer_Enqueue, ASM_MODE_ARM;ASM_SECTION_TEXT)

NK_Timer_Enqueue:
	MRS	ip, cpsr        @ [cpsr -> ip]
	ORR	r1, ip, #0x80   @ [I=1]
	MSR	cpsr, r1
1:	STMFD	sp!, {r4-r7,ip,lr}
	LDR	r1, =NK_Timer_Queue
	LDMIA	r0, {r4-r5}     @ Target -> r4,r5

@ r0:   &Timer
@ r1:   &Queue
@ r2:   &Prev
@ r3:   &Next
@ r4,r5: Target

.LEnqueue_Search:
	LDR	r3, [r1]        @ Next(=Head) -> r3
	MOV	r2, #0x00       @ Prev(=NULL) -> r2
1:	CMP	r3, #0x00       @ Reached end? (ie. Next==NULL)
	BEQ	2f              @  Y: Queue here
	LDMIA	r3, {r6-r7}     @ Next.Target -> r6,r7
	RSBS	r6, r6, r4      @ This.Target >= Next.Target?
	RSCS	r7, r7, r5
	MOVPL	r2, r3          @  Prev = Next, Next = Next.Next
	LDRPL	r3, [r3, #0x1C]
	BPL	1b
2:

.LEnqueue_Schedule:
#if __ARM_ARCH >= 5
	STRD	r2, [r0, #0x18] @ Store This.{Prev,Next}
#else
	ADD	ip, r0, #0x18
	STMIA	ip, {r2-r3}
#endif
	CMP	r3, #0x00       @ Next?
	STRNE	r0, [r3, #0x18] @  Y: Next.Prev = This
	CMP	r2, #0x00       @ Prev?
	STRNE	r0, [r2, #0x1C] @  Y: Prev.Next = This
	BNE	.LEnqueue_Exit  @     Prev will burst before This, so skip scheduling
1:	STR	r0, [r1]        @ Set new Queue head
	BL	NK_Tick_Poll
	RSBS	r0, r0, r4      @ Schedule(Delta = Target-Tick)
	RSC	r1, r1, r5
	BL	NK_Timer_Schedule

.LEnqueue_Exit:
	LDMFD	sp!, {r4-r7,ip,lr}
	MSR	cpsr, ip
	BX	lr

ASM_FUNC_END(NK_Timer_Enqueue)

/**************************************/
//! EOF
/**************************************/
