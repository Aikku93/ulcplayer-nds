/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainDefines.inc"
#include "MainGraphicsDefines.inc"
/**************************************/

ASM_FUNC_GLOBAL(Gfx_UpdateGraphics)
ASM_FUNC_BEG   (Gfx_UpdateGraphics, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_UpdateGraphics:
	STMFD	sp!, {r3-fp,lr}
	MOV	r0, #0x04000000
	LDR	r1, =0x04001000
	LDR	ip, =0x00010108                 @ DISPCNT_A = MODE(0) | BG0_3D | DISPMODE(1)
	LDR	lr, =0x00011D40                 @ DISPCNT_B = MODE(0) | BMPOBJBOUNDARY_128B | BG0 | BG2 | BG3 | OBJ | DISPMODE(1)
	LDR	r4, =Main_State
	STR	ip, [r0]
	LDRB	r0, [r4, #0x0C]                 @ Make sure we are ready for another update (nested interrupts are a very bad idea here)
	STR	lr, [r1]
	MOV	r1, #0x01
	STRB	r1, [r4, #0x0C]                 @ [State.BusyFlag = TRUE]
	CMP	r0, #0x00
	LDMNEFD	sp!, {r3-fp,pc}
1:	LDR	r0, =0x07000400                 @ Disable all used OAM entries (we will enable them as needed)
	MOV	r1, #GFXOBJ_NEXT_OBJID
	MOV	r2, #0x0200
10:	STRH	r2, [r0], #0x08
	SUBS	r1, r1, #0x01
	BNE	10b
2:	LDR	r0, [r4, #0x08]                 @ MenuScrollPos | MenuScrollTarget<<16 -> r0
	MOV	r1, r0, lsr #0x10               @ MenuScrollPos += (MenuScrollTarget-MenuScrollPos) / 4 -> r5
	BIC	r0, r0, r1, lsl #0x10
	SUBS	r1, r1, r0
	ADDHI	r1, r1, #0x03
	ADD	r5, r0, r1, asr #0x02
	STRH	r5, [r4, #0x08]
3:	ADD	r0, r4, #0x20                   @ DC_InvalidateLine(State)
	MCR	p15,0,r0,c7,c6,1                @ We read State fairly often in this routine, so may as well do this once only

.LSetPlaybackModesObj:
	LDRB	r0, [r4, #0x0D]                 @ Set Shuffle/Repeat mode OAM
	LDR	r1, =0x07000400
1:	LDR	r2, =GFXOBJ_MAINWINDOW_MENU_SHUFFLE_Y0 | 3<<10 | GFXOBJ_MAINWINDOW_MENU_SHUFFLE_X0<<16 | 1<<30
	LDR	r3, =GFXOBJ_MAINWINDOW_MENU_SHUFFLE_TILE_OFF | 15<<12
	MOVS	r0, r0, lsr #0x01               @ C=Shuffle? (and RepeatMode -> r0)
	EORCS	r3, r3, #GFXOBJ_MAINWINDOW_MENU_SHUFFLE_TILE_OFF^GFXOBJ_MAINWINDOW_MENU_SHUFFLE_TILE_ON
	STRD	r2, [r1, #0x08*GFXOBJ_MAINWINDOW_MENU_SHUFFLE_OBJID]
1:	LDR	r2, =GFXOBJ_MAINWINDOW_MENU_REPEAT_Y0 | 3<<10 | GFXOBJ_MAINWINDOW_MENU_REPEAT_X0<<16 | 1<<30
	LDR	r3, =GFXOBJ_MAINWINDOW_MENU_REPEAT_TILE_OFF | 15<<12
	CMP	r0, #0x01
	EOREQ	r3, r3, #GFXOBJ_MAINWINDOW_MENU_REPEAT_TILE_SINGLE^GFXOBJ_MAINWINDOW_MENU_REPEAT_TILE_OFF
	EORHI	r3, r3, #GFXOBJ_MAINWINDOW_MENU_REPEAT_TILE_ALL^GFXOBJ_MAINWINDOW_MENU_REPEAT_TILE_OFF
	STRD	r2, [r1, #0x08*GFXOBJ_MAINWINDOW_MENU_REPEAT_OBJID]

.LDrawMenuLabels:
	ADD	r6, r5, #0x80                   @ ActiveWindow = Round[MenuScrollPos/SCREEN_WIDTH] -> r6
	MOV	r6, r6, lsr #0x08
0:	LDR	r0, =GfxBg_DrawArea_Menu
	BL	DrawArea_Clear
1:	LDR	r0, =.LString_Songs
	LDR	r1, =GfxFont_NotoSans12
	LDR	r2, =GfxBg_DrawBox_Menu_Songs
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_MAINWINDOW_MENU_SONGS_INK_INACTIVE<<24
	CMP	r6, #0x00
	EOREQ	r3, r3, #(GFXBG_MAINWINDOW_MENU_SONGS_INK_ACTIVE^GFXBG_MAINWINDOW_MENU_SONGS_INK_INACTIVE)<<24
	BL	Text_DrawString_Boxed
2:	LDR	r0, =.LString_Artists
	LDR	r1, =GfxFont_NotoSans12
	LDR	r2, =GfxBg_DrawBox_Menu_Artists
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_MAINWINDOW_MENU_ARTISTS_INK_INACTIVE<<24
	CMP	r6, #0x01
	EOREQ	r3, r3, #(GFXBG_MAINWINDOW_MENU_ARTISTS_INK_ACTIVE^GFXBG_MAINWINDOW_MENU_ARTISTS_INK_INACTIVE)<<24
	BL	Text_DrawString_Boxed
3:	LDR	r0, =.LString_Playing
	LDR	r1, =GfxFont_NotoSans12
	LDR	r2, =GfxBg_DrawBox_Menu_Playing
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_MAINWINDOW_MENU_PLAYING_INK_INACTIVE<<24
	CMP	r6, #0x02
	EOREQ	r3, r3, #(GFXBG_MAINWINDOW_MENU_PLAYING_INK_ACTIVE^GFXBG_MAINWINDOW_MENU_PLAYING_INK_INACTIVE)<<24
	BL	Text_DrawString_Boxed

.LDrawBody:
	LDR	r0, =GfxBg_DrawArea_Body
	BL	DrawArea_Clear
0:	CMP	r5, #SCROLLOFFS_ARTISTS         @            Pos < ARTISTS? Draw SONGS
	BLCC	Gfx_DrawSongsWindow
	RSBS	r0, r5, #SCROLLOFFS_SONGS       @ SONGS   <  Pos < PLAYING? Draw ARTISTS
	CMPCC	r5, #SCROLLOFFS_PLAYING
	BLCC	Gfx_DrawArtistsWindow
	CMP	r5, #SCROLLOFFS_ARTISTS         @            Pos > ARTISTS? Draw PLAYING
	BLHI	Gfx_DrawPlayingWindow

.LDrawFooter:
	LDR	r5, [r4, #0x18]                 @ PlayingTrack -> r5
	LDR	r0, =GfxBg_DrawArea_Footer
	BL	DrawArea_Clear

@ Title is drawn last, in case its glyphs overlap with those of Artist,
@ and because it has a brighter ink, it should hide defects better.
.LDrawFooter_DrawTitleArtist:
0:	LDR	r0, [r5, #0x04]                 @ Artist -> r0?
	LDR	r1, =GfxFont_NotoSans8
	CMP	r0, #0x00
	LDREQ	r0, =.LString_UnknownArtist     @  If no artist, use Artist="Unknown Artist"
	LDR	r2, =GfxBg_DrawBox_Footer_Artist
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_MAINWINDOW_FOOTER_ARTIST_INK<<24
	BL	Text_DrawString_Boxed
0:	LDR	r0, [r5, #0x00]                 @ Title -> r0?
	LDR	r1, =GfxFont_NotoSans9
	CMP	r0, #0x00                       @  If no title, use Title=Filename
	BLEQ	.LDrawFooter_DrawTitleArtist_UseFilename
	LDR	r2, =GfxBg_DrawBox_Footer_Title
	LDR	ip, [r4, #0x14]
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_MAINWINDOW_FOOTER_TITLE_INK<<24
	SUB	r3, r3, ip, asr #0x08
	BL	Text_DrawString_Boxed
0:	CMP	r0, #GFXBG_MAINWINDOW_FOOTER_TITLE_WIDTH @ Need scrolling?
	LDRGT	r1, [r4, #0x14]
	MOVLE	r1, #0x00                                @  No scrolling: Reset HScroll=0 (in case of song switch)
	ADDGT	r1, r1, #0x40                            @  Scrolling: Increase scroll
	CMPGT	r1, r0, lsl #0x08                        @             When the text disappears, restart scroll
	LDRGT	r1, =-(GFXBG_MAINWINDOW_FOOTER_TITLE_WIDTH<<8)
	STR	r1, [r4, #0x14]

.LDrawFooter_DrawIcon:
	LDR	r1, [r5, #0x0C]                 @ Load default cover art if none found
	LDR	r0, =OBJBITMAPPXADR_B(GFXOBJ_MAINWINDOW_FOOTER_ICON_TILEOFFS)
	CMP	r1, #0x00
	LDREQ	r1, =Gfx_GenericCoverArt
	MOV	r2, #0x02 * 16*16               @ Copy 16x16 icon
	BL	memcpy
0:	LDR	r0, =0x07000400
	LDR	r2, =GFXOBJ_MAINWINDOW_FOOTER_ICON_Y0 | 3<<10 | GFXOBJ_MAINWINDOW_FOOTER_ICON_X0<<16 | 1<<30
	LDR	r3, =GFXOBJ_MAINWINDOW_FOOTER_ICON_TILEOFFS | 15<<12
	STRD	r2, [r0, #0x08*GFXOBJ_MAINWINDOW_FOOTER_ICON_OBJID]

@ nSecondsRem = nSamplesRem(=nBlkRem*BlockSize) / RateHz
@ nSeconds = Duration - nSecondsRem
@ DrawWidth = WIDTH * (nSeconds / Duration)
@           = WIDTH - nBlkRem*BlockSize*WIDTH/(RateHz*Duration)
@ NOTE: Hardware Div in use here
.LDrawFooter_DrawTransportProgress:
	LDRH	r0, [r4, #0x20+0x1C]    @ BlockSize -> r0
	LDR	r1, [r4, #0x20+0x04]    @ nBlkRem -> r1
	LDR	r2, [r5, #0x10]         @ RateHz -> r2
	LDR	r3, [r5, #0x18]         @ Duration -> r3
	MOV	ip, #GFXBG_MAINWINDOW_FOOTER_TRANSPORT_WIDTH
	SMULBB	r0, r0, ip              @ DIV_NUMER = nBlkRem*BlockSize*WIDTH -> r0,r1
	MOV	ip, #0x04000002         @ &REG_DIVCNT + 2 -> ip
	ADD	ip, ip, #0x0280
	UMULL	r0, r1, r0, r1
	UMULL	r2, r3, r2, r3          @ DIV_DENOM = RateHz*Duration -> r2,r3
	STRD	r0, [ip, #0x10-2]
	STRD	r2, [ip, #0x18-2]
	STRH	ip, [ip, #0x00-2]       @ DIVCNT    = DIV_64_64
0:	LDRH	r0, [ip, #0x00-2]       @ Busy wait
	TST	r0, #0x8000
	BNE	0b
	LDR	r0, [ip, #0x20-2]       @ DrawWidth = WIDTH - DIV_RESULT
	LDR	r1, =BGTILEPXADR4_B(GFXBG_DRAWING_FOOTER_TILEOFFS, 4) + \
		     (GFXBG_MAINWINDOW_FOOTER_TRANSPORT_Y0-GFXBG_DRAWING_FOOTER_Y0TILE*8)*8 + \
		     (GFXBG_MAINWINDOW_FOOTER_TRANSPORT_X0-GFXBG_DRAWING_FOOTER_X0TILE*8)/8*8 * GFXBG_DRAWING_FOOTER_NTILESY*8
	LDR	r2, =0x11111111 * GFXBG_MAINWINDOW_FOOTER_TRANSPORT_INK
	RSBS	r0, r0, #GFXBG_MAINWINDOW_FOOTER_TRANSPORT_WIDTH
	MOVCC	r0, #0x00
	MOV	r3, r2
1:	SUBS	r0, r0, #0x08           @ Draw in groups of 8px
	STRCS	r2, [r1], #GFXBG_DRAWING_FOOTER_NTILESY * (8*8/2)
	BHI	1b
2:	ANDS	r0, r0, #0x07           @ Store final 1..7px
	MOVNE	r0, r0, lsl #0x02
	BICNE	r2, r2, r2, lsl r0
	STRNE	r2, [r1]

.LDrawVisualizer:
	BL	Gfx_DrawVisualizerScreen

.LExit:
	MOV	r0, #0x00
	STRB	r0, [r4, #0x0C]         @ State.BusyFlag = FALSE
	LDMFD	sp!, {r3-fp,pc}

.LDrawFooter_DrawTitleArtist_UseFilename:
	LDR	r0, [r5, #0x08]
	BIC	r0, r0, #TRACKLISTING_FLAGS_MASK
	STMFD	sp!, {r0,r1,ip,lr}
	MOV	r1, #'/'
	BL	strrchr
	MOVS	r2, r0
	LDMFD	sp!, {r0,r1,ip,lr}
	ADDNE	r0, r2, #0x01
	BX	lr

ASM_FUNC_END(Gfx_UpdateGraphics)

/**************************************/

ASM_DATA_BEG(Gfx_UpdateGraphics_Strings, ASM_SECTION_RODATA;ASM_ALIGN(1))

Gfx_UpdateGraphics_Strings:
.LString_Songs:         .asciz "Songs"
.LString_Artists:       .asciz "Artists"
.LString_Playing:       .asciz "Playing"
.LString_UnknownArtist: .asciz "Unknown Artist"

ASM_DATA_END(Gfx_UpdateGraphics_Strings)

/**************************************/

ASM_DATA_GLOBAL(GfxBg_DrawArea_Menu)
ASM_DATA_BEG   (GfxBg_DrawArea_Menu, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawArea_Menu:
	.word BGTILEPXADR4_B(GFXBG_DRAWING_MENU_TILEOFFS, 4)
	.byte GFXBG_DRAWING_MENU_X0TILE,  GFXBG_DRAWING_MENU_Y0TILE
	.byte GFXBG_DRAWING_MENU_NTILESX, GFXBG_DRAWING_MENU_NTILESY
ASM_DATA_END(GfxBg_DrawArea_Menu)

ASM_DATA_GLOBAL(GfxBg_DrawArea_Body)
ASM_DATA_BEG   (GfxBg_DrawArea_Body, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawArea_Body:
	.word BGTILEPXADR4_B(GFXBG_DRAWING_BODY_TILEOFFS, 4)
	.byte GFXBG_DRAWING_BODY_X0TILE,  GFXBG_DRAWING_BODY_Y0TILE
	.byte GFXBG_DRAWING_BODY_NTILESX, GFXBG_DRAWING_BODY_NTILESY
ASM_DATA_END(GfxBg_DrawArea_Body)

ASM_DATA_GLOBAL(GfxBg_DrawArea_Footer)
ASM_DATA_BEG   (GfxBg_DrawArea_Footer, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawArea_Footer:
	.word BGTILEPXADR4_B(GFXBG_DRAWING_FOOTER_TILEOFFS, 4)
	.byte GFXBG_DRAWING_FOOTER_X0TILE,  GFXBG_DRAWING_FOOTER_Y0TILE
	.byte GFXBG_DRAWING_FOOTER_NTILESX, GFXBG_DRAWING_FOOTER_NTILESY
ASM_DATA_END(GfxBg_DrawArea_Footer)

/**************************************/

ASM_DATA_BEG(GfxBg_DrawBox_Menu_Songs, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Menu_Songs:
	.word GfxBg_DrawArea_Menu + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_MAINWINDOW_MENU_SONGS_X0,      GFXBG_MAINWINDOW_MENU_SONGS_Y0
	.byte GFXBG_MAINWINDOW_MENU_SONGS_WIDTH-1, GFXBG_MAINWINDOW_MENU_SONGS_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Menu_Songs)

ASM_DATA_BEG(GfxBg_DrawBox_Menu_Artists, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Menu_Artists:
	.word GfxBg_DrawArea_Menu + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_MAINWINDOW_MENU_ARTISTS_X0,      GFXBG_MAINWINDOW_MENU_ARTISTS_Y0
	.byte GFXBG_MAINWINDOW_MENU_ARTISTS_WIDTH-1, GFXBG_MAINWINDOW_MENU_ARTISTS_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Menu_Artists)

ASM_DATA_BEG(GfxBg_DrawBox_Menu_Playing, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Menu_Playing:
	.word GfxBg_DrawArea_Menu + DRAWBOX_ALIGN_CENTER
	.byte GFXBG_MAINWINDOW_MENU_PLAYING_X0,      GFXBG_MAINWINDOW_MENU_PLAYING_Y0
	.byte GFXBG_MAINWINDOW_MENU_PLAYING_WIDTH-1, GFXBG_MAINWINDOW_MENU_PLAYING_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Menu_Playing)

ASM_DATA_BEG(GfxBg_DrawBox_Footer_Title, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Footer_Title:
	.word GfxBg_DrawArea_Footer + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_MAINWINDOW_FOOTER_TITLE_X0,      GFXBG_MAINWINDOW_FOOTER_TITLE_Y0
	.byte GFXBG_MAINWINDOW_FOOTER_TITLE_WIDTH-1, GFXBG_MAINWINDOW_FOOTER_TITLE_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Footer_Title)

ASM_DATA_BEG(GfxBg_DrawBox_Footer_Artist, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Footer_Artist:
	.word GfxBg_DrawArea_Footer + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_MAINWINDOW_FOOTER_ARTIST_X0,      GFXBG_MAINWINDOW_FOOTER_ARTIST_Y0
	.byte GFXBG_MAINWINDOW_FOOTER_ARTIST_WIDTH-1, GFXBG_MAINWINDOW_FOOTER_ARTIST_HEIGHT-1
ASM_DATA_END(GfxBg_DrawBox_Footer_Artist)

/**************************************/
//! EOF
/**************************************/
