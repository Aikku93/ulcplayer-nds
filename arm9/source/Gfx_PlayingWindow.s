/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainDefines.inc"
#include "MainGraphicsDefines.inc"
/**************************************/

@ r4:     [Reserved: &Main_State]
@ r5:     [Reserved:  MenuScrollPos]
@ r6..fp: [Available/Pushed]

ASM_FUNC_GLOBAL(Gfx_DrawPlayingWindow)
ASM_FUNC_BEG   (Gfx_DrawPlayingWindow, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_DrawPlayingWindow:
	STMFD	sp!, {r5,lr}
	RSB	r5, r5, #SCROLLOFFS_PLAYING @ xDrawOffs -> r5
	LDR	r6, [r4, #0x18]             @ PlayingTrack -> r6

.LDrawTitleArtist:
0:	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYING_ARTIST_INK<<24
	LDR	r0, [r6, #0x04]             @ Artist -> r0?
	LDR	r1, =GfxFont_NotoSans8
	CMP	r0, #0x00
	LDREQ	r0, =.LString_UnknownArtist @  If no artist, use Artist="Unknown Artist"
	LDR	r2, =GfxBg_DrawBox_Playing_Artist
	ADD	r3, r3, r5
	BL	Text_DrawString_Boxed
0:	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYING_TITLE_INK<<24
	LDR	r0, [r6, #0x00]             @ Title -> r0?
	LDR	r1, =GfxFont_NotoSans9
	CMP	r0, #0x00                   @  If no title, use Title=Filename
	BLEQ	.LDrawTitleArtist_UseFilename
	LDR	r2, =GfxBg_DrawBox_Playing_Title
	ADD	r3, r3, r5
	BL	Text_DrawString_Boxed

.LDrawIcon:
	LDR	r1, [r6, #0x0C]                 @ Load default cover art if none found
	LDR	r0, =OBJBITMAPPXADR_B(GFXOBJ_PLAYING_ICON_TILEOFFS)
	CMP	r1, #0x00
	LDREQ	r1, =Gfx_GenericCoverArt
	MOV	r2, #0x02 * 64*64               @ Copy 64x64 icon
	ADD	r1, r1, #0x02 * 16*16
	BL	memcpy
0:	ADD	r2, r5, #GFXOBJ_PLAYING_ICON_X0 @ Build OAM data
	CMN	r2, #GFXOBJ_PLAYING_ICON_WIDTH
	RSBGTS	r3, r2, #0x0100
	MOVGT	r2, r2, lsl #0x20-9
	MOVGT	r2, r2, lsr #0x20-9-16
	LDRGT	r0, =0x07000400
	LDRGT	r3, =GFXOBJ_PLAYING_ICON_TILEOFFS | 15<<12
	ORRGT	r2, r2, #0x03<<30
	ORRGT	r2, r2, #0x03<<10
	ORRGT	r2, r2, #GFXOBJ_PLAYING_ICON_Y0
	STRGTD	r2, [r0, #0x08*GFXOBJ_PLAYING_ICON_OBJID]

.LPushString:
	SUB	sp, sp, #0x20 @ Allocate space for some strings

.LDrawTime:
	MOV	r0, sp                @ Dst = Temp -> r0
	LDR	r1, [r6, #0x18]       @ Seconds = Duration -> r1
	MOV	r2, #0x03             @ NumDigits = 3 + (Duration >= 10:00) + (Duration >= 1:00:00) -> r2
	CMP	r1, #10*60
	ADDCS	r2, r2, #0x01
	CMP	r1, #60*60
	ADDCS	r2, r2, #0x01
	MOV	r7, r2                @ NumDigits -> r7 (for next call)
	BL	strfsecs_Safe
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYING_ENDTIME_INK<<24
	MOV	r0, sp
	LDR	r1, =GfxFont_NotoSans8
	LDR	r2, =GfxBg_DrawBox_Playing_EndTime
	ADD	r3, r3, r5
	BL	Text_DrawString_Boxed
0:	LDRH	r0, [r4, #0x20+0x1C]  @ BlockSize -> r0
	LDR	r2, [r4, #0x20+0x04]  @ nBlkRem -> r2
	LDR	r1, [r6, #0x10]       @ RateHz -> r1
	MUL	r0, r2, r0            @ nSecondsRem = nSamplesRem(=nBlkRem*BlockSize) / RateHz
	BL	__udivsi3
	LDR	r1, [r6, #0x18]       @ Seconds = Duration - nSecondsRem -> r1
	MOV	r2, r7                @ nDigits -> r2
	SUB	r1, r1, r0
	MOV	r0, sp                @ Dst = Temp -> r0
	BL	strfsecs_Safe
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYING_CURTIME_INK<<24
	MOV	r0, sp
	LDR	r1, =GfxFont_NotoSans8
	LDR	r2, =GfxBg_DrawBox_Playing_CurTime
	ADD	r3, r3, r5
	BL	Text_DrawString_Boxed

@ This is running inside an interrupt, so no sprintf() :(
.LDrawStats:
	LDR	r2, [r6, #0x10]       @ Number = RateKHz(=RateHz/1000) -> r2,r3 [.38fxp]
	LDR	r3, =0x10624DD3
	MOV	r0, sp                @ Dst = Temp -> r0
	UMULL	r2, r3, r2, r3
	MOV	r2, #0x00             @ PadChar/nMinChar=0
	MOV	r1, r3, lsr #0x06     @ Number -> r1
	BL	itoa_Safe
	LDR	r1, =.LString_Joiner1 @ "kHz @ "
	BL	strcpy_Safe
	LDRH	r1, [r6, #0x14]       @ Number = RateKbps -> r1
	MOV	r2, #0x00             @ PadChar/nMinChar=0
	BL	itoa_Safe
	LDR	r1, =.LString_Joiner2 @ "kbps ("
	BL	strcpy_Safe
	LDRH	r1, [r6, #0x16]       @ "Mono)"/"Stereo)"
	CMP	r1, #0x02
	LDRCC	r1, =.LString_Mono
	LDRCS	r1, =.LString_Stereo
	BL	strcpy_Safe
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYING_STATS_INK<<24
	MOV	r0, sp
	LDR	r1, =GfxFont_NotoSans8
	LDR	r2, =GfxBg_DrawBox_Playing_Stats
	ADD	r3, r3, r5
	BL	Text_DrawString_Boxed

.LPopString_Exit:
	ADD	sp, sp, #0x20

.LExit:
	LDMFD	sp!, {r5,pc}

.LDrawTitleArtist_UseFilename:
	LDR	r0, [r6, #0x08] @ Strip directory from filename
	BIC	r0, r0, #TRACKLISTING_FLAGS_MASK
	STMFD	sp!, {r0,r1,r3,lr}
	MOV	r1, #'/'
	BL	strrchr
	MOVS	r2, r0
	LDMFD	sp!, {r0,r1,r3,lr}
	ADDNE	r0, r2, #0x01
	BX	lr

ASM_FUNC_END(Gfx_DrawPlayingWindow)

/**************************************/

ASM_DATA_BEG(Gfx_PlayingWindow_Strings, ASM_SECTION_RODATA;ASM_ALIGN(1))

Gfx_PlayingWindow_Strings:
.LString_UnknownArtist: .asciz "Unknown Artist"
.LString_Joiner1:       .asciz "kHz @ "
.LString_Joiner2:       .asciz "kbps ("
.LString_Mono:          .asciz "Mono)"
.LString_Stereo:        .asciz "Stereo)"

ASM_DATA_END(Gfx_PlayingWindow_Strings)

/**************************************/

ASM_DATA_BEG(GfxBg_DrawBox_Playing_Title, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playing_Title:
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_PLAYING_TITLE_X0,      GFXBG_PLAYING_TITLE_Y0
	.byte GFXBG_PLAYING_TITLE_WIDTH-1, GFXBG_PLAYING_TITLE_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Playing_Title)

ASM_DATA_BEG(GfxBg_DrawBox_Playing_Artist, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playing_Artist:
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_PLAYING_ARTIST_X0,      GFXBG_PLAYING_ARTIST_Y0
	.byte GFXBG_PLAYING_ARTIST_WIDTH-1, GFXBG_PLAYING_ARTIST_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Playing_Artist)

ASM_DATA_BEG(GfxBg_DrawBox_Playing_CurTime, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playing_CurTime:
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_PLAYING_CURTIME_X0,      GFXBG_PLAYING_CURTIME_Y0
	.byte GFXBG_PLAYING_CURTIME_WIDTH-1, GFXBG_PLAYING_CURTIME_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Playing_CurTime)

ASM_DATA_BEG(GfxBg_DrawBox_Playing_EndTime, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playing_EndTime:
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_RIGHT
	.byte GFXBG_PLAYING_ENDTIME_X0,      GFXBG_PLAYING_ENDTIME_Y0
	.byte GFXBG_PLAYING_ENDTIME_WIDTH-1, GFXBG_PLAYING_ENDTIME_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Playing_EndTime)

ASM_DATA_BEG(GfxBg_DrawBox_Playing_Stats, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playing_Stats:
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_PLAYING_STATS_X0,      GFXBG_PLAYING_STATS_Y0
	.byte GFXBG_PLAYING_STATS_WIDTH-1, GFXBG_PLAYING_STATS_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Playing_Stats)

/**************************************/
//! EOF
/**************************************/
