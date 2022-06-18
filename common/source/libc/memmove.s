/**************************************/
#include "AsmMacros.h"
/**************************************/
#define OPTIMIZE_UNALIGNED 1
/**************************************/

@ r0: &Dst
@ r1: &Src
@ r2:  Cnt

ASM_FUNC_GLOBAL(memmove)
ASM_FUNC_BEG   (memmove, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

memmove:
	RSBS	ip, r1, r0        @ Should use forward copy? (Dst <= Src || Dst >= Src+Cnt)
#if 0 //! Assume user is not completely braindead
	BXEQ	lr                @ Dst == Src? Early exit
#endif
	CMPHI	r2, ip
	BLS	memcpy
	ADD	r1, r1, r2        @ Src = Src+Len -> r1 (need to access backwards)
	ADD	ip, r0, r2        @ Dst = Dst+Len -> ip (need to preserve r0)

.LCheckAlignment:
	EOR	r3, r1, ip        @ Check 4-byte-align congruency for Dst|Src
	TST	r3, #0x03
	BNE	.LUnalignedCopy

.LCopyHead:
	TST	ip, #0x03         @ Word aligned?
	BEQ	.LCopyBody
1:	MOVS	r3, ip, lsr #0x01 @ Check 2-byte align [C=1]
	CMPCS	r2, #0x01         @ Check count
	LDRCSB	r3, [r1, #-0x01]! @  Align
	SUBCS	r2, r2, #0x01     @  Count down
	STRCSB	r3, [ip, #-0x01]!
2:	MOVS	r3, ip, lsr #0x02 @ Check 4-byte align [C=1]
	CMPCS	r2, #0x02         @ Check count
	LDRCSH	r3, [r1, #-0x02]! @  Align
	SUBCS	r2, r2, #0x02     @  Count down
	STRCSH	r3, [ip, #-0x02]!
0:	CMP	r2, #0x01         @ Check count
	LDREQB	r3, [r1, #-0x01]  @  Copy tail
	STREQB	r3, [ip, #-0x01]
	BXLS	lr

.LCopyBody:
#if __ARM_ARCH >= 5
	STMFD	sp!, {r4-sl,lr}
#else
	STMFD	sp!, {r4-r9,lr}
#endif
1:	SUBS	r2, r2, #0x20
	LDMCSDB	r1!, {r3-r9,lr}   @ Copy 32-byte blocks
	STMCSDB	ip!, {r3-r9,lr}
	BHI	1b
#if __ARM_ARCH >= 5
	LDMEQFD	sp!, {r4-sl,pc}   @ Early exit when nothing left
#else
	BEQ	.LExit
#endif

.LCopyTail:
	MOVS	r2, r2, lsl #0x1B @ Copy 16-byte
	LDMMIDB	r1!, {r3-r6}
	STMMIDB	ip!, {r3-r6}
	MOVS	r2, r2, lsl #0x02 @ Copy 8-byte, 4-byte
	LDMCSDB	r1!, {r3-r4}
	LDRMI	r5, [r1, #-0x04]!
	STMCSDB	ip!, {r3-r4}
	STRMI	r5, [ip, #-0x04]!
	MOVS	r2, r2, lsl #0x02 @ Copy 2-byte, 1-byte
	LDRCSH	r2, [r1, #-0x02]!
	LDRMIB	r3, [r1, #-0x01]!
	STRCSH	r2, [ip, #-0x02]!
	STRMIB	r3, [ip, #-0x01]!

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
1:	LDRCSB	r3, [r1, #-0x01]!
	SUBCSS	r2, r2, #0x01
	STRCSB	r3, [ip, #-0x01]!
	BHI	1b
2:	BX	lr
#else
1:	SUBS	r2, r2, #0x01
	LDRCSB	r3, [r1, #-0x01]!
	STRCSB	r3, [ip, #-0x01]!
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
1:	LDRNEB	r3, [r1, #-0x01]!
	STRNEB	r3, [ip, #-0x01]!
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

.LUnaligned_BlockCopyLoop3:
	LDRB	r3, [ip], #0x01            @ 00-00-00-x4
	BCC	2f                         @ <- This will perform a redundant LDRB/STRB, but meh
1:	MOV	lr, r3, lsl #0x18          @ x4-00-00-00
	LDR	r3, [r1, #-0x04]!          @ x3-x2-x1-x4
	SUBS	r2, r2, #0x04
	ORR	lr, lr, r3, lsr #0x08      @ x4-x3-x2-x1
	STR	lr, [ip, #-0x04]!
	BCS	1b
2:	ADD	r2, r2, #0x04
	@B	.LUnaligned_TailLoop

.LUnaligned_TailLoop:
1:	STRB	r3, [ip, #-0x01]!
	SUBS	r2, r2, #0x01
	LDRCSB	r3, [r1, #-0x01]!
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
	LDRH	r3, [ip], #0x02            @ 00-00-x4-x3
1:	MOV	lr, r3, lsl #0x10          @ x4-x3-00-00
	LDR	r3, [r1, #-0x04]!          @ x2-x1-x4-x3
	SUBS	r2, r2, #0x04
	ORR	lr, lr, r3, lsr #0x10      @ x4-x3-x2-x1
	STR	lr, [ip, #-0x04]!
	BCS	1b
	STRH	r3, [ip, #-0x02]!
2:	ADDS	r2, r2, #0x04-1
	LDRCSB	r3, [r1, #-0x01]!
	BCS	.LUnaligned_TailLoop
#if __ARM_ARCH >= 5
	LDR	pc, [sp], #0x08
#else
	B	.LUnaligned_Exit
#endif

.LUnaligned_BlockCopyLoop1:
	BCC	2f
	LDR	lr, [ip, #-0x01]           @ x4-x3-x2-00
	ADD	ip, ip, #0x03
	BIC	lr, lr, #0xFF
1:	LDR	r3, [r1, #-0x04]!          @ x1-x4-x3-x2
	SUBS	r2, r2, #0x04
	ORR	lr, lr, r3, lsr #0x18      @ x4-x3-x2-x1
	STR	lr, [ip, #-0x04]!
	MOV	lr, r3, lsl #0x08          @ x4-x3-x2-00
	BCS	1b
	LDRB	r3, [ip, #-0x04]!          @ 00-00-00-x1
	ORR	r3, r3, lr                 @ x4-x3-x2-x1
	STR	r3, [ip], #0x01
2:	ADDS	r2, r2, #0x04-1
	LDRCSB	r3, [r1, #-0x01]!
	BCS	.LUnaligned_TailLoop
#if __ARM_ARCH >= 5
	LDR	pc, [sp], #0x08
#else
	B	.LUnaligned_Exit
#endif

#endif

ASM_FUNC_END(memmove)
ASM_WEAK(memmove)

/**************************************/
//! EOF
/**************************************/
