/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0: &Dst (must be 2-byte aligned)
@ r1: &Src (must be 4-byte aligned)
@ This is a "special" LZSS variant that operates
@ on 16bit data to work with VRAM memory access.

ASM_FUNC_GLOBAL(UnLZSS)
ASM_FUNC_BEG   (UnLZSS, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

UnLZSS:
	LDR	r2, [r1], #0x04       @ Size -> r2
	STMFD	sp!, {r4-r6,lr}
	ADD	r2, r0, r2, lsl #0x01 @ End=Dst+Size -> r2

@ r0: &Dst
@ r1: &Src
@ r2: &End (relative to Dst)
@ r3:  LZCnt

.LReadLoop_Main:
1:	LDRH	r3, [r1], #0x02       @ LZCnt -> r3
	BL	1f                    @ Bit15
	BL	1f                    @ Bit14
	BL	1f                    @ Bit13
	BL	1f                    @ Bit12
	BL	1f                    @ Bit11
	BL	1f                    @ Bit10
	BL	1f                    @ Bit9
	BL	1f                    @ Bit8
	BL	1f                    @ Bit7
	BL	1f                    @ Bit6
	BL	1f                    @ Bit5
	BL	1f                    @ Bit4
	BL	1f                    @ Bit3
	BL	1f                    @ Bit2
	BL	1f                    @ Bit1
	ADR	lr, 1b                @ Bit0
1:	MOVS	r3, r3, lsr #0x01     @ Byte read?
2:	BCC	.LReadLoop_Single
	@BCS	.LReadLoop_Block

.LReadLoop_Block:
	LDRH	r5, [r1], #0x02       @ Offs|Cnt<<12 -> ip
	ADD	r4, r5, #(3-1)<<12    @ (Len+3 - 1)<<12 -> r4 [-1 for BCS loop]
	BIC	r5, r5, #0xF000       @ Offs -> r5
	SUB	r5, r0, r5, lsl #0x01 @ Src = (Dst - Offs - 1) -> r5
	SUB	r5, r5, #0x02
1:	LDRH	ip, [r5], #0x02       @ *Dst++ = *Src++
	SUBS	r4, r4, #0x01<<12
	STRH	ip, [r0], #0x02
	BCS	1b
2:	CMP	r0, r2 @ End?
	MOVNE	pc, lr @  N: Continue
	LDMFD	sp!, {r4-r6,pc}

.LReadLoop_Single:
	LDRH	ip, [r1], #0x02
	STRH	ip, [r0], #0x02
	CMP	r0, r2 @ End?
	MOVNE	pc, lr @  N: Continue
	LDMFD	sp!, {r4-r6,pc}

ASM_FUNC_END(UnLZSS)

/**************************************/
//! EOF
/**************************************/
