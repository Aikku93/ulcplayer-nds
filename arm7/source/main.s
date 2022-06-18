/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulcPlayer.h"
/**************************************/

@ Allow some underrun buffering
.equ CAPTURE_BUFFERSIZE, (CAPTURE_SIZE+512)

/**************************************/

ASM_FUNC_GLOBAL(main)
ASM_FUNC_BEG   (main, ASM_MODE_THUMB;ASM_SECTION_TEXT)

main:
	BL	irqInit
	BL	fifoInit
	BL	touchInit
0:	BL	NK_Tick_Init @ This is supposed to happen inside crt0, but eh...
	BL	NK_Timer_Init
	LDR	r0, =1<<0    @ Update input on VBlank
	LDR	r1, =inputGetAndSend
	BL	irqSet
	LDR	r0, =1<<0
	BL	irqEnable
	BL	ulc_Init

.Lmain_SetupCapture:
	LDR	r0, =CaptureBuffer
	MOV	r1, #0x00
	LDR	r2, =0x02*CAPTURE_BUFFERSIZE * 2
	BL	memset
0:	LDR	r4, =0x04000400
	LDR	r0, =0xA8000000
	LDR	r1, =.LCaptureL
	LDR	r2, =(0x010000 - CAPTURE_PERIOD/2) | 0<<16
	LDR	r3, =0x02*CAPTURE_BUFFERSIZE / 0x04
	STR	r1, [r4, #0x14]
	STR	r2, [r4, #0x18]
	STR	r3, [r4, #0x1C]
	STR	r0, [r4, #0x10]
	LDR	r0, =0xA87F0000
	LDR	r1, =.LCaptureR
	STR	r1, [r4, #0x34]
	STR	r2, [r4, #0x38]
	STR	r3, [r4, #0x3C]
	STR	r0, [r4, #0x30]
0:	LDR	r0, =0x04000500
	MOV	r1, r0
	ADD	r1, #0x10
	LDR	r2, =.LCaptureL
	LDR	r3, =0x02*CAPTURE_BUFFERSIZE / 0x04
	STMIA	r1!, {r2-r3}
	LDR	r2, =.LCaptureR
	STMIA	r1!, {r2-r3}
	MOV	r1, #0x80
	STRB	r1, [r0, #0x08] @ Begin capture
	STRB	r1, [r0, #0x09]
	LDR	r0, =0x04000108
	LDR	r2, =(0x010000 - CAPTURE_PERIOD)     | 0x80<<16
	LDR	r3, =(0x010000 - CAPTURE_BUFFERSIZE) | 0x84<<16
	STMIA	r0!, {r2-r3}    @ Begin timers to keep track of capture offset
0:	MOV	r0, #CAPTURE_FIFOCHN
	LDR	r1, =CaptureFifoRecv
	@MOV	r2, #0x00       @ Userdata is unused
	BL	fifoSetAddressHandler

.Lmain_MainLoop:
0:	BL	ulc_Update
	BL	swiHalt
	B	0b

ASM_FUNC_END(main)

/**************************************/

@ r0: &Dst (int16_t[2][CAPTURE_SIZE])

ASM_FUNC_GLOBAL(CaptureFifoRecv)
ASM_FUNC_BEG   (CaptureFifoRecv, ASM_MODE_THUMB;ASM_SECTION_FASTCODE)

CaptureFifoRecv:
	MOV	r3, lr
	PUSH	{r3-r7}
	LDR	r1, =0x04000100
	LDRH	r2, [r1, #0x0C]            @ TMR_D(3) (CaptureOffs) -> r2
	LDR	r7, =0x02*CAPTURE_SIZE
	LDR	r6, =0x02*CAPTURE_BUFFERSIZE
	LDR	r5, =0x010000-CAPTURE_BUFFERSIZE
	LDR	r4, =CaptureBuffer
	SUB	r5, r2, r5                 @ Offs = ((CaptureOffs - CAPTURE_SIZE) &~ 1)*sizeof(int16_t)? -> r5
	LSR	r5, #0x01                  @ (we round Offs down to 2 samples to avoid misaligned copy)
	LSL	r5, #0x01+1
	SUB	r5, r7
	BCS	0f
	ADD	r5, r6                     @ Handle wraparound (Offs < 0)
0:	ADD	r4, r5                     @ Src = Buf + Offs -> r4
	SUB	r6, r5                     @ nCopyR = min(CAPTURE_SIZE, BUFFER_SIZE - Offs) -> r6
	CMP	r6, r7
	BCC	0f
	MOV	r6, r7
0:	SUB	r7, r6                     @ nCopyL = CAPTURE_SIZE - nCopyR -> r7
1:	@MOV	r0, r0                     @ Copy L-chan R-side
	MOV	r1, r4
	MOV	r2, r6
	BL	memcpy
	ADD	r0, r6                     @ Copy L-chan L-side
	SUB	r1, r4, r5
	MOV	r2, r7
	BL	memcpy
0:	LDR	r1, =0x02*CAPTURE_BUFFERSIZE
	ADD	r4, r1                     @ Move to R-chan
2:	ADD	r0, r7                     @ Copy R-chan R-side
	MOV	r1, r4
	MOV	r2, r6
	BL	memcpy
	ADD	r0, r6                     @ Copy R-chan L-side
	SUB	r1, r4, r5
	MOV	r2, r7
	BL	memcpy
3:	POP	{r3-r7}
	BX	r3

ASM_FUNC_END(CaptureFifoRecv)

/**************************************/

ASM_DATA_BEG(CaptureBuffer, ASM_SECTION_BSS;ASM_ALIGN(4))

CaptureBuffer:
.LCaptureL: .space 0x02 * CAPTURE_BUFFERSIZE
.LCaptureR: .space 0x02 * CAPTURE_BUFFERSIZE

ASM_DATA_END(CaptureBuffer)

/**************************************/
//! EOF
/**************************************/
