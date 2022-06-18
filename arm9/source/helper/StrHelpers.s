/**************************************/
#include "AsmMacros.h"
/**************************************/

@ r0: &Dst
@ r1:  Number
@ r2:  PadChar | Reversed<<16 | nMinChar<<24
@ Returns Dst+nOutputChar, always base-10 (NOT standard behaviour)

ASM_FUNC_GLOBAL(itoa_Safe)
ASM_FUNC_BEG   (itoa_Safe, ASM_MODE_ARM;ASM_SECTION_TEXT)

itoa_Safe:
	STMFD	sp!, {r4,lr}
	LDR	r3, =0xCCCCCCCD         @ 1/10 [.35fxp] -> r3
	MOV	ip, r0                  @ Start -> ip
1:	UMULL	r4, lr, r3, r1          @ Number/10 -> r4,lr [.35fxp]
	SUB	r2, r2, #0x01<<24       @ --nMinChar
	BIC	r4, lr, #0x07           @ Number/10*10 -> r4
	ADD	r4, r4, r4, lsr #0x03-1
	SUB	r1, r1, r4              @ Number - Number/10*10 = Number%10, then convert to characters
	ADD	r1, r1, #'0'
	STRB	r1, [r0], #0x01
	MOVS	r1, lr, lsr #0x03       @ Number = Number/10?
	BNE	1b
2:	SUBS	r2, r2, #0x01<<24       @ Insert padding
	STRGEB	r2, [r0], #0x01
	BGE	2b
3:	STRB	r1, [r0]                @ Append NUL
	MOVS	r2, r2, lsr #0x10+1     @ C=Reversed?
	SUB	r1, r0, #0x01           @ We wrote the digits backwards, so reverse them
30:	CMPCC	ip, r1
	LDRCCB	r2, [ip]
	LDRCCB	r3, [r1]
	STRCCB	r2, [r1], #-0x01
	STRCCB	r3, [ip], #0x01
	BCC	30b
4:	LDMFD	sp!, {r4,pc}

ASM_FUNC_END(itoa_Safe)

/**************************************/

@ r0: &Dst
@ r1: &Src
@ Returns Dst+strlen(Src) (NOT standard behaviour)

ASM_FUNC_GLOBAL(strcpy_Safe)
ASM_FUNC_BEG   (strcpy_Safe, ASM_MODE_THUMB;ASM_SECTION_TEXT)

strcpy_Safe:
	SUB	r0, #0x01
1:	LDRB	r2, [r1]
	ADD	r1, #0x01
	ADD	r0, #0x01
	STRB	r2, [r0]
	CMP	r2, #0x00
	BNE	1b
2:	BX	lr

ASM_FUNC_END(strcpy_Safe)

/**************************************/

@ Custom routine: strfsecs - Time-formatted string from seconds
@ r0: &Dst
@ r1:  Seconds
@ r2:  nDigits (excluding colons. 3 = "x:xx", 4 = "xx:xx", 5 = "x:xx:xx")
@ Returns Dst+nDigits+nColons

ASM_FUNC_GLOBAL(strfsecs_Safe)
ASM_FUNC_BEG   (strfsecs_Safe, ASM_MODE_ARM;ASM_SECTION_TEXT)

strfsecs_Safe:
	STMFD	sp!, {r4-r8,lr}
	MOV	r8, #':'
	MOV	r7, r0                   @ Start -> r7
	LDR	r6, =0x88888889          @ 1/60 -> r6 [.37fxp]
	MOV	r5, r2                   @ nDigits -> r5
	MOV	r4, r1                   @ Seconds -> r4
1:	UMULL	r2, r3, r6, r4           @ Seconds/60 -> r2,r3 [.37fxp]
	LDR	r2, ='0' | 1<<16 | 2<<24 @ {PadChar='0', Reversed=TRUE, nMinChar=min(2,nDigitsRem)} -> r2
	SUBS	ip, r5, #0x02
	ADDCC	r2, r2, ip, lsl #0x18
	MOV	ip, r3, lsr #0x05        @ Number=Seconds%60 -> r1
	SUB	r1, r4, ip, lsl #0x06
	ADD	r1, r1, ip, lsl #0x02
	@MOV	r0, r0                   @ Dst = Dst -> r0
	MOV	r4, r3, lsr #0x05        @ Seconds = Seconds/60
	BL	itoa_Safe
	SUBS	r5, r5, #0x02            @ Still have more digits?
	STRHIB	r8, [r0], #0x01          @  Append a colon and continue
	BHI	1b
2:	STRB	r4, [r0]                 @ Append NUL
	SUB	r1, r0, #0x01            @ We wrote the string backwards, so reverse it
20:	CMP	r7, r1
	LDRCCB	r2, [r7]
	LDRCCB	r3, [r1]
	STRCCB	r2, [r1], #-0x01
	STRCCB	r3, [r7], #0x01
	BCC	20b
3:	LDMFD	sp!, {r4-r8,pc}

ASM_FUNC_END(strfsecs_Safe)

/**************************************/
//! EOF
/**************************************/
