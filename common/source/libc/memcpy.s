/**************************************/
#include "AsmMacros.h"
/**************************************/
#define OPTIMIZE_UNALIGNED 1
/**************************************/

@ r0: &Dst
@ r1: &Src
@ r2:  Cnt

ASM_FUNC_GLOBAL(memcpy)
ASM_FUNC_BEG   (memcpy, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

memcpy:
#if 0 //! Assume user is not completely braindead
	CMP	r0, r1            @ Dst == Src?
	BXEQ	lr
#endif
	MOV	ip, r0            @ Dst -> ip

.LCheckAlignment:
	EOR	r3, r1, ip        @ Check 4-byte-align congruency for Dst|Src
	TST	r3, #0x03
	BNE	.LUnalignedCopy

.LCopyHead:
	TST	ip, #0x03         @ Word aligned?
	BEQ	.LCopyBody
1:	MOVS	r3, ip, lsr #0x01 @ Check 2-byte align [C=1]
	CMPCS	r2, #0x01         @ Check count
	LDRCSB	r3, [r1], #0x01   @  Align
	SUBCS	r2, r2, #0x01     @  Count down
	STRCSB	r3, [ip], #0x01
2:	MOVS	r3, ip, lsr #0x02 @ Check 4-byte align [C=1]
	CMPCS	r2, #0x02         @ Check count
	LDRCSH	r3, [r1], #0x02   @  Align
	SUBCS	r2, r2, #0x02     @  Count down
	STRCSH	r3, [ip], #0x02
0:	CMP	r2, #0x01         @ Check count
	LDREQB	r3, [r1]          @  Copy tail
	STREQB	r3, [ip]
	BXLS	lr

.LCopyBody:
#if __ARM_ARCH >= 5
	STMFD	sp!, {r4-sl,lr}
#else
	STMFD	sp!, {r4-r9,lr}
#endif
1:	SUBS	r2, r2, #0x20
	LDMCSIA	r1!, {r3-r9,lr}   @ Copy 32-byte blocks
	STMCSIA	ip!, {r3-r9,lr}
	BHI	1b
#if __ARM_ARCH >= 5
	LDMEQFD	sp!, {r4-sl,pc}   @ Early exit when nothing left
#else
	BEQ	.LExit
#endif

.LCopyTail:
	MOVS	r2, r2, lsl #0x1B @ Copy 16-byte
	LDMMIIA	r1!, {r3-r6}
	STMMIIA	ip!, {r3-r6}
	MOVS	r2, r2, lsl #0x02 @ Copy 8-byte, 4-byte
	LDMCSIA	r1!, {r3-r4}
	LDRMI	r5, [r1], #0x04
	STMCSIA	ip!, {r3-r4}
	STRMI	r5, [ip], #0x04
	MOVS	r2, r2, lsl #0x02 @ Copy 2-byte, 1-byte
	LDRCSH	r2, [r1], #0x02
	LDRMIB	r3, [r1], #0x01
	STRCSH	r2, [ip], #0x02
	STRMIB	r3, [ip], #0x01

.LExit:
#if __ARM_ARCH >= 5
	LDMFD	sp!, {r4-sl,pc}
#else
	LDMFD	sp!, {r4-r9,lr}
	BX	lr
#endif

/**************************************/

.LUnalignedCopy:
#if !OPTIMIZE_UNALIGNED

#if __ARM_ARCH >= 5
	CMP	r2, #0x01 @ <- This is normally checked inside the "aligned copy" section, so need to do this here as well
1:	LDRCSB	r3, [r1], #0x01
	SUBCSS	r2, r2, #0x01
	STRCSB	r3, [ip], #0x01
	BHI	1b
2:	BX	lr
#else
1:	SUBS	r2, r2, #0x01
	LDRCSB	r3, [r1], #0x01
	STRCSB	r3, [ip], #0x01
	BHI	1b
2:	BX	lr
#endif

#else

.LUnaligned_AlignSrc:
#if __ARM_ARCH >= 5
	STR	lr, [sp, #-0x08]!
#else
	STR	lr, [sp, #-0x04]!
#endif
	CMP	r2, #0x00                  @ Align Src to words
	TSTNE	r1, #0x03
1:	LDRNEB	r3, [r1], #0x01
	STRNEB	r3, [ip], #0x01
	SUBNES	r2, r2, #0x01
	TSTNE	r1, #0x03
	BNE	1b

.LUnaligned_BlockCopyLoop:
	SUBS	r2, r2, #0x04              @ Pre-decrement Cnt (makes things easier)
	AND	r3, ip, #0x03
	LDR	pc, [pc, r3, lsl #0x02]
	NOP
	NOP	                           @ <- Would imply ((Src^Dst) & 3) == 0, which is false
	.word	.LUnaligned_BlockCopyLoop1
	.word	.LUnaligned_BlockCopyLoop2
	.word	.LUnaligned_BlockCopyLoop3

.LUnaligned_BlockCopyLoop1:
	LDRB	r3, [ip, #-0x01]!          @ 00-00-00-x1
	BCC	2f                         @ <- This will perform a redundant LDRB/STRB, but meh
1:	LDR	lr, [r1], #0x04            @ x1-x4-x3-x2
	SUBS	r2, r2, #0x04
	ORR	r3, r3, lr, lsl #0x08      @ x4-x3-x2-x1
	STR	r3, [ip], #0x04
	MOV	r3, lr, lsr #0x18          @ 00-00-00-x1
	BCS	1b
2:	ADD	r2, r2, #0x04
	@B	.LUnaligned_TailLoop

.LUnaligned_TailLoop:
1:	STRB	r3, [ip], #0x01
	SUBS	r2, r2, #0x01
	LDRCSB	r3, [r1], #0x01
	BCS	1b

.LUnaligned_Exit:
#if __ARM_ARCH >= 5
	LDR	pc, [sp], #0x08
#else
	LDR	lr, [sp], #0x04
	BX	lr
#endif

.LUnaligned_BlockCopyLoop2:
	BCC	2f
	LDRH	r3, [ip, #-0x02]!          @ 00-00-x2-x1
1:	LDR	lr, [r1], #0x04            @ x2-x1-x4-x3
	SUBS	r2, r2, #0x04
	ORR	r3, r3, lr, lsl #0x10      @ x4-x3-x2-x1
	STR	r3, [ip], #0x04
	MOV	r3, lr, lsr #0x10          @ 00-00-x2-x1
	BCS	1b
	STRH	r3, [ip], #0x02
2:	ADDS	r2, r2, #0x04-1
	LDRCSB	r3, [r1], #0x01
	BCS	.LUnaligned_TailLoop
#if __ARM_ARCH >= 5
	LDR	pc, [sp], #0x08
#else
	B	.LUnaligned_Exit
#endif

.LUnaligned_BlockCopyLoop3:
	BCC	2f
	LDR	r3, [ip, #-0x03]!          @ 00-x3-x2-x1
	BIC	r3, r3, #0xFF<<24
1:	LDR	lr, [r1], #0x04            @ x3-x2-x1-x4
	SUBS	r2, r2, #0x04
	ORR	r3, r3, lr, lsl #0x18      @ x4-x3-x2-x1
	STR	r3, [ip], #0x04
	MOV	r3, lr, lsr #0x08          @ 00-x3-x2-x1
	BCS	1b
	LDRB	lr, [ip, #0x03]!           @ 00-00-00-x4
	ORR	r3, r3, lr, lsl #0x18      @ x4-x3-x2-x1
	STR	r3, [ip, #-0x03]
2:	ADDS	r2, r2, #0x04-1
	LDRCSB	r3, [r1], #0x01
	BCS	.LUnaligned_TailLoop
#if __ARM_ARCH >= 5
	LDR	pc, [sp], #0x08
#else
	B	.LUnaligned_Exit
#endif

#endif

ASM_FUNC_END(memcpy)
ASM_WEAK(memcpy)

/**************************************/
//! EOF
/**************************************/
