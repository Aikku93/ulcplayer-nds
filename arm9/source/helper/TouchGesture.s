/**************************************/
#include "AsmMacros.h"
/**************************************/

//! Radius (squared) of the deadzone for Dx and Dy
//! If this is too low, touch jitter can result in bizarre
//! subtle movements, but if too high, sensitivity at small
//! movements will be deadened.
.equ DEADZONE_RADIUS2, 9 @ 3.0px

/**************************************/

ASM_DATA_BEG(TouchGesture_State, ASM_SECTION_BSS;ASM_ALIGN(4))

TouchGesture_State:
	.word  0 @ [00h] ActiveTouchHandler
	.hword 0 @ [04h] TouchX | HasMoved<<15 (if TouchXY == FFFFFFFFh, screen has not been touched yet)
	.hword 0 @ [06h] TouchY | DragMode<<15
	.word  0 @ [08h] TouchFirstTick
	.word  0 @ [0Ch] GestureHandlers

ASM_DATA_END(TouchGesture_State)

/**************************************/

ASM_FUNC_GLOBAL(TouchGesture_Init)
ASM_FUNC_BEG   (TouchGesture_Init, ASM_MODE_THUMB;ASM_SECTION_TEXT)

TouchGesture_Init:
	LDR	r0, =TouchGesture_State
	MOV	r2, #0x00
	MVN	r3, r2
	STR	r2, [r0, #0x00] @ ActiveTouchHandler=NULL
	STR	r3, [r0, #0x04] @ TouchXY = UNTOUCHED
	@STR	r2, [r0, #0x08] @ TouchFirstTick = 0 (not needed)
	STR	r2, [r0, #0x0C] @ GestureHandlers = NULL
	BX	lr

ASM_FUNC_END(TouchGesture_Init)

/**************************************/

ASM_FUNC_GLOBAL(TouchGesture_Attach)
ASM_FUNC_BEG   (TouchGesture_Attach, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0: &GestureHandler

TouchGesture_Attach:
	PUSH	{r3-r5,lr}
	LDR	r1, =TouchGesture_State
	MOV	r2, #0x00       @ Prev = NULL
	LDR	r3, [r1, #0x0C] @ Next = GestureHandlers.Head
	LDRH	r4, [r0, #0x06] @ Handler.Priority -> r4
1:	CMP	r3, #0x00       @ Next == NULL?
	BEQ	1f              @  Y: Insert here
	LDRH	r5, [r3, #0x06] @ Next.Priority -> r5
	CMP	r4, r5          @ if(Handler.Priority > Next.Priority)
	BHI	1f              @  Y: Insert here
	MOV	r2, r3          @ Prev = Next
	LDR	r3, [r3, #0x14] @ Next = Next.Next
	B	1b
1:	CMP	r2, #0x00       @ Prev == NULL?
	BEQ	11f
10:	STR	r0, [r2, #0x14] @  N: Prev.Next = Handler
	B	1f
11:	STR	r0, [r1, #0x0C] @  Y: GestureHandlers.Head = Handler
1:	CMP	r3, #0x00       @ Next == NULL?
	BEQ	1f
10:	STR	r0, [r3, #0x10] @  N: Next.Prev = Handler
1:	ADD	r0, #0x10       @ Handler.{Prev,Next} = {Prev,Next}
	STMIA	r0!, {r2-r3}
	POP	{r3-r5,pc}

ASM_FUNC_END(TouchGesture_Attach)

/**************************************/

ASM_FUNC_GLOBAL(TouchGesture_Detach)
ASM_FUNC_BEG   (TouchGesture_Detach, ASM_MODE_THUMB;ASM_SECTION_TEXT)

@ r0: &GestureHandler

TouchGesture_Detach:
	LDR	r1, =TouchGesture_State
	ADD	r0, #0x10
	LDMIA	r0!, {r2-r3}    @ Prev,Next -> r2,r3
1:	CMP	r2, #0x00       @ Prev == NULL?
	BEQ	11f
10:	STR	r3, [r2, #0x14] @  N: Prev.Next = Next
	B	1f
11:	STR	r3, [r1, #0x0C] @  Y: GestureHandlers.Head = Next
1:	CMP	r3, #0x00       @ Next == NULL?
	BEQ	1f
10:	STR	r2, [r3, #0x10] @  N: Next.Prev = Prev
1:	BX	lr

ASM_FUNC_END(TouchGesture_Detach)

/**************************************/

ASM_FUNC_GLOBAL(TouchGesture_Update)
ASM_FUNC_BEG   (TouchGesture_Update, ASM_MODE_THUMB;ASM_SECTION_TEXT)

TouchGesture_Update:
	PUSH	{r3-r7,lr}
	LDR	r4, =TouchGesture_State
0:	BL	keysCurrent
	LSR	r0, #0x0C+1     @ KEY_TOUCH?
	BCS	.LHandleTouchHold

/**************************************/

.LHandleTouchRelease:
	LDR	r7, [r4, #0x04] @ TouchXY -> r7
	LDR	r6, [r4, #0x00] @ ActiveTouchHandler -> r6
	ADD	r1, r7, #0x01   @ if(TouchXY == UNTOUCHED) Early exit
	BEQ	.LHandleTouchRelease_Exit
	CMP	r6, #0x00       @ Unhandled Touch event: Early exit
	BEQ	.LHandleTouchRelease_Exit
1:	LDR	r3, [r6, #0x24] @ if(HasMoved || DragMode || HoldTime < TapTicks) Release(); else Tap();
	LSL	r2, r7, #0x10
	ORR	r2, r7
	BMI	0f
	BL	NK_Tick_Poll
	LDR	r2, [r4, #0x08] @ TouchFirstTick -> r2
	LDRH	r1, [r6, #0x08] @ TapTicks -> r1
	SUB	r0, r2          @ HoldTime = Tick() - TouchFirstTick -> r2
	CMP	r0, r1          @ HoldTime >= TapTicks? Tap();
	BCC	0f
	LDR	r3, [r6, #0x1C]
0:	LDR	r2, [r6, #0x0C] @ Userdata -> r2
	BIC	r7, r5          @ [clear HasMoved flags]
	LSR	r1, r7, #0x10   @ TouchX -> r0, TouchY -> r1
	LSL	r0, r7, #0x10
	LSR	r0, #0x10
	CMP	r3, #0x00
	BEQ	.LHandleTouchRelease_Exit
	BLX	r3

.LHandleTouchRelease_Exit:
	MOV	r0, #0x00       @ Clear ActiveTouchHandler=NULL, TouchXY = UNTOUCHED and exit
	MVN	r1, r0
	STMIA	r4!, {r0-r1}
	POP	{r3-r7,pc}

/**************************************/

.LHandleTouchHold:
	SUB	sp, #0x10       @ Read TouchXY
	MOV	r0, sp
	BL	touchRead
	LDR	r0, [sp, #0x04] @ NewTouchXY -> r0
	LDR	r6, [r4, #0x00] @ ActiveTouchHandler -> r6
	LDR	r5, [r4, #0x04] @ OldTouchXY -> r5 == UNTOUCHED? (ie. first Touch event)
	ADD	sp, #0x10
	ADD	r1, r5, #0x01
	BEQ	.LHandleFirstTouch
0:	CMP	r6, #0x00       @ Unhandled Touch event?
	BEQ	.LHandleTouchHold_Exit
	LDR	r2, =0x7FFF7FFF @ InvFlagsMask = ~(HasMovedMask|DragModeMask) -> r2
	LSR	r1, r0, #0x10   @ NewTouchY -> r1
	LSL	r0, #0x10       @ NewTouchX -> r0
	LSR	r0, #0x10
	AND	r2, r5
	BIC	r5, r2          @ Flags -> r5
	LSR	r3, r2, #0x10   @ OldTouchY -> r3
	LSL	r2, #0x10       @ OldTouchX -> r2
	LSR	r2, #0x10
	SUB	r2, r0, r2      @ Dx -> r2
	SUB	r3, r1, r3      @ Dy -> r3
.if DEADZONE_RADIUS2 > 0
	PUSH	{r2-r3}
	MUL	r2, r2
	MUL	r3, r3
	ADD	r2, r3
	CMP	r2, #DEADZONE_RADIUS2
	POP	{r2-r3}
	BHI	0f
	SUB	r0, r2
	SUB	r1, r3
	MOV	r2, #0x00
	MOV	r3, #0x00
.endif
0:	LSR	r7, r5, #0x0F+1 @ Movement is already locked to this handler?
	BCC	.LHandleTouchHold_ValidateMovement

.LHandleTouchHold_MovementValidated:
.LHandleTouchHold_UpdateMovement:
	MOV	r7, #0x01       @ Flags |= HasMoved*(Dx != 0) | HasMoved*(Dy != 0)
	LSL	r7, #0x0F
	CMP	r2, #0x00
	BNE	0f
	CMP	r3, #0x00
	BNE	0f
	MOV	r7, #0x00
0:	ORR	r5, r7
1:	PUSH	{r0-r3}
	BL	NK_Tick_Poll
	LDR	r2, [r4, #0x08] @ TouchFirstTick -> r2
	LDRH	r3, [r6, #0x0A] @ HoldTicks -> r3
	SUB	r0, r2          @ DeltaTicks = Tick() - TouchFirstTick -> r0
	CMP	r0, r3          @ DeltaTicks >= HoldTicks?
	POP	{r0-r3}
	BCC	2f
1:	LSR	r7, r5, #0x0F+1 @  if(!HasMoved) DragMode = TRUE
	SBC	r7, r7
	LSL	r7, #0x1F
	ORR	r5, r7
2:	ORR	r5, r0          @ Store TouchXY = NewTouchXY | Flags
	LSL	r7, r1, #0x10
	ORR	r5, r7
	STR	r5, [r4, #0x04]
3:	LDR	r7, [r6, #0x18] @ if(DragMode) Drag(); else Touch();
	LSR	r5, #0x1F+1
	BCC	0f
	LDR	r7, [r6, #0x20]
	CMP	r7, #0x00       @ if(!DragCb) Touch();
	BNE	0f
	LDR	r7, [r6, #0x18]
0:	LDR	r6, [r6, #0x0C] @ Userdata -> r6
	CMP	r7, #0x00       @ CbFunc?
	BEQ	.LHandleTouchHold_Exit
	STR	r6, [sp, #0x00] @ Pass Userdata in stack (r3 was pushed as dummy/alignment in prologue
	BLX	r7              @ so we can just store this value directly to the stack without pushing)

.LHandleTouchHold_Exit:
	POP	{r3-r7,pc}

.LHandleFirstTouch:
	STR	r0, [r4, #0x04] @ TouchXY = NewTouchXY | HasMoved=FALSE | DragMode=FALSE
	MOV	r6, r0          @ Stash NewTouchXY -> r6
0:	LSR	r1, r0, #0x10   @ Get Handler for this TouchXY -> r5?
	LSL	r0, #0x10
	LSR	r0, #0x10
	MOV	r2, #0x00
	BL	.LGetEventHandler
	MOV	r5, r0
	BEQ	2f
0:	STR	r5, [r4, #0x00] @ ActiveTouchHandler = Handler
	BL	NK_Tick_Poll    @ TouchFirstTick = GetTick()
	STR	r0, [r4, #0x08]
0:	LDR	r7, [r5, #0x18] @ TouchCb -> r7
	LDR	r3, [r5, #0x0C] @ Userdata -> r3
	CMP	r7, #0x00
	BEQ	2f
	STR	r3, [sp, #0x00] @ Pass Userdata in stack (r3 was pushed as dummy/alignment in prologue
	MOV	r2, #0x00       @ TouchCb expects Dx,Dy, so pass {0,0}
	MOV	r3, #0x00
	LSL	r0, r6, #0x10   @ TouchX -> r0, TouchY -> r1
	LSR	r0, #0x10
	LSR	r1, r6, #0x10
	BLX	r7
2:	POP	{r3-r7,pc}

.LHandleTouchHold_ValidateMovement:
	PUSH	{r2-r3}
	ASR	r7, r2, #0x1F   @ ABS(Dx) -> r2
	EOR	r2, r7
	SUB	r2, r7
	ASR	r7, r3, #0x1F   @ ABS(Dy) -> r3
	EOR	r3, r7
	SUB	r3, r7
0:	LDRH	r7, [r6, #0x04] @ Handler.Flags -> r7
	LSL	r5, r3, #0x01   @ if(!AllowMoveX && ABS(Dx) >= 2*ABS(Dy)) TryNewHandler(OldTouchXY)
	CMP	r2, r5
	BCC	1f
	LSR	r5, r7, #0x00+1
	BCS	1f
	PUSH	{r0-r3}
	LDR	r2, [sp, #0x10]
	LDR	r3, [sp, #0x14]
	SUB	r0, r2
	SUB	r1, r3
	MOV	r2, r6
	BL	.LGetEventHandler
	MOV	ip, r0
	CMP	r0, #0x00
	POP	{r0-r3}
	BEQ	0f
	MOV	r6, ip          @ Set new handler and try again
	B	0b
0:	LDR	r6, [r4, #0x00] @ Reset handler to what we started with
1:	LDRH	r7, [r6, #0x04] @ Handler.Flags -> r7
	LSL	r5, r2, #0x01   @ if(!AllowMoveY && ABS(Dy) >= 2*ABS(Dx)) TryNewHandler(OldTouchXY)
	CMP	r3, r5
	BCC	2f
	LSR	r5, r7, #0x01+1
	BCS	2f
	PUSH	{r0-r3}
	LDR	r2, [sp, #0x10]
	LDR	r3, [sp, #0x14]
	SUB	r0, r2
	SUB	r1, r3
	MOV	r2, r6
	BL	.LGetEventHandler
	MOV	ip, r0
	CMP	r0, #0x00
	POP	{r0-r3}
	BEQ	0f
	MOV	r6, ip          @ Set new handler and try again
	B	1b
0:	LDR	r6, [r4, #0x00] @ Reset handler to what we started with
2:	STR	r6, [r4, #0x00] @ Update handler if needed
	POP	{r2-r3}         @ Restore Dx,Dy
	B	.LHandleTouchHold_MovementValidated

/**************************************/

@ r0:  TouchX
@ r1:  TouchY
@ r2: &PrevHandler (NULL = Search from the start)
@ r3:
@ r4: &TouchGesture_State
@ Destroys r2,r3

.LGetEventHandler:
	PUSH	{r4-r5}
	CMP	r2, #0x00       @ if(!PrevHandler) PrevHandler = FirstHandler
	BNE	1f
	LDR	r2, [r4, #0x0C]
	CMP	r2, #0x00
	BNE	2f
	B	3f              @ No handlers - return NULL
1:	LDR	r2, [r2, #0x14] @ Handler = Handler.Next?
	CMP	r2, #0x00
	BEQ	3f
2:	LDRH	r5, [r2, #0x04] @ Handler.Flags -> r5
	LDRB	r3, [r2, #0x00]
	LDRB	r4, [r2, #0x01]
	LSR	r5, #0x02+1     @ Bounding circle check?
	BCS	21f
20:	@LDRB	r3, [r2, #0x00] @ Check bounding box
	@LDRB	r4, [r2, #0x01]
	CMP	r0, r3
	BCC	1b
	CMP	r0, r4
	BHI	1b
	LDRB	r3, [r2, #0x02]
	LDRB	r4, [r2, #0x03]
	CMP	r1, r3
	BCC	1b
	CMP	r1, r4
	BLS	3f
	B	1b
21:	@LDRB	r3, [r2, #0x00] @ Check bounding circle
	@LDRB	r4, [r2, #0x01] @ (TouchX - CenterX)^2 + (TouchY - CenterY)^2 < Radius^2?
	LDRH	r5, [r2, #0x02]
	SUB	r3, r0
	SUB	r4, r1
	MUL	r3, r3
	MUL	r4, r4
	ADD	r3, r4
	CMP	r3, r5
	BHI	1b
3:	MOV	r0, r2          @ Return Handler
	POP	{r4-r5}
	BX	lr

/**************************************/

ASM_FUNC_END(TouchGesture_Update)

/**************************************/
//! EOF
/**************************************/
