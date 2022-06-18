/**************************************/
#include "AsmMacros.h"
#include "NK_Tick.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

//! Set to 0 to skip the splash screen
//! This may cause the screen to stay white for
//! a bit while scanning for music, however.
.equ USE_SPLASH_SCREEN, 1

/**************************************/

//! Song to automatically play on startup
.equ STARTUP_TRACK, 0 | 0x8000*0 @ First track in the Songs listings

//! Minimum display time for the splash screen
//! NOTE: This includes the fade-in time, but NOT the fade-out time
.equ MIN_SPLASH_DISPLAY_TICKS, ((33534207 * 5/2 - 1) / NK_TICK_CYCLES_PER_TICK + 1) @ 2.5 seconds

//! Step value for MASTER_BRIGHT during splash window fade-in/out (0.32fxp, added per frame)
.equ SPLASHVBLANK_FADEIN_ALPHA_STEP, 143581725 //! Ceil[2^32 / (59.8261 * nSecs(=0.5))]
.equ SPLASHVBLANK_FADEOUT_ALPHA_STEP, 71790863 //! Ceil[2^32 / (59.8261 * nSecs(=1.0))]

//! Step value for MASTER_BRIGHT during initial fade-in (0.32fxp, added per frame)
.equ MAINVBLANK_FADEIN_ALPHA_STEP, 143581725 //! Ceil[2^32 / (59.8261 * nSecs(=0.5))]

/**************************************/

