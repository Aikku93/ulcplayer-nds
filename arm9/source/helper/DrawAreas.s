/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainDefines.inc"
#include "MainGraphicsDefines.inc"
/**************************************/

@ r0:  TileX0   | TileY0 <<16
@ r1:  nTilesX  | nTilesY<<16
@ r2:  TileOffs | BoundaryBytes<<16
@ r3: &Map

ASM_FUNC_GLOBAL(DrawArea_PrepTilemap)
ASM_FUNC_BEG   (DrawArea_PrepTilemap, ASM_MODE_ARM;ASM_SECTION_TEXT)

DrawArea_PrepTilemap:
	SMLATT	r3, r0, r2, r3          @ Dst += TileY0*BoundaryBytes
	MOV	r0, r0, lsl #0x10       @ Dst += TileX0 * sizeof(uint16_t)
	ADD	r3, r3, r0, lsr #0x10-1
	MOV	ip, r1, lsr #0x10       @ nTilesYRem -> ip
0:	MOV	r0, r2, lsl #0x10       @ Tile(=TileOffs) | -nTilesXRem(=nTilesX)<<16 -> r0
	MOV	r0, r0, lsr #0x10
	SUB	r0, r0, r1, lsl #0x10
1:	STRH	r0, [r3], #0x02         @ *Map++ = Tile
	ADD	r0, r0, r1, lsr #0x10   @ Tile += nTilesY
	ADDS	r0, r0, #0x01<<16       @ --nTilesXRem?
	BCC	1b
2:	ADD	r2, r2, #0x01           @ TileOffs++
	MOV	r0, r1, lsl #0x10       @ Map -= nTilesX*sizeof(u16) [rewind]
	SUB	r3, r3, r0, lsr #0x10-1
	ADD	r3, r3, r2, lsr #0x10   @ Map += BoundaryBytes
	SUBS	ip, ip, #0x01           @ --nTilesYRem?
	BNE	0b
3:	BX	lr

ASM_FUNC_END(DrawArea_PrepTilemap)

/**************************************/

@ r0: &DrawArea

ASM_FUNC_GLOBAL(DrawArea_Clear)
ASM_FUNC_BEG   (DrawArea_Clear, ASM_MODE_THUMB;ASM_SECTION_TEXT)

DrawArea_Clear:
	LDMIA	r0, {r0-r1} @ memset(GfxMem, 0, nTilesX*nTilesY * (8*8) * 4/8)
	LSL	r2, r1, #0x08
	LSR	r3, r1, #0x18
	LSR	r2, #0x18
	LSL	r2, #0x06-1
	MUL	r2, r3
	LDR	r3, =memset
	MOV	r1, #0x00
	BX	r3

ASM_FUNC_END(DrawArea_Clear)

/**************************************/
//! EOF
/**************************************/
