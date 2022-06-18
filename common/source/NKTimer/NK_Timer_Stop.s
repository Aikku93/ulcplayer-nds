/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0: &Timer

ASM_FUNC_GLOBAL(NK_Timer_Stop)
ASM_FUNC_BEG   (NK_Timer_Stop, ASM_MODE_ARM;ASM_SECTION_TEXT)

NK_Timer_Stop:
	MRS	ip, cpsr             @ [cpsr -> ip]
	ORR	r1, ip, #0x80        @ [I=1]
	MSR	cpsr, r1

.LStop_DoDetach:
	LDR	r1, [r0, #0x10]      @ CbFunc -> r1
#ifdef ARM7
	ADD	r0, r0, #0x18
	LDMIA	r0, {r2-r3}
#else
	LDRD	r2, [r0, #0x18]!
#endif
	CMP	r1, #0x00            @ CbFunc == NULL? (ie. already burst or cancelled)
	BEQ	.LStop_Exit        @  Y: Do not try unlinking
1:	LDR	r1, =NK_Timer_Queue
	CMP	r2, #0x00            @ Prev?
	STRNE	r3, [r2, #0x1C]      @  Y: Prev.Next = Next, N: QueueHead = Next
	STREQ	r3, [r1]
	CMP	r3, #0x00            @ Next?
	STRNE	r2, [r3, #0x18]      @  Y: Next.Prev = Prev
	MOV	r2, #0x00
	MOV	r3, #0x00
	STR	r2, [r0, #0x10-0x18] @ CbFunc = NULL
	STMIA	r0, {r2-r3}          @ {Prev,Next} = {NULL,NULL}

@ When Prev == NULL and Next != NULL, let HW timer burst IRQ
@ reschedule Next and avoid doing it here. Keep it simple.

.LStop_Exit:
	MSR	cpsr, ip
	BX	lr

ASM_FUNC_END(NK_Timer_Stop)

/**************************************/
//! EOF
/**************************************/
