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

ASM_FUNC_GLOBAL(NK_Timer_Init)
ASM_FUNC_BEG   (NK_Timer_Init, ASM_MODE_THUMB;ASM_SECTION_TEXT)

NK_Timer_Init:
#if __ARM_ARCH >= 5
	PUSH	{r3,lr}
#else
	PUSH	{lr}
#endif
	LDR	r0, =NK_Timer_Queue
	LDR	r1, =0x04000100+0x04*NK_TIMER_HWTIMER
	MOV	r2, #0x00
	STR	r2, [r0]        @ Queue = NULL
	STRH	r2, [r1, #0x02] @ Stop HW timer (safety)
	LDR	r0, =1<<(3+NK_TIMER_HWTIMER)
	LDR	r1, =NK_Timer_HWTimerBurstIRQ
	BL	irqSet
	LDR	r0, =1<<(3+NK_TIMER_HWTIMER)
	BL	irqEnable
#if __ARM_ARCH >= 5
	POP	{r3,pc}
#else
	POP	{r3}
	BX	r3
#endif

ASM_FUNC_END(NK_Timer_Init)

/**************************************/

ASM_FUNC_BEG(NK_Timer_HWTimerBurstIRQ, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

NK_Timer_HWTimerBurstIRQ:
#if __ARM_ARCH >= 5
	STMFD	sp!, {r3-r7,lr}
#else
	STMFD	sp!, {r4-r7,lr}
#endif

.LBurst_CheckQueue:
	LDR	r4, =NK_Timer_Queue
	MOV	r0, #0x04000000
	LDR	r5, [r4]                                                 @ Queue -> r5
	STR	r0, [r0, #0x04000100+0x04*NK_TIMER_HWTIMER - 0x04000000] @ Stop timer
	CMP	r5, #0x00                                                @ Empty queue? (eg. only one timer ready, and was then cancelled)
#if __ARM_ARCH >= 5
	LDMEQFD	sp!, {r3-r7,pc}
#else
	BEQ	.LBurst_bxne_r1___bx_lr                                  @ <- Save a cycle in most cases by reusing code from later on
#endif

.LBurst_CheckTarget:
	LDMIA	r5, {r6-r7}          @ Target -> r6,r7
	BL	NK_Tick_Poll         @ Tick -> r0,r1
1:	SUBS	r2, r0, r6           @ Tick - Target -> r2,r3
	SBCS	r3, r1, r7           @ Tick < Target? (eg. clipped large delta or previous timer was cancelled)
	BMI	.LBurst_Premature

.LBurst_ScheduleNext:
	LDR	r2, [r5, #0x1C]      @ This.Next -> r2? (ie. have a Next to schedule?)
	MOV	r3, #0x00
	STR	r2, [r4]             @ [Queue = Next]
	CMP	r2, #0x00
	BEQ	2f
1:	STR	r3, [r2, #0x18]      @ Next.Prev = NULL
	LDMIA	r2, {r2-r3}          @ Next.Target -> r2,r3
	RSBS	r0, r0, r2           @ Schedule(Delta = Next.Target - Tick)
	RSC	r1, r1, r3
	BL	NK_Timer_Schedule
2:

.LBurst_CheckPeriodic:
	ADD	ip, r5, #0x08        @ &Phase -> ip
	LDMIA	ip, {r0,r2,r4-r5}    @ {Phase,Period,CbFunc,CbUser} -> r0,r2,r4,r5
	MOVS	r3, r2               @ Period == 0?
	BEQ	2f
1:	ADDS	lr, r0, r2, lsl #0x20-NK_TICK_LOG2_CYCLES_PER_TICK @ Phase  += Period%CYCLES_PER_TICK -> lr? (C=1 on overflow)
	ADCS	r2, r6, r2, lsr #NK_TICK_LOG2_CYCLES_PER_TICK      @ Target += Period/CYCLES_PER_TICK + PhaseCarry -> r2,r3
	ADC	r3, r7, #0x00
	STMDA	ip, {r2-r3,lr}                                     @ Store new {Target,Phase} and re-queue this timer
	SUB	r0, ip, #0x08
	ADR	lr, .LBurst_CallHandler
	B	NK_Timer_Enqueue
2:	STR	r2, [ip, #0x10-0x08] @ Not periodic: Set CbFunc = NULL (avoids Cancel() issues when timer already burst)
#if __ARM_ARCH >= 5
	STRD	r2, [ip, #0x18-0x08] @ Unlink (safety) and skip re-queueing. Head and Next.Prev are already updated
#else
	ADD	ip, ip, #0x18-0x08
	STMIA	ip, {r2-r3}
#endif

.LBurst_CallHandler:
	MOV	r0, r5               @ CbUser -> r0
	MOVS	r1, r4               @ CbFunc -> r1?

.LBurst_bxne_r1___bx_lr:
#if __ARM_ARCH >= 5
	LDMFD	sp!, {r3-r7,lr}
#else
	LDMFD	sp!, {r4-r7,lr}
#endif
	BXNE	r1
	BX	lr

.LBurst_Premature:
	RSBS	r0, r0, r6           @ Schedule(Delta = Target-Tick)
	RSC	r1, r1, r7
#if __ARM_ARCH >= 5
	LDMFD	sp!, {r3-r7,lr}
#else
	LDMFD	sp!, {r4-r7,lr}
#endif
	B	NK_Timer_Schedule

ASM_FUNC_END(NK_Timer_HWTimerBurstIRQ)

/**************************************/
//! EOF
/**************************************/
