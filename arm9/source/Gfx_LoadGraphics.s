/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

@ NOTE: MAINWINDOW has lower priority than HEADERFOOTER, and then
@ Songs/Artists icons have the same priority as MAINWINDOW. This
@ causes HEADERFOOTER to mask them out, and keep the illusion of
@ scrolling objects.
.equ BG0CNT_B, (       4<<2        | 2<<8) @              CHARMAP(4),       TILEMAP(2) (Drawing)
.equ BG1CNT_B, (0)
.equ BG2CNT_B, (       4<<2 | 1<<7 | 0<<8) @              CHARMAP(4), 8BPP, TILEMAP(0) (Header/Footer)
.equ BG3CNT_B, (1<<0 | 4<<2 | 1<<7 | 1<<8) @ PRIORITY(1), CHARMAP(4), 8BPP, TILEMAP(1) (Main Window)

ASM_FUNC_GLOBAL(Gfx_LoadGraphics)
ASM_FUNC_BEG   (Gfx_LoadGraphics, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Gfx_LoadGraphics:
	PUSH	{r4-r6,lr}

.LLoadGraphics_InitHW:
	LDR	r0, =0x820F                      @ LCDA_2D | GX3D_RENDER | GX3D_GEOMETRY | LCDB_2D | LCDA_UPPER
	LDR	r3, =0x04000304                  @ &POWCNT1 -> r3
	LDR	r2, =0x04000240                  @ Init VRAMCNT (VRAM_A in LCDC mode)
	STR	r0, [r3]
	LDR	r0, =0x84840080
	MOV	r1, #0x00
	STR	r0, [r2, #0x00]                  @ VRAM_A, VRAM_B, VRAM_C, VRAM_D
	STRH	r1, [r2, #0x04]                  @ VRAM_E
	STRB	r1, [r2, #0x06]                  @ VRAM_F
	STRH	r1, [r2, #0x08]                  @ VRAM_H, VRAM_I

.LInitHW_A:
	MOV	r4, #0x04                        @ &REG_BASE -> r4
	LSL	r4, #0x18
	MOV	r0, #0x00
	STRH	r0, [r4, #0x08]                  @ BGCNT_A(0) = 0 (nothing important here)
	STR	r0, [r4, #0x10]                  @ BGHOFS_A(0) = BGVOFS_A(0) = 0
0:	LDR	r4, =0x04000400                  @ &REG_GXFIFO -> r4
	LDR	r5, =0x04000600                  @ &REG_GXSTAT -> r5
1:	@MOV	r0, #0x00                        @ Send 128 NOP commands to flush out the FIFO
	MOV	r1, #0x00
	MOV	r2, #0x00
	MOV	r3, #0x00
	MOV	r6, #0x80
10:	STMIA	r4!, {r0-r3}
	SUB	r4, #0x10
	SUB	r6, #0x04
	BNE	10b
	ADD	r4, #0x40                        @ &REG_GXCMD -> r4
11:	LDR	r0, [r5]                         @ Busy wait (GXSTAT -> r0]
	LSR	r1, r0, #0x1B+1
	BCS	11b
12:	MOV	r1, #0x03
	STR	r1, [r4, #0x40-0x40]             @ MTXMODE = TEXTURE
	STR	r1, [r4, #0x54-0x40]             @ MtxTexture = MTXIDENTITY
	MOV	r1, #0x00
	STR	r1, [r4, #0x40-0x40]             @ MTXMODE = PROJ
	LSL	r1, r0, #0x1F-13
	LSR	r1, #0x1F
	BEQ	0f
	STR	r1, [r4, #0x48-0x40]             @ MTXPOP = ProjLevel
0:	LDR	r2, =Gfx_LoadGraphics_OrthoProjMtx
	MOV	r3, #0x04*4
0:	LDMIA	r2!, {r1}
	STR	r1, [r4, #0x58-0x40]             @ MtxProj = OrthoProjMtx
	SUB	r3, #0x01
	BNE	0b
	MOV	r1, #0x02
	STR	r1, [r4, #0x40-0x40]             @ MTXMODE = POSVEC
	LSL	r1, r0, #0x20-12
	LSR	r1, #0x20-5
	BEQ	0f
	STR	r1, [r4, #0x48-0x40]             @ MTXPOP = PosVecLevel
0:	STR	r1, [r4, #0x54-0x40]             @ MtxPosVec = IDENTITY
	MOV	r1, #0x01
	LSL	r1, #0x0F                        @ GXSTAT = MTXOVERFLOWACK (just in case)
	STR	r1, [r5]
2:	LDR	r5, =0x04000060                  @ &REG_DISP3DCNT -> r5
	LDR	r0, =0x3019                      @ DISP3DCNT = TEXMAP | ALPHABLD | ANTIALIAS | RDUNDERFLOWACK | VTXOVERFLOWACK (1<<5 = Edge marking?)
	LDR	r2, =0x04000350
	STR	r0, [r5]
	MOV	r0, #0x1F
	LSL	r0, #0x10
	STR	r0, [r2]                         @ CLEARCOLOUR = {r=0,g=0,b=0,a=31,ClearPolyID=0}
	MVN	r0, r0
	LSR	r0, #0x11
	STR	r0, [r2, #0x04]                  @ CLEARDEPTH = 7FFFh, CLEARIMAGE_OFFS = {x=0,y=0}
	MOV	r0, #0x01
	ADD	r4, #0x0130-0x40
	LDR	r1, =0xBFFF0000
	STR	r1, [r4, #0x0180-0x0130]         @ VIEWPORT = {0,0,255,191}
	STR	r0, [r4, #0x0140-0x0130]         @ SWAPBUFFERS = MANUALSORT

.LLoadGraphics_InitHW_B:
	LDR	r4, =0x04001008                  @ &REG_BGCNT_B(0) -> r4
0:	LDR	r0, =BG0CNT_B | BG1CNT_B<<16     @ Init BGxCNT_B, BGxHOFS_B = 0, BGxVOFS_B = 0
	LDR	r1, =BG2CNT_B | BG3CNT_B<<16
	MOV	r2, #0x00
	MOV	r3, #0x00
	STMIA	r4!, {r0-r3}
	STMIA	r4!, {r2-r3}
	LDR	r3, =0x10102C41                  @ Init BLDCNT_B = (A=BG0|SFX : B=BG2|BG3|BD|SFX, Out=ALL), BLDALPHA_B = (1.0 : 1.0)
	ADD	r4, #0x50 - 0x20
	STR	r3, [r4]
0:	LDR	r0, =BGTILEPXADR4_B(0, 0)        @ Clear all BGVRAM_B (128KiB), because we are lazy
	MOV	r1, #0x00
	MOV	r2, #0x01
	LSL	r2, #0x11
	BL	memset
0:	LDR	r0, =0x07000400                  @ Disable all OAM_B entries
	MOV	r1, #0x80
	LSL	r2, r1, #0x02
0:	STRH	r2, [r0]
	ADD	r0, #0x08
	SUB	r1, #0x01
	BNE	0b

.LLoadGraphics_LoadData:
0:	LDR	r1, =GfxBg_MainWindow_Gfx        @ Load Header/Footer + Main Window graphics
	LDR	r0, =BGTILEPXADR8_B(GFXBG_MAINWINDOW_GFX_TILEOFFS, 4)
	BL	UnLZSS
	LDR	r1, =GfxBg_MainWindow_Map        @ Load Header/Footer + Main Window tilemaps
	LDR	r0, =BGTILEMAPADR_B(0)
	BL	UnLZSS
	LDR	r0, =0x05000400                  @ Load Main Window + Playing Window palette
	LDR	r1, =GfxBg_MainWindow_Pal
	LDR	r2, =0x02 * 128
	BL	memcpy
0:	LDR	r1, =GfxObj_PlaybackModes_Gfx    @ Load Shuffle/Repeat tiles
	LDR	r0, =OBJBITMAPPXADR_B(GFXOBJ_MAINWINDOW_MENU_SHUFFLE_TILEOFFS)
	BL	UnLZSS
0:	LDR	r1, =Gfx_Visualizer_Backdrop     @ Load Visualizer backdrop, then lock VRAM_A = TEX
	LDR	r0, =0x06800000
	BL	UnLZSS
	LDR	r0, =0x04000240
	MOV	r1, #0x83
	STRB	r1, [r0]

.LLoadGraphics_PrepDrawAreas:
0:	LDR	r0, =GFXBG_DRAWING_MENU_X0TILE   | GFXBG_DRAWING_MENU_Y0TILE<<16
	LDR	r1, =GFXBG_DRAWING_MENU_NTILESX  | GFXBG_DRAWING_MENU_NTILESY<<16
	LDR	r2, =GFXBG_DRAWING_MENU_TILEOFFS | 0x7000 | (0x02 * 32)<<16
	LDR	r3, =BGTILEMAPADR_B(2)
	BL	DrawArea_PrepTilemap
0:	LDR	r0, =GFXBG_DRAWING_BODY_X0TILE   | GFXBG_DRAWING_BODY_Y0TILE<<16
	LDR	r1, =GFXBG_DRAWING_BODY_NTILESX  | GFXBG_DRAWING_BODY_NTILESY<<16
	LDR	r2, =GFXBG_DRAWING_BODY_TILEOFFS | 0x7000 | (0x02 * 32)<<16
	LDR	r3, =BGTILEMAPADR_B(2)
	BL	DrawArea_PrepTilemap
0:	LDR	r0, =GFXBG_DRAWING_FOOTER_X0TILE   | GFXBG_DRAWING_FOOTER_Y0TILE<<16
	LDR	r1, =GFXBG_DRAWING_FOOTER_NTILESX  | GFXBG_DRAWING_FOOTER_NTILESY<<16
	LDR	r2, =GFXBG_DRAWING_FOOTER_TILEOFFS | 0x7000 | (0x02 * 32)<<16
	LDR	r3, =BGTILEMAPADR_B(2)
	BL	DrawArea_PrepTilemap

.LLoadGraphics_Exit:
	POP	{r4-r6,pc}

ASM_FUNC_END(Gfx_LoadGraphics)

/**************************************/

@ l = 0, r = 256*2^4 (.4fxp with Vtx16)
@ t = 0, b = 192*2^4 (.4fxp with Vtx16)
@ n = 0, f = -2.0

ASM_DATA_BEG(Gfx_LoadGraphics_OrthoProjMtx, ASM_SECTION_RODATA;ASM_ALIGN(4))

Gfx_LoadGraphics_OrthoProjMtx:
	.word  0x2000, 0x0000, 0x0000, 0x0000
	.word  0x0000,-0x2AAA, 0x0000, 0x0000
	.word  0x0000, 0x0000, 0x1000, 0x0000
	.word -0x1000, 0x1000,-0x1000, 0x1000

ASM_DATA_END(Gfx_LoadGraphics_OrthoProjMtx)

/**************************************/

ASM_DATA_BEG(Gfx_Visualizer_Backdrop, ASM_SECTION_RODATA;ASM_ALIGN(4))

Gfx_Visualizer_Backdrop:
	IncludeResource VisualizerBackdrop.gfx.lz

ASM_DATA_END(Gfx_Visualizer_Backdrop)

/**************************************/
//! EOF
/**************************************/
