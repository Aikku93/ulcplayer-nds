/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainDefines.inc"
/**************************************/

@ These hacks are for allowing scrolling text
.equ DRAWBOXED_LEFTALIGN_OVERSIZED, 1 @ When text does not fit in the box, left-align
.equ DRAWBOXED_RETURN_WIDTH,        1 @ Return StringWidth on calls to DrawString_Boxed()

/**************************************/

@ r0: &Str
@ r1: &Font
@ r2: &DrawArea
@ r3:  x | y<<12 | Ink<<24

ASM_FUNC_GLOBAL(Text_DrawString)
ASM_FUNC_BEG   (Text_DrawString, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Text_DrawString:
	PUSH	{r3-r7,lr}
0:	MOV	r4, r0          @ Str -> r4
	MOV	r5, r1          @ Font -> r5
	MOV	r6, r2          @ DrawArea -> r6
	MOV	r7, r3          @ x | y<<12 | Ink<<24 -> r7
1:	BL	Text_DecodeChar @ Char -> r0?
	CMP	r0, #0x00
	BEQ	2f
0:	LDR	r1, [r5, #0x00] @ nGlyphs -> r1
	SUB	r0, #' '        @ GlyphIdx -> r0
	BCC	1b              @  Control char: Skip
	CMP	r0, r1          @ Out of range? Replace with '?'
	BCC	0f
	MOV	r0, #'?'-' '
0:	MOV	r1, r5          @ CharWidth -> r1
	ADD	r1, #0x08
	LDRB	r1, [r1, r0]
	MOV	r3, r7
	MOV	r2, r6
	ADD	r7, r1          @ [advance x position]
	MOV	r1, r5
	@MOV	r0, r0
	BL	Text_DrawGlyph
	B	1b
2:	POP	{r3-r7,pc}

ASM_FUNC_END(Text_DrawString)

/**************************************/

@ r0: &Str
@ r1: &Font
@ r2: &DrawBox
@ r3:  xOffs | yOffs<<12 | Ink<<24

ASM_FUNC_GLOBAL(Text_DrawString_Boxed)
ASM_FUNC_BEG   (Text_DrawString_Boxed, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Text_DrawString_Boxed:
	PUSH	{r0-r6,lr}
	MOV	r4, r2          @ DrawBox -> r4
1:	@MOV	r0, r0          @ First, get the string width
	@MOV	r1, r1
	BL	Text_StringWidth
.if DRAWBOXED_RETURN_WIDTH
	MOV	ip, r0          @ Width -> ip (all other registers are in use)
.endif
	LDR	r6, [r4, #0x00] @ DrawArea | Alignment -> r6
	LDRB	r5, [r4, #0x06] @ BoxW-1 -> r5
	LSL	r1, r6, #0x20-2 @ Alignment -> r1
	LSR	r1, #0x20-2
	BIC	r6, r1          @ [DrawArea -> r2]
	ADD	r5, #0x01       @ PadSpace = BoxW-StrWidth -> r5
	SUB	r5, r0
.if DRAWBOXED_LEFTALIGN_OVERSIZED
	BHI	0f
	MOV	r5, #0x00       @ Oversized: Set PadSpace=0
0:
.endif
	CMP	r1, #0x01       @ Check alignment type
	BEQ	2f
	BHI	3f
1:	MOV	r5, #0x00       @ Left Align:   xOffsAlign = 0 (NOTE: StringWidth() result discarded...)
	B	0f
2:	ASR	r5, #0x01       @ Center Align: xOffsAlign = PadSpace/2 (NOTE: ASR, not LSR)
	B	0f
3:	@B	0f              @ Right Align:  xOffsAlign = PadSpace
0:	POP	{r0-r3}
	MOV	r2, r6          @ DrawArea -> r2
	ADD	r3, r5          @ xOffs += xOffsAlign
	LDRB	r6, [r4, #0x05] @ BoxY -> r6
	LDRB	r5, [r4, #0x04] @ BoxX -> r5
	LSL	r6, #0x0C
	ADD	r3, r6          @ y += BoxY
	ADD	r3, r5          @ x += BoxX
.if DRAWBOXED_RETURN_WIDTH
	MOV	r4, ip          @ Width -> r4
.endif
	BL	Text_DrawString
.if DRAWBOXED_RETURN_WIDTH
	MOV	r0, r4          @ Return Width
.endif
	POP	{r4-r6,pc}

ASM_FUNC_END(Text_DrawString_Boxed)

/**************************************/

@ r0: &Str
@ r1: &Font

ASM_FUNC_GLOBAL(Text_StringWidth)
ASM_FUNC_BEG   (Text_StringWidth, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Text_StringWidth:
	PUSH	{r4-r6,lr}
	MOV	r4, r0          @ Str  -> r4
	MOV	r5, r1          @ Font -> r5
	MOV	r6, #0x00       @ Width=0 -> r6
1:	BL	Text_DecodeChar @ Char -> r0?
	CMP	r0, #0x00
	BEQ	2f
0:	LDR	r1, [r5, #0x00] @ nGlyphs -> r1
	SUB	r0, #' '        @ GlyphIdx -> r0
	BCC	1b              @  Control char: Skip
	CMP	r0, r1          @ Out of range? Replace with '?'
	BCC	0f
	MOV	r0, #'?'-' '
0:	MOV	r1, r5          @ CharWidth -> r1
	ADD	r1, #0x08
	LDRB	r1, [r1, r0]
	ADD	r6, r1          @ Width += CharWidth
	B	1b
2:	MOV	r0, r6          @ Return Width
	POP	{r4-r6,pc}

ASM_FUNC_END(Text_StringWidth)

/**************************************/

@ r4: &Str
@ Returns Char in r0, destroys r1,r2,r3, moves r4 to next character

ASM_FUNC_BEG(Text_DecodeChar, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Text_DecodeChar:
	LDRB	r0, [r4]  @ Char -> r0?
	ADD	r4, #0x01
	MOV	r2, #0x00 @ [nBytes=0 -> r2, preparing for UTF8 decode during stall cycle]
	LSL	r1, r0, #0x18
	BPL	.LDecodeChar_Exit

.LDecodeChar_DecodeUTF8:
1:	ADD	r2, #0x01     @ Keep counting until hitting the stop bit
	LSL	r1, #0x01
	BMI	1b
2:	LSR	r1, r2        @ Restore low bits
	LSR	r0, r1, #0x18
	SUB	r1, r2, #0x02 @ Unexpected continuation (10xxxxxx) or char takes more than 4 bytes?
	CMP	r1, #0x04-2
	BHI	.LDecodeChar_ErrorExit
3:	LDRB	r1, [r4]      @ Build up character
	ADD	r4, #0x01
	LSL	r0, #0x06     @ Mix next bits in
	SUB	r1, #0x80     @ Ensure next byte is in range 80h..BFh
	CMP	r1, #0xBF-0x80
	BHI	.LDecodeChar_ErrorExit
	ORR	r0, r1
	SUB	r2, #0x01
	BNE	3b

.LDecodeChar_Exit:
	BX	lr

.LDecodeChar_ErrorExit:
	MOV	r0, #0x00 @ Return NUL
	BX	lr

ASM_FUNC_END(Text_DecodeChar)

/**************************************/

@ r0:  GlyphIdx
@ r1: &Font
@ r2: &DrawArea
@ r3:  x | y<<12 | Ink<<24

ASM_FUNC_GLOBAL(Text_DrawGlyph)
ASM_FUNC_BEG   (Text_DrawGlyph, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Text_DrawGlyph:
	STMFD	sp!, {r3-fp,lr}
0:	LDMIA	r2, {r2,r4}              @ Dst=GfxMem -> r2, TileX0|TileY0<<8|nTilesX<<16|nTilesY<<24 -> r4
	MOV	ip, #DRAW_BIAS           @ Remove bias from x/y, x -> r6, y -> r7
	MOV	r6, r3, lsl #0x20-12
	RSB	r6, ip, r6, lsr #0x20-12
	MOV	r7, r3, lsl #0x20-12-12
	RSB	r7, ip, r7, lsr #0x20-12
	LDMIA	r1!, {r8,r9}             @ Font.nGlyphs -> r8, Font.{CellW,CellH,BaseX,BaseY} -> r9, &Font.Width[] -> r1
	MOV	r3, r3, lsr #0x18        @ Expand InkOfs=Ink*0x11111111 -> r3
	ORR	r3, r3, r3, lsl #0x04
	ORR	r3, r3, r3, lsl #0x08
	ORR	r3, r3, r3, lsl #0x10
	ADD	r8, r8, #0x03            @ &Font.PxData[] -> r1
	BIC	r8, r8, #0x03
	ADD	r1, r1, r8
	MOV	ip, #0xFF
	AND	r8, ip, r9, lsr #0x10    @ x -= BaseX
	SUB	r6, r6, r8
	AND	r8, ip, r9, lsr #0x18    @ y -= BaseY
	SUB	r7, r7, r8
	AND	r8, ip, r4, lsr #0x00    @ x -= TileX0*8
	SUB	r6, r6, r8, lsl #0x03
	AND	r8, ip, r4, lsr #0x08    @ y -= TileY0*8
	SUB	r7, r7, r8, lsl #0x03
	AND	r8, ip, r9, lsr #0x00    @ nPxX=CellW -> r8
	AND	r9, ip, r9, lsr #0x08    @ nPxY=CellH -> r9
	SMULBB	lr, r8, r9               @ nCellPixels = CellW*CellH -> lr
	AND	r5, ip, r4, lsr #0x18    @ nTilesY -> r5
	MUL	r0, lr, r0               @ Src = &Font.PxData[GlyphIdx * nCellPixels / 4] (2bpp source) -> r0
	AND	r4, ip, r4, lsr #0x10    @ nTilesX -> r4
	ADD	r0, r1, r0, lsr #0x02
0:	RSBS	r1, r6, #0x00            @ nPxSkipX = (-x) -> r1 > 0?
	BICGT	r1, r1, #0x07            @  nPxSkipX = nPxSkipX/8*8
	SUBGT	r8, r8, r1               @  nPxX    -= nPxSkipX
	ADDGT	r6, r6, r1               @  x       += nPxSkipX
	MOVGT	r1, r1, lsr #0x02        @  Src     += nPxSkipX * CellH * 2/8 (2bpp)
	SMLABBGT r0, r1, r9, r0
0:	ADD	r1, r6, r8               @ nPxSkipX = x+nPxX - nTilesX*8 -> r1 > 0?
	SUBS	r1, r1, r4, lsl #0x03
	BICGT	r1, r1, #0x07            @  nPxSkipX = nPxSkipX/8*8
	SUBGT	r8, r8, r1               @  nPxX    -= nPxSkipX
1:	RSBS	sl, r7, #0x00            @ nLineSkipY = nPxSkipY = (-y) -> sl > 0?
	MOVLT	sl, #0x00                @ [clip nLineSkipY to 0 when nothing is skipped]
	SUBGT	r9, r9, sl               @  nPxY -= nPxSkipY (ie. nPxY = 0)
	ADDGT	r7, r7, sl               @  y    += nPxSkipY
	ADDGT	r0, r0, sl, lsl #0x03-2  @  Src  += nPxSkipY*8 * 2/8 (2bpp)
1:	ADD	r1, r7, r9               @ nPxSkipY = y+nPxY - nTilesY*8 -> r1 > 0?
	SUBS	r1, r1, r5, lsl #0x03
	SUBGT	r9, r9, r1               @  nPxY       -= nPxSkipY
	ADDGT	sl, sl, r1               @  nLineSkipY += nPxSkipY
2:	CMP	r8, #0x00                @ nPxX <= 0 || nPxY <= 0? Nothing to draw
	CMPGT	r9, #0x00
	LDMLEFD	sp!, {r3-fp,pc}
	ADD	r2, r2, r7, lsl #0x03-1  @ Seek y (Dst += y*8 * 4/8)
	BIC	r1, r6, #0x07            @ Seek x tile (Dst += (x/8*8)*nTilesY*8 * 4/8)
	MOV	r5, r5, lsl #0x03-1
	SMLABB	r2, r1, r5, r2
	ORR	r1, r9, sl, lsl #0x10    @ nPxY | nTailStrideLines(=-nPxY+nLineSkipY-1+TileStrideX(=nTilesY*8*8)/8)<<16 -> r1
	SUB	r1, r1, r1, lsl #0x10
	ADD	r1, r1, r5, lsl #0x10+1
	SUB	r1, r1, #0x01<<16
	LDR	r7, =Text_DrawGlyph_PxMskLUT

@ r0: &Src
@ r1:  nPxY    | nTailStrideLines<<16
@ r2: &Dst
@ r3:  InkOffs(=Ink*0x11111111)
@ r4:  nTilesX
@ r5:  nTilesY*8 * 4/8
@ r6:  x (pre-incremented inside TileRowLoop)
@ r7: &PxMskLUT
@ r8:  nPxRemX | -nPxRemY
@ r9: [PxMask from GetPxData()]
@ sl:  nLineSkipY
@ fp: [Temp]
@ ip: [PxData from GetPxData()]
@ lr: [Temp]

.LDrawGlyph_TileRowLoop:
	AND	ip, r6, #0x07           @ Call drawing handler based on x%8
	ADD	r6, r6, #0x08           @ [x += 8]
	SUB	r8, r8, r1, lsl #0x10   @ nPxRemY = nPxY
	LDR	pc, [pc, ip, lsl #0x02]
	NOP
1:	.word	.LDrawGlyph_TileColumnLoop_X0
	.word	.LDrawGlyph_TileColumnLoop_X1
	.word	.LDrawGlyph_TileColumnLoop_X2
	.word	.LDrawGlyph_TileColumnLoop_X3
	.word	.LDrawGlyph_TileColumnLoop_X4
	.word	.LDrawGlyph_TileColumnLoop_X5
	.word	.LDrawGlyph_TileColumnLoop_X6
	.word	.LDrawGlyph_TileColumnLoop_X7

.LDrawGlyph_TileRowLoop_Tail:
	ADD	r2, r2, r1, lsr #0x10-2 @ Dst += nTailStrideLines*8 * 4/8
	ADD	r0, r0, sl, lsl #0x03-2 @ Src += nLineSkipY*8 * 2/8
	SUBS	r8, r8, #0x08           @ nPxX -= 8?
	BGT	.LDrawGlyph_TileRowLoop
0:	LDMFD	sp!, {r3-fp,pc}

.LDrawGlyph_GetPxData:
	LDRB	ip, [r0], #0x01         @ PxA -> ip
	LDRB	r9, [r0], #0x01         @ PxB -> r9
	LDR	ip, [r7, ip, lsl #0x02] @ PxA | MskA -> ip
	LDR	r9, [r7, r9, lsl #0x02] @ PxB | MskB -> r9
	@ STALL
	EOR	ip, ip, r9, lsl #0x10   @ PxA | (MskA^PxB)<<16
	EOR	r9, r9, ip, lsr #0x10   @ (PxB^MskA^PxB) | MskB<<16 = MskA | MskB<<16
	EOR	ip, ip, r9, lsl #0x10   @ PxA | (MskA^PxB^MskA)<<16 = PxA  | PxB <<16
	ADD	ip, ip, r3
	AND	ip, ip, r9
	BX	lr

/**************************************/

.LDrawGlyph_TileColumnLoop_X0:
1:	LDR	fp, [r2]                     @ x >= 0: Draw LHS (Always true)
	BL	.LDrawGlyph_GetPxData
	BIC	fp, fp, r9, lsl #0x00
	ORR	fp, fp, ip, lsl #0x00
	STR	fp, [r2], #0x04
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X1:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x04
	ORRGE	fp, fp, ip, lsl #0x04
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x1C
	ORRLT	fp, fp, ip, lsr #0x1C
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X2:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x08
	ORRGE	fp, fp, ip, lsl #0x08
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x18
	ORRLT	fp, fp, ip, lsr #0x18
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X3:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x0C
	ORRGE	fp, fp, ip, lsl #0x0C
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x14
	ORRLT	fp, fp, ip, lsr #0x14
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X4:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x10
	ORRGE	fp, fp, ip, lsl #0x10
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x10
	ORRLT	fp, fp, ip, lsr #0x10
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X5:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x14
	ORRGE	fp, fp, ip, lsl #0x14
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x0C
	ORRLT	fp, fp, ip, lsr #0x0C
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X6:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x18
	ORRGE	fp, fp, ip, lsl #0x18
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x08
	ORRLT	fp, fp, ip, lsr #0x08
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

.LDrawGlyph_TileColumnLoop_X7:
1:	BL	.LDrawGlyph_GetPxData
	CMP	r6, #0x00+8                  @ x >= 0: Draw LHS
	LDRGE	fp, [r2]
	BICGE	fp, fp, r9, lsl #0x1C
	ORRGE	fp, fp, ip, lsl #0x1C
	STRGE	fp, [r2]
	CMP	r6, r4, lsl #0x03            @ x+8 < nTilesX*8: Draw RHS
	LDRLT	fp, [r2, r5, lsl #0x03]
	BICLT	fp, fp, r9, lsr #0x04
	ORRLT	fp, fp, ip, lsr #0x04
	STRLT	fp, [r2, r5, lsl #0x03]
	ADD	r2, r2, #0x04                @ Next column
	ADDS	r8, r8, #0x01<<16            @ --nPxRemY?
	BCC	1b
2:	B	.LDrawGlyph_TileRowLoop_Tail

/**************************************/

ASM_FUNC_END(Text_DrawGlyph)

/**************************************/

ASM_DATA_BEG(Text_DrawGlyph_PxMskLUT, ASM_SECTION_FASTDATA;ASM_ALIGN(4))

Text_DrawGlyph_PxMskLUT:
	.word 0x00000000,0x000F0001,0x000F0002,0x000F0003,0x00F00010,0x00FF0011,0x00FF0012,0x00FF0013
	.word 0x00F00020,0x00FF0021,0x00FF0022,0x00FF0023,0x00F00030,0x00FF0031,0x00FF0032,0x00FF0033
	.word 0x0F000100,0x0F0F0101,0x0F0F0102,0x0F0F0103,0x0FF00110,0x0FFF0111,0x0FFF0112,0x0FFF0113
	.word 0x0FF00120,0x0FFF0121,0x0FFF0122,0x0FFF0123,0x0FF00130,0x0FFF0131,0x0FFF0132,0x0FFF0133
	.word 0x0F000200,0x0F0F0201,0x0F0F0202,0x0F0F0203,0x0FF00210,0x0FFF0211,0x0FFF0212,0x0FFF0213
	.word 0x0FF00220,0x0FFF0221,0x0FFF0222,0x0FFF0223,0x0FF00230,0x0FFF0231,0x0FFF0232,0x0FFF0233
	.word 0x0F000300,0x0F0F0301,0x0F0F0302,0x0F0F0303,0x0FF00310,0x0FFF0311,0x0FFF0312,0x0FFF0313
	.word 0x0FF00320,0x0FFF0321,0x0FFF0322,0x0FFF0323,0x0FF00330,0x0FFF0331,0x0FFF0332,0x0FFF0333
	.word 0xF0001000,0xF00F1001,0xF00F1002,0xF00F1003,0xF0F01010,0xF0FF1011,0xF0FF1012,0xF0FF1013
	.word 0xF0F01020,0xF0FF1021,0xF0FF1022,0xF0FF1023,0xF0F01030,0xF0FF1031,0xF0FF1032,0xF0FF1033
	.word 0xFF001100,0xFF0F1101,0xFF0F1102,0xFF0F1103,0xFFF01110,0xFFFF1111,0xFFFF1112,0xFFFF1113
	.word 0xFFF01120,0xFFFF1121,0xFFFF1122,0xFFFF1123,0xFFF01130,0xFFFF1131,0xFFFF1132,0xFFFF1133
	.word 0xFF001200,0xFF0F1201,0xFF0F1202,0xFF0F1203,0xFFF01210,0xFFFF1211,0xFFFF1212,0xFFFF1213
	.word 0xFFF01220,0xFFFF1221,0xFFFF1222,0xFFFF1223,0xFFF01230,0xFFFF1231,0xFFFF1232,0xFFFF1233
	.word 0xFF001300,0xFF0F1301,0xFF0F1302,0xFF0F1303,0xFFF01310,0xFFFF1311,0xFFFF1312,0xFFFF1313
	.word 0xFFF01320,0xFFFF1321,0xFFFF1322,0xFFFF1323,0xFFF01330,0xFFFF1331,0xFFFF1332,0xFFFF1333
	.word 0xF0002000,0xF00F2001,0xF00F2002,0xF00F2003,0xF0F02010,0xF0FF2011,0xF0FF2012,0xF0FF2013
	.word 0xF0F02020,0xF0FF2021,0xF0FF2022,0xF0FF2023,0xF0F02030,0xF0FF2031,0xF0FF2032,0xF0FF2033
	.word 0xFF002100,0xFF0F2101,0xFF0F2102,0xFF0F2103,0xFFF02110,0xFFFF2111,0xFFFF2112,0xFFFF2113
	.word 0xFFF02120,0xFFFF2121,0xFFFF2122,0xFFFF2123,0xFFF02130,0xFFFF2131,0xFFFF2132,0xFFFF2133
	.word 0xFF002200,0xFF0F2201,0xFF0F2202,0xFF0F2203,0xFFF02210,0xFFFF2211,0xFFFF2212,0xFFFF2213
	.word 0xFFF02220,0xFFFF2221,0xFFFF2222,0xFFFF2223,0xFFF02230,0xFFFF2231,0xFFFF2232,0xFFFF2233
	.word 0xFF002300,0xFF0F2301,0xFF0F2302,0xFF0F2303,0xFFF02310,0xFFFF2311,0xFFFF2312,0xFFFF2313
	.word 0xFFF02320,0xFFFF2321,0xFFFF2322,0xFFFF2323,0xFFF02330,0xFFFF2331,0xFFFF2332,0xFFFF2333
	.word 0xF0003000,0xF00F3001,0xF00F3002,0xF00F3003,0xF0F03010,0xF0FF3011,0xF0FF3012,0xF0FF3013
	.word 0xF0F03020,0xF0FF3021,0xF0FF3022,0xF0FF3023,0xF0F03030,0xF0FF3031,0xF0FF3032,0xF0FF3033
	.word 0xFF003100,0xFF0F3101,0xFF0F3102,0xFF0F3103,0xFFF03110,0xFFFF3111,0xFFFF3112,0xFFFF3113
	.word 0xFFF03120,0xFFFF3121,0xFFFF3122,0xFFFF3123,0xFFF03130,0xFFFF3131,0xFFFF3132,0xFFFF3133
	.word 0xFF003200,0xFF0F3201,0xFF0F3202,0xFF0F3203,0xFFF03210,0xFFFF3211,0xFFFF3212,0xFFFF3213
	.word 0xFFF03220,0xFFFF3221,0xFFFF3222,0xFFFF3223,0xFFF03230,0xFFFF3231,0xFFFF3232,0xFFFF3233
	.word 0xFF003300,0xFF0F3301,0xFF0F3302,0xFF0F3303,0xFFF03310,0xFFFF3311,0xFFFF3312,0xFFFF3313
	.word 0xFFF03320,0xFFFF3321,0xFFFF3322,0xFFFF3323,0xFFF03330,0xFFFF3331,0xFFFF3332,0xFFFF3333

ASM_DATA_END(Text_DrawGlyph_PxMskLUT)

/**************************************/
//! EOF
/**************************************/
