/**************************************/
#include "AsmMacros.h"
#include "NK_Tick.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

#define MSEC2TICK(x) ((x) * (33513982 / NK_TICK_CYCLES_PER_TICK) / 1000)

/**************************************/

ASM_DATA_GLOBAL(Main_GestureList)
ASM_DATA_BEG   (Main_GestureList, ASM_SECTION_RODATA;ASM_ALIGN(4))

Main_GestureList:
	.word (.LGestures_End - .LGestures_Beg) / 0x28
.LGestures_Beg:
	@ Used to scroll between the menus by touching the window body
	@ This is just a fallback for the other gesture nodes
	.LGesture_MenuScroll:
		.byte GFXBG_MAINWINDOW_BODY_X0 @ BBox
		.byte GFXBG_MAINWINDOW_BODY_X1-1
		.byte GFXBG_MAINWINDOW_BODY_Y0
		.byte GFXBG_MAINWINDOW_BODY_Y1-1
		.hword 0x01        @ Flags     = AllowMoveX
		.hword 0           @ Priority  = 0
		.hword 0           @ TapTicks  = 0
		.hword 0           @ HoldTicks = 0
		.word  Main_State  @ Userdata  = &State
		.word  0,0         @ Prev,Next = NULL
		.word  Gesture_MenuScroll_Touch   @ TouchCb
		.word  0                          @ TapCb
		.word  0                          @ DragCb
		.word  Gesture_MenuScroll_Release @ ReleaseCb

	@ Used to interact with a playlist
	.LGesture_Playlist:
		.byte  GFXBG_PLAYLIST_ITEM_X0 @ BBox
		.byte  GFXBG_PLAYLIST_ITEM_X1-1
		.byte  GFXBG_PLAYLIST_ITEM_Y0
		.byte  GFXBG_PLAYLIST_ITEM_Y0+GFXBG_PLAYLIST_TRACK_SPACING*(GFXBG_PLAYLIST_TRACK_MAXDISP-1)-1
		.hword 0x02           @ Flags     = AllowMoveY
		.hword 1              @ Priority  = 1
		.hword MSEC2TICK(50)  @ TapTicks  = 50ms
		.hword MSEC2TICK(500) @ HoldTicks = 500ms
		.word  Main_State     @ Userdata  = &State
		.word  0,0            @ Prev,Next = NULL
		.word  Gesture_Playlist_Touch @ TouchCb
		.word  Gesture_Playlist_Tap   @ TapCb
		.word  0                      @ DragCb
		.word  0                      @ ReleaseCb

	@ Used to change menu and playback mode
	.LGesture_Menu:
		.byte  GFXBG_MAINWINDOW_MENU_X0 @ BBox
		.byte  GFXBG_MAINWINDOW_MENU_X1-1
		.byte  GFXBG_MAINWINDOW_MENU_Y0
		.byte  GFXBG_MAINWINDOW_MENU_Y1-1
		.hword 0x01           @ Flags     = AllowMoveX
		.hword 1              @ Priority  = 1
		.hword MSEC2TICK(50)  @ TapTicks  = 50ms
		.hword MSEC2TICK(500) @ HoldTicks = 500ms
		.word  Main_State     @ Userdata  = &State
		.word  0,0            @ Prev,Next = NULL
		.word  Gesture_MenuScroll_Touch   @ TouchCb
		.word  Gesture_Menu_Tap           @ TapCb
		.word  0                          @ DragCb
		.word  Gesture_MenuScroll_Release @ ReleaseCb
.LGestures_End:

ASM_DATA_END(Main_GestureList)

/**************************************/

