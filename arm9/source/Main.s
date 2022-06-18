/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

ASM_FUNC_GLOBAL(main)
ASM_FUNC_BEG   (main, ASM_MODE_THUMB;ASM_SECTION_TEXT)

main:
	@PUSH	{r4,lr}
	BLX	.Lmain_CleanAllCache @ <- This is because some flashcart firmwares skip this :/
	BL	NK_Tick_Init
	BL	fatInitDefault
0:	BL	Main_Startup
0:	BL	.Lmain_UpdateInput   @ Do updates
	BL	ulc_Update
	SWI	0x06                 @ Halt()
	B	0b
0:	@POP	{r4,pc}

/**************************************/

.Lmain_UpdateInput:
	PUSH	{r4-r6,lr}
	LDR	r4, =Main_State
	BL	scanKeys
	BL	TouchGesture_Update
	BL	keysDown
	MOV	r5, r0
	BL	keysCurrent
	MOV	r6, r0
1:	LSR	r0, r5, #0x09+1      @ KEY_L?
	BCC	1f
	LSR	r0, r6, #0x02+1      @ KEY_L + KEY_SELECT = Previous song
	BCS	11f
10:	LDRH	r0, [r4, #0x08]      @  MenuScrollTarget = (MenuScrollPos/SCREEN_WIDTH-1)*SCREEN_WIDTH
	LSR	r0, #0x08
	SUB	r0, #0x01
	ASR	r1, r0, #0x1F
	BIC	r0, r1
	LSL	r0, #0x08
	STRH	r0, [r4, #0x0A]
	B	2f
11:	MOV	r0, #0x01            @  SeekTrack(IgnorePlaybackMode=TRUE, Delta=-1)
	NEG	r1, r0
	BL	Main_SeekTrack
	B	2f
1:	LSR	r0, r5, #0x08+1      @ KEY_R?
	BCC	1f
	LSR	r0, r6, #0x02+1      @  KEY_R + KEY_SELECT = Next song
	BCS	11f
10:	LDRH	r0, [r4, #0x08]      @  MenuScrollTarget = (MenuScrollPos/SCREEN_WIDTH+1)*SCREEN_WIDTH
	LSR	r0, #0x08
	ADD	r0, #0x01
	CMP	r0, #SCROLLOFFS_END/256
	BCC	0f
	MOV	r0, #SCROLLOFFS_END/256
0:	LSL	r0, #0x08
	STRH	r0, [r4, #0x0A]
	B	2f
11:	MOV	r0, #0x01            @  SeekTrack(IgnorePlaybackMode=TRUE, Delta=+1)
	MOV	r1, r0
	BL	Main_SeekTrack
	B	2f
1:	LSR	r0, r5, #0x00+1      @ KEY_A?
	BCC	1f
10:	MOV	r0, #0x20            @  Unpause
	ADD	r0, r4
	BL	ulc_Unpause
	B	2f
1:	LSR	r0, r5, #0x01+1      @ KEY_B?
	BCC	1f
10:	MOV	r0, #0x20            @  Pause
	ADD	r0, r4
	BL	ulc_Pause
	@B	2f
1:	
2:

.Lmain_UpdateInput_Exit:
	POP	{r4-r6,pc}

/**************************************/

ASM_MODE_ARM

@ Slightly optimized version of the example code on the ARM documentation
.Lmain_CleanAllCache:
	MOV	r0, #0x00           @ Segment -> r0
1:	MOV	r1, r0              @ Segment | Line
2:	MCR	p15,0,r1,c7,c10,2   @ DC_CleanLineSI()
	ADD	r1, r1, #0x20       @ Next line, and check for end of segment
	MOVS	ip, r1, lsl #0x20-10
	BNE	2b
	ADDS	r0, r0, #0x40000000 @ Next segment?
	BCC	1b
3:	BX	lr

ASM_FUNC_END(main)

/**************************************/
//! EOF
/**************************************/