ASM_FUNC_GLOBAL(Main_Startup)
ASM_FUNC_BEG   (Main_Startup, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Main_Startup:
	PUSH	{r4-r6,lr}
0:	BL	ulc_Init                     @ Init ulc
.if USE_SPLASH_SCREEN
0:	BL	.LLoadSplashScreen
	MOV	r0, #0x01<<0                 @ Set VBlank interrupt
	LDR	r1, =.LSplash_VBlankIRQ_FadeIn+1
	BL	irqSet
	MOV	r0, #0x01<<0                 @ Enable VBlank interrupt
	BL	irqEnable
0:	LDR	r4, =MIN_SPLASH_DISPLAY_TICKS
	BL	NK_Tick_Poll
	ADD	r4, r0                       @ LoadingEndTick -> r4
.endif
	LDR	r0, =N_INBUILT_TRACKS        @ Populate available tracks
	LDR	r1, =MAX_TRACKS
	BL	TrackListing_Populate        @ nListings_Songs|nListings_Artists<<16 -> r5
.if USE_SPLASH_SCREEN
	MOV	r5, r0
0:	SWI	0x05                         @ VBlankIntrWait
	BL	NK_Tick_Poll                 @ Wait for minimum loading time
	SUB	r0, r4
	BMI	0b
0:	LDR	r4, =Main_State
	STR	r5, [r4, #0x04]              @ Init Xorshift seed (anything non-zero will work)
	STR	r5, [r4, #0x10]              @ Store nListings (this causes the loading screen to start fading out)
	SWI	0x05                         @ <- This is needed for no$ because the interrupt is delayed :/
0:	SWI	0x05
	LDR	r0, [r4, #0x00]              @ Wait for fade to end
	CMP	r0, #0x00
	BNE	0b
.else
	LDR	r4, =Main_State
	STR	r0, [r4, #0x10]
.endif
0:	BL	Gfx_LoadGraphics             @ Load main graphics
	MOV	r0, #0x01<<0                 @ Set VBlank interrupt
	LDR	r1, =.LStartup_VBlankIRQ_FadeIn
	BL	irqSet
.if !USE_SPLASH_SCREEN
	MOV	r0, #0x01<<0                 @ Enable VBlank interrupt
	BL	irqEnable
.endif
	LDR	r0, =STARTUP_TRACK           @ Begin playing startup song
	BL	Main_PlayTrack
1:	BL	TouchGesture_Init            @ Install gestures
	LDR	r4, =Main_GestureList
	LDMIA	r4!, {r5}
10:	MOV	r0, r4
	BL	TouchGesture_Attach
	ADD	r4, #0x28
	SUB	r5, #0x01
	BNE	10b
0:	POP	{r4-r6,pc}

/**************************************/
.if USE_SPLASH_SCREEN
/**************************************/

.LLoadSplashScreen:
	PUSH	{r4,lr}

.LLoadSplashScreen_InitHW:
	LDR	r0, =0x0003                  @ LCDA_2D
	LDR	r3, =0x04000304              @ &POWCNT1 -> r3
	LDR	r2, =0x04000240              @ Init VRAMCNT (VRAM_A = BG_A)
	STR	r0, [r3]
	MOV	r0, #0x81
	STRB	r0, [r2, #0x00]
	MOV	r4, #0x04                    @ &REG_DISPCNT_A -> r4
	LSL	r4, #0x18
0:	LDR	r0, =0<<2 | 1<<7 | 31<<8     @ Init BG0CNT_A = CHARMAP(0) | 8BPP | TILEMAP(31), BG0HOFS_A = 0, BG0VOFS_A = 0
	MOV	r1, #0x00
	STRH	r0, [r4, #0x08]
	STR	r1, [r4, #0x10]

.LLoadSplashScreen_LoadData:
0:	LDR	r1, =GfxBg_SplashScreen_Gfx  @ Load tiles
	LDR	r0, =BGTILEPXADR8_A(0, 0)
	BL	UnLZSS
	LDR	r1, =GfxBg_SplashScreen_Map  @ Load tilemap
	LDR	r0, =BGTILEMAPADR_A(31)
	BL	UnLZSS
	LDR	r0, =0x05000000              @ Load palette
	LDR	r1, =GfxBg_SplashScreen_Pal
	LDR	r2, =0x02 * 64
	BL	memcpy

.LLoadSplashScreen_Exit:
	POP	{r4,pc}

/**************************************/

.LSplash_VBlankIRQ_FadeIn:
	PUSH	{r4,lr}
	LDR	r4, =Main_State
	LDR	r1, =SPLASHVBLANK_FADEIN_ALPHA_STEP
	LDR	r0, [r4, #0x00]     @ FadeInAlpha -> r0
	MOV	r2, #0x04           @ REG_DISPCNT_A -> r2
	LSL	r2, #0x18
	LDR	r3, =0x00010100     @ DISPCNT_A = MODE(0) | BG0 | DISPMODE(1)
	ADD	r0, r1              @ Increase alpha?
	STR	r3, [r2, #0x00]
	BCS	1f
0:	STR	r0, [r4, #0x00]     @ Not overflowed: Set MASTER_BRIGHT_A = (16-Alpha) | MASTER_BRIGHT_UP
	LSR	r0, #0x20-4
	SUB	r0, #0x10
	NEG	r0, r0
	MOV	r1, #0x40
	LSL	r1, #0x08
	ORR	r0, r1
	STR	r0, [r2, #0x6C]
	POP	{r4,pc}
1:	MOV	r0, #0x00           @ Overflowed: Set MASTER_BRIGHT_A/B = 0
	STR	r0, [r2, #0x6C]
	STR	r0, [r4, #0x00]     @ Reset FadeInAlpha=0
	MOV	r0, #0x01<<0        @ Set new interrupt point
	LDR	r1, =.LSplash_VBlankIRQ_WaitForListings+1
	BL	irqSet
	POP	{r4,pc}

.LSplash_VBlankIRQ_WaitForListings:
	LDR	r0, =Main_State
	LDR	r0, [r0, #0x10]     @ Check for nListings
	CMP	r0, #0x00
	BNE	0f
.Lbxlr:	BX	lr
0:	PUSH	{r4,lr}
	MOV	r0, #0x01<<0        @ Set new interrupt point
	LDR	r1, =.LSplash_VBlankIRQ_FadeOut+1
	BL	irqSet
	POP	{r4,pc}

.LSplash_VBlankIRQ_FadeOut:
	LDR	r3, =Main_State
	LDR	r1, =SPLASHVBLANK_FADEOUT_ALPHA_STEP
	LDR	r0, [r3, #0x00]     @ FadeInAlpha -> r0
	MOV	r2, #0x04           @ REG_DISPCNT_A -> r2
	LSL	r2, #0x18
	ADD	r0, r1              @ Increase alpha?
	BCS	1f
0:	STR	r0, [r3, #0x00]     @ Not overflowed: Set MASTER_BRIGHT_A = Alpha | MASTER_BRIGHT_UP
	LSR	r0, #0x20-4
	MOV	r1, #0x40
	LSL	r1, #0x08
	ORR	r0, r1
	STR	r0, [r2, #0x6C]
	BX	lr
1:	LDR	r0, =0x10 | 0x4000  @ Overflowed: Set MASTER_BRIGHT_A = Alpha=1.0 | MASTER_BRIGHT_UP
	MOV	r1, #0x00
	STR	r0, [r2, #0x6C]
	STR	r1, [r3, #0x00]     @ Reset FadeInAlpha=0
	PUSH	{r4,lr}
	MOV	r0, #0x01<<0        @ Set new interrupt point
	LDR	r1, =.Lbxlr+1
	BL	irqSet
	POP	{r4,pc}

/**************************************/

ASM_MODE_ARM

.LStartup_VBlankIRQ_FadeIn:
	LDR	ip, =Main_State
	LDR	r1, =MAINVBLANK_FADEIN_ALPHA_STEP
	LDR	r0, [ip, #0x00]     @ FadeInAlpha -> r0
	MOV	r2, #0x04000000     @ REG_DISPCNT_A -> r2
	ADD	r3, r2, #0x1000     @ REG_DISPCNT_B -> r3
	ADDS	r0, r0, r1          @ Increase alpha?
	STR	r0, [ip, #0x00]
	MOV	r0, r0, lsr #0x20-4 @ Not overflowed: Set MASTER_BRIGHT_A/B = (16-Alpha) | MASTER_BRIGHT_UP, Overflowed: Set MASTER_BRIGHT_A/B = 0
	RSBCC	r0, r0, #0x10
	ORRCC	r0, r0, #0x4000
	STR	r0, [r2, #0x6C]
	STR	r0, [r3, #0x6C]
	BCC	Gfx_UpdateGraphics
1:	STR	lr, [sp, #-0x08]!
	MOV	r0, #0x01<<0        @ Re-set VBlank interrupt to the "main" code to skip over the fade-in stuff
	LDR	r1, =Gfx_UpdateGraphics
	BL	irqSet
	LDR	lr, [sp], #0x08
	B	Gfx_UpdateGraphics
	
/**************************************/
.endif	
/**************************************/
	
ASM_FUNC_END(Main_Startup)

/**************************************/
//! EOF
/**************************************/