ASM_FUNC_BEG(Gesture_MenuScroll_Touch, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0: x
@ r1: y
@ r2: Dx
@ r3: Dy

Gesture_MenuScroll_Touch:
	LDR	r0, =Main_State
	LDR	r3, =SCROLLOFFS_END
	LDRH	r1, [r0, #0x0A] @ MenuScrollTarget -= Dx
	SUB	r1, r2
	ASR	r2, r1, #0x1F
	BIC	r1, r2
	CMP	r1, r3
	BCC	0f
	MOV	r1, r3
0:	STRH	r1, [r0, #0x0A]
	BX	lr

ASM_FUNC_END(Gesture_MenuScroll_Touch)

/**************************************/

ASM_FUNC_BEG(Gesture_MenuScroll_Release, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0:  x
@ r1:  y
@ r2: &State

Gesture_MenuScroll_Release:
	LDRH	r0, [r2, #0x08] @ Snap MenuScrollTarget to target window
	LDRH	r1, [r2, #0x0A]
	CMP	r1, r0
	BCC	1f
	BEQ	0f              @ If not moving, snap to closest
	ADD	r1, #0x7F
0:	ADD	r1, #0x80
1:	LSR	r1, #0x08
	LSL	r1, #0x08
	STRH	r1, [r2, #0x0A]
	BX	lr

ASM_FUNC_END(Gesture_MenuScroll_Release)

/**************************************/

ASM_FUNC_BEG(Gesture_Menu_Tap, ASM_MODE_ARM;ASM_SECTION_TEXT)

@ r0:  x
@ r1:  y
@ r2: &State

Gesture_Menu_Tap:
.LMenu_Tap_Songs:
.if GFXBG_MAINWINDOW_MENU_SONGS_X0 != 0
	CMP	r0, #GFXBG_MAINWINDOW_MENU_SONGS_X0
	BCC	.LMenu_Tap_Exit
.endif
	CMP	r0, #GFXBG_MAINWINDOW_MENU_SONGS_X1
	BCS	.LMenu_Tap_Artists
0:	LDR	r0, =SCROLLOFFS_SONGS
	B	.LMenu_Tap_SetScrollTarget

.LMenu_Tap_Artists:
.if GFXBG_MAINWINDOW_MENU_ARTISTS_X0 != GFXBG_MAINWINDOW_MENU_SONGS_X1
	CMP	r0, #GFXBG_MAINWINDOW_MENU_ARTISTS_X0
	BCC	.LMenu_Tap_Exit
.endif
	CMP	r0, #GFXBG_MAINWINDOW_MENU_ARTISTS_X1
	BCS	.LMenu_Tap_Playing
0:	LDR	r0, =SCROLLOFFS_ARTISTS
	B	.LMenu_Tap_SetScrollTarget

.LMenu_Tap_Playing:
.if GFXBG_MAINWINDOW_MENU_PLAYING_X0 != GFXBG_MAINWINDOW_MENU_ARTISTS_X1
	CMP	r0, #GFXBG_MAINWINDOW_MENU_PLAYING_X0
	BCC	.LMenu_Tap_Exit
.endif
	CMP	r0, #GFXBG_MAINWINDOW_MENU_PLAYING_X1
	BCS	.LMenu_Tap_Shuffle
0:	LDR	r0, =SCROLLOFFS_PLAYING
	@B	.LMenu_Tap_SetScrollTarget

.LMenu_Tap_SetScrollTarget:
	STRH	r0, [r2, #0x0A]

.LMenu_Tap_Exit:
	BX	lr

.LMenu_Tap_Shuffle:
.if GFXOBJ_MAINWINDOW_MENU_SHUFFLE_X0 != GFXBG_MAINWINDOW_MENU_PLAYING_X1
	CMP	r0, #GFXOBJ_MAINWINDOW_MENU_SHUFFLE_X0
	BCC	.LMenu_Tap_Exit
.endif
	CMP	r0, #GFXOBJ_MAINWINDOW_MENU_SHUFFLE_X1
	BCS	.LMenu_Tap_Repeat
1:	LDRB	r0, [r2, #0x0D] @ Shuffle ^= 1
	MOV	r1, #0x01
	EOR	r0, r1
	STRB	r0, [r2, #0x0D]
	BX	lr

.LMenu_Tap_Repeat:
.if GFXOBJ_MAINWINDOW_MENU_REPEAT_X0 != GFXOBJ_MAINWINDOW_MENU_SHUFFLE_X1
	CMP	r0, #GFXOBJ_MAINWINDOW_MENU_REPEAT_X0
	BCC	.LMenu_Tap_Exit
.endif
	CMP	r0, #GFXOBJ_MAINWINDOW_MENU_REPEAT_X1
	BCS	.LMenu_Tap_Exit
1:	LDRB	r0, [r2, #0x0D] @ RepeatMode = Wrap(RepeatMode+1)
	ADD	r0, #0x01<<1
	CMP	r0, #0x03<<1
	BCC	0f
	SUB	r0, #0x03<<1
0:	STRB	r0, [r2, #0x0D]
	BX	lr

ASM_FUNC_END(Gesture_Menu_Tap)

/**************************************/

ASM_FUNC_BEG(Gesture_Playlist_Touch, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0: x
@ r1: y
@ r2: Dx
@ r3: Dy

Gesture_Playlist_Touch:
	LDR	r0, =Main_State
	LDRH	r1, [r0, #0x08]       @ ScreenIdx = MenuScrollPos/256?
	LSR	r1, #0x08
	CMP	r1, #0x01
	BHI	1f                    @ Early exit when not in a playlist
0:	LDR	r0, =Gfx_State_SongsWindow
	BNE	0f
	LDR	r0, =Gfx_State_ArtistsWindow
0:	NEG	r3, r3
	LSL	r3, #0x08
	STR	r3, [r0, #0x04]       @ VScrollRate = -TouchDeltaY
1:	BX	lr

ASM_FUNC_END(Gesture_Playlist_Touch)

/**************************************/

ASM_FUNC_BEG(Gesture_Playlist_Tap, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0: x
@ r1: y
@ r2: &State

Gesture_Playlist_Tap:
	PUSH	{r4-r6,lr}
0:	LDRH	r6, [r2, #0x08]     @ ScreenIdx = MenuScrollPos/256 -> r6?
	LSR	r6, #0x08
	CMP	r6, #0x01
	BHI	.LPlaylist_Tap_Exit @ Early exit when not in a playlist
0:	LDR	r4, =Gfx_State_SongsWindow
	LDRH	r5, [r2, #0x10]     @ nItems -> r5
	BNE	1f
	LDR	r4, =Gfx_State_ArtistsWindow
	LDRH	r5, [r2, #0x12]
1:	LDR	r0, [r4, #0x00]     @ VScroll -> r0
	SUB	r1, #GFXBG_PLAYLIST_ITEM_Y0
	LSR	r0, #0x08
	ADD	r0, r1              @ TouchItem = (VScroll + TouchY) / SPACING
.if GFXBG_PLAYLIST_TRACK_SPACING_RECP != 1
	BLX	.LPlaylist_Tap_GetTouchItemFromYPos
.else
	LSR	r0, #GFXBG_PLAYLIST_TRACK_SPACING_RECPBITS
.endif
	CMP	r0, r5              @ Check TouchItem is in range
	BCS	.LPlaylist_Tap_Exit
2:	LSL	r6, #0x0F           @ Play(TouchItem | 8000h*IsArtistsWindow)
	ORR	r0, r6
	BL	Main_PlayTrack

.LPlaylist_Tap_Exit:
	POP	{r4-r6,pc}

.if GFXBG_PLAYLIST_TRACK_SPACING_RECP != 1

@ r0: YPos (becomes TouchItem)

ASM_MODE_ARM

.LPlaylist_Tap_GetTouchItemFromYPos:
	LDR	r1, =GFXBG_PLAYLIST_TRACK_SPACING_RECP
	UMULL	r2, r3, r1, r0
	MOV	r0, r3, lsr #GFXBG_PLAYLIST_TRACK_SPACING_RECPBITS-32
	BX	lr

.endif

ASM_FUNC_END(Gesture_Playlist_Tap)

/**************************************/
//! EOF
/**************************************/
