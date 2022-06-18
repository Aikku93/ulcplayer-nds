/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

@ r0:      xDrawOffs (-255 .. +255)
@ r1:     &State
@ r2:     &Listings
@ r3:      nListings
@ r4:     [Reserved: &Main_State]
@ r5:     [Reserved:  MenuScrollPos]
@ r6..fp: [Available/Pushed]

ASM_FUNC_GLOBAL(Gfx_DrawPlaylist)
ASM_FUNC_BEG   (Gfx_DrawPlaylist, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_DrawPlaylist:
	STMFD	sp!, {r4,lr}
	LDR	sl, [r4, #0x20+0x10]                  @ NextData = DecoderState.NextData -> sl?
	LDMIA	r1, {ip,lr}                           @ VScroll -> ip, VScrollRate -> lr
	CMP	sl, #0x00
	LDRNE	sl, [r4, #0x18]                       @ Song is playing (NextData != NULL): PlayingTrack -> sl
	CMP	r0, #0x00                             @ If screen is not fully centered, clear out VScrollRate
	MOVNE	lr, #0x00
	ADDS	ip, ip, lr, asr #0x02                 @ VScroll = max(0, VScroll+VScrollRate/4) (NOTE: Scaled VScrollRate looks nicer)
	MOVMI	ip, #0x00
	RSBS	lr, lr, lr, lsl #0x05                 @ VScrollRate *= 31/32
	ADDMI	lr, lr, #0x1F                         @ <- Make sure to round towards 0
	MOV	lr, lr, asr #0x05
	SUBS	r4, r3, #GFXBG_PLAYLIST_TRACK_MAXDISP-1 @ Check nListings against MAXDISP (NOTE: -1 to discount the "extra" item used for scrolling)
	MOVLS	ip, #0x00                             @ if(nListings <= MAXDISP) VScroll = 0
	MOVLS	r6, r3                                @                          nItems  = nListings
	MOVHI	r6, #GFXBG_PLAYLIST_TRACK_SPACING     @ else VScroll = min(VScroll, (nItems-MAXDISP)*SPACING)
	SMULBBHI r4, r4, r6
	MOVHI	r6, #GFXBG_PLAYLIST_TRACK_MAXDISP     @      nItems  = MAXDISP
	CMPHI	ip, r4, lsl #0x08
	MOVHI	ip, r4, lsl #0x08
	STMIA	r1, {ip,lr}
	MOV	ip, ip, lsr #0x08                     @ (int)VScroll (ie. remove fractional portion)
.if GFXBG_PLAYLIST_TRACK_SPACING_RECP != 1
	LDR	lr, =GFXBG_PLAYLIST_TRACK_SPACING_RECP
.endif
	SUB	r6, r6, r6, lsl #0x10                 @ nItems | -nItemsRem<<16 -> r6
.if GFXBG_PLAYLIST_TRACK_SPACING_RECP != 1
	UMULL	r8, r1, ip, lr                        @ ListingOffs = VScroll / SPACING -> r1
.else
	MOV	r1, ip, lsr #GFXBG_PLAYLIST_TRACK_SPACING_RECPBITS
.endif
	LDR	r8, =TrackListings
	LDR	lr, =-GFXBG_PLAYLIST_TRACK_SPACING
.if GFXBG_PLAYLIST_TRACK_SPACING_RECP != 1
	MOV	r1, r1, lsr #GFXBG_PLAYLIST_TRACK_SPACING_RECPBITS-32
.endif
	SMLABB	ip, r1, lr, ip                        @ yDrawOffs = VScroll % SPACING -> ip
	ADD	r9, r2, r1, lsl #0x01                 @ Seek first visible item index -> r9
	ADD	r4, ip, r0, lsl #0x10                 @ yDrawOffs | xDrawOffs<<16 -> r4

@ r4:  yDrawOffs | xDrawOffs<<16
@ r5: [Reserved: MenuScrollPos]
@ r6:  nItems | -nItemsRem<<16
@ r7: &ThisTrackListing
@ r8: &Listings[]
@ r9: &ItemOrder[]
@ sl: &PlayingTrack
@ fp:  ItemIndex
.LDrawItemsLoop:
	LDRH	r7, [r9], #0x02                       @ ThisTrackListing = &Listings[*ItemOrder++] -> r7
	ADD	fp, r6, r6, lsl #0x10                 @ ItemIndex (=nItems-nItemsRem) -> fp
	MOV	fp, fp, lsr #0x10
	EOR	r0, r7, #0x00FF                       @ New artist marker?
	EORS	r0, r0, #0xFF00
	ADD	r7, r8, r7, lsl #0x05
	BEQ	.LDrawItems_NewArtist

.LDrawItems_DrawIcon:
	MOV	r0, r4, asr #0x10                     @ Ensure icon will be visible (xDrawOffs+ICON_X0 -> r0)
	ADD	r0, r0, #GFXOBJ_PLAYLIST_ICON_X0
	CMN	r0, #GFXOBJ_PLAYLIST_ICON_WIDTH
	RSBGTS	r1, r0, #0x0100
	BLE	.LDrawItems_DrawIcon_Skip
0:	LDR	lr, =0x07000400                       @ Build OAM data
	MOV	r0, r0, lsl #0x20-9                   @ Attr1 = OAM_X(xDrawOffs+ICON_X0)
	MOV	r0, r0, lsr #0x20-9-16
	CMP	r4, #0x00                             @ Check Left/Right icon placement
	LDRLT	r1, =GFXOBJ_PLAYLIST_ICON_L_TILEOFFS | 1<<10 | 15<<12 @ Attr2 = OAM_TILE(TileOffs) | OAM_PRIORITY(1) | OAM_ALPHA(15)
	LDRGE	r1, =GFXOBJ_PLAYLIST_ICON_R_TILEOFFS | 1<<10 | 15<<12
	ORR	r0, r0, #0x01<<30                     @ Attr1 |= OAM_SIZE_16x16
	ORR	r0, r0, #0x03<<10                     @ Attr0 |= OAM_BITMAP
	ORR	r0, r0, #GFXOBJ_PLAYLIST_ICON_Y0      @ Attr0 |= OAM_Y(yDrawOffs+ICON_Y0+ItemIndex*SPACING)
	MOV	ip, r4, lsl #0x10
	SUB	r0, r0, ip, lsr #0x10
	LDR	ip, =GFXBG_PLAYLIST_TRACK_SPACING
	SMLABB	r0, ip, fp, r0
	ADD	r1, r1, fp, lsl #0x02                 @ Attr2 += OAM_TILE(ItemIndex*4)
	ADD	lr, lr, fp, lsl #0x03                 @ Store to OAM[OAMOffs+ItemIndex]
	STRLTD	r0, [lr, #0x08*GFXOBJ_PLAYLIST_ICON_L_OBJID]
	STRGED	r0, [lr, #0x08*GFXOBJ_PLAYLIST_ICON_R_OBJID]
0:	LDR	r1, [r7, #0x0C]                       @ Load cover art
	LDRLT	r0, =OBJBITMAPPXADR_B(GFXOBJ_PLAYLIST_ICON_L_TILEOFFS)
	LDRGE	r0, =OBJBITMAPPXADR_B(GFXOBJ_PLAYLIST_ICON_R_TILEOFFS)
	CMP	r1, #0x00
	LDREQ	r1, =Gfx_GenericCoverArt              @  Load default if none found
	MOV	r2, #0x02 * 16*16                     @ Copy 16x16 icon
	ADD	r0, r0, fp, lsl #0x07+2
	BL	memcpy
.LDrawItems_DrawIcon_Skip:

.LDrawItems_DrawTitleArtist:
0:	LDR	r0, [r7, #0x04]                 @ Artist -> r0?
	LDR	r1, =GfxFont_NotoSans8
	CMP	r0, #0x00
	LDR	r2, =GfxBg_DrawBox_Playlist_Artist
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYLIST_ARTIST_INK<<24
	ADD	r2, r2, fp, lsl #0x03
	MOV	ip, r4, lsl #0x10
	ADD	r3, r3, r4, asr #0x10
	SUB	r3, r3, ip, lsr #0x10-12
	LDREQ	r0, =.LString_UnknownArtist     @  If no artist, use Artist="Unknown Artist"
	BL	Text_DrawString_Boxed
0:	LDR	r0, [r7, #0x00]                 @ Title -> r0?
	LDR	ip, [r7, #0x08]                 @ Filename -> ip (to check flags)
	LDR	r1, =GfxFont_NotoSans9
	CMP	r0, #0x00                       @  If no Title, use Title=Filename
	BLEQ	.LDrawTitleArtist_UseFilename
	LDR	r2, =GfxBg_DrawBox_Playlist_Title
	TST	ip, #TRACKLISTING_UNPLAYABLE
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYLIST_TITLE_INK<<24
	ADD	r2, r2, fp, lsl #0x03
	EORNE	r3, r3, #(GFXBG_PLAYLIST_TITLE_INK^GFXBG_PLAYLIST_TITLE_INK_UNPLAYABLE)<<24
	CMPEQ	r7, sl
	EOREQ	r3, r3, #(GFXBG_PLAYLIST_TITLE_INK^GFXBG_PLAYLIST_TITLE_INK_ACTIVE)<<24
	MOV	ip, r4, lsl #0x10
	ADD	r3, r3, r4, asr #0x10
	SUB	r3, r3, ip, lsr #0x10-12
	BL	Text_DrawString_Boxed

.LDrawItems_DrawDuration:
	SUB	sp, sp, #0x20
	MOV	r0, sp          @ Dst = Temp -> r0
	LDR	r1, [r7, #0x18] @ Seconds = Duration -> r1
	MOV	r2, #0x03       @ NumDigits = 3 + (Duration >= 10:00) + (Duration >= 1:00:00) -> r2
	CMP	r1, #10*60
	ADDCS	r2, r2, #0x01
	CMP	r1, #60*60
	ADDCS	r2, r2, #0x01
	BL	strfsecs_Safe
	MOV	r0, sp
	LDR	r1, =GfxFont_NotoSans8
	LDR	r2, =GfxBg_DrawBox_Playlist_Duration
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYLIST_DURATION_INK<<24
	ADD	r2, r2, fp, lsl #0x03
	MOV	ip, r4, lsl #0x10
	ADD	r3, r3, r4, asr #0x10
	SUB	r3, r3, ip, lsr #0x10-12
	BL	Text_DrawString_Boxed
	ADD	sp, sp, #0x20

.LDrawItemsLoop_Tail:
	ADDS	r6, r6, #0x01<<16
	BCC	.LDrawItemsLoop

.LExit:
	LDMFD	sp!, {r4,pc}

.LDrawTitleArtist_UseFilename:
	BIC	r0, ip, #TRACKLISTING_FLAGS_MASK
	STMFD	sp!, {r0,r1,ip,lr}
	MOV	r1, #'/'
	BL	strrchr
	MOVS	r2, r0
	LDMFD	sp!, {r0,r1,ip,lr}
	ADDNE	r0, r2, #0x01
	BX	lr

.LDrawItems_NewArtist:
	LDRH	r0, [r9]                        @ Next.Artist -> r0?
	LDR	r1, =GfxFont_NotoSans10
	ADD	r0, r8, r0, lsl #0x05
	LDR	r0, [r0, #0x04]
	LDR	r2, =GfxBg_DrawBox_Playlist_ArtistHeader
	LDR	r3, =(0+DRAW_BIAS) | (0+DRAW_BIAS)<<12 | GFXBG_PLAYLIST_ARTISTHEADER_INK<<24
	ADD	r2, r2, fp, lsl #0x03
	MOV	ip, r4, lsl #0x10
	ADD	r3, r3, r4, asr #0x10
	SUB	r3, r3, ip, lsr #0x10-12
	CMP	r0, #0x00
	LDREQ	r0, =.LString_UnknownArtist     @  If no artist, use Artist="Unknown Artist"
	BL	Text_DrawString_Boxed
	B	.LDrawItemsLoop_Tail

ASM_FUNC_END(Gfx_DrawPlaylist)

/**************************************/

ASM_DATA_BEG(Gfx_DrawPlaylist_Strings, ASM_SECTION_RODATA;ASM_ALIGN(1))

Gfx_DrawPlaylist_Strings:
.LString_UnknownArtist: .asciz "Unknown Artist"

ASM_DATA_END(Gfx_DrawPlaylist_Strings)

/**************************************/

ASM_DATA_BEG(GfxBg_DrawBox_Playlist_Title, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playlist_Title:
.macro GfxBg_DrawBox_Playlist_Title_Create n
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_PLAYLIST_TITLE_X0,      GFXBG_PLAYLIST_TITLE_Y0 + GFXBG_PLAYLIST_TRACK_SPACING*(GFXBG_PLAYLIST_TRACK_MAXDISP-(\n))
	.byte GFXBG_PLAYLIST_TITLE_WIDTH-1, GFXBG_PLAYLIST_TITLE_HEIGHT-1
.if (\n)-1
	GfxBg_DrawBox_Playlist_Title_Create (\n)-1
.endif
.endm
	GfxBg_DrawBox_Playlist_Title_Create GFXBG_PLAYLIST_TRACK_MAXDISP
ASM_DATA_END(GfxBg_DrawBox_Playlist_Title)

ASM_DATA_BEG(GfxBg_DrawBox_Playlist_Artist, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playlist_Artist:
.macro GfxBg_DrawBox_Playlist_Artist_Create n
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_PLAYLIST_ARTIST_X0,      GFXBG_PLAYLIST_ARTIST_Y0 + GFXBG_PLAYLIST_TRACK_SPACING*(GFXBG_PLAYLIST_TRACK_MAXDISP-(\n))
	.byte GFXBG_PLAYLIST_ARTIST_WIDTH-1, GFXBG_PLAYLIST_ARTIST_HEIGHT-1
.if (\n)-1
	GfxBg_DrawBox_Playlist_Artist_Create (\n)-1
.endif
.endm
	GfxBg_DrawBox_Playlist_Artist_Create GFXBG_PLAYLIST_TRACK_MAXDISP
ASM_DATA_END(GfxBg_DrawBox_Playlist_Artist)

ASM_DATA_BEG(GfxBg_DrawBox_Playlist_Duration, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playlist_Duration:
.macro GfxBg_DrawBox_Playlist_Duration_Create n
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_RIGHT
	.byte GFXBG_PLAYLIST_DURATION_X0,      GFXBG_PLAYLIST_DURATION_Y0 + GFXBG_PLAYLIST_TRACK_SPACING*(GFXBG_PLAYLIST_TRACK_MAXDISP-(\n))
	.byte GFXBG_PLAYLIST_DURATION_WIDTH-1, GFXBG_PLAYLIST_DURATION_HEIGHT-1
.if (\n)-1
	GfxBg_DrawBox_Playlist_Duration_Create (\n)-1
.endif
.endm
	GfxBg_DrawBox_Playlist_Duration_Create GFXBG_PLAYLIST_TRACK_MAXDISP
ASM_DATA_END(GfxBg_DrawBox_Playlist_Duration)

ASM_DATA_BEG(GfxBg_DrawBox_Playlist_ArtistHeader, ASM_SECTION_RODATA;ASM_ALIGN(4))
GfxBg_DrawBox_Playlist_ArtistHeader:
.macro GfxBg_DrawBox_Playlist_ArtistHeader_Create n
	.word GfxBg_DrawArea_Body + DRAWBOX_ALIGN_LEFT
	.byte GFXBG_PLAYLIST_ARTISTHEADER_X0,      GFXBG_PLAYLIST_ARTISTHEADER_Y0 + GFXBG_PLAYLIST_TRACK_SPACING*(GFXBG_PLAYLIST_TRACK_MAXDISP-(\n))
	.byte GFXBG_PLAYLIST_ARTISTHEADER_WIDTH-1, GFXBG_PLAYLIST_ARTISTHEADER_HEIGHT-1
.if (\n)-1
	GfxBg_DrawBox_Playlist_ArtistHeader_Create (\n)-1
.endif
.endm
	GfxBg_DrawBox_Playlist_ArtistHeader_Create GFXBG_PLAYLIST_TRACK_MAXDISP
ASM_DATA_END(GfxBg_DrawBox_Playlist_ArtistHeader)

/**************************************/
//! EOF
/**************************************/
