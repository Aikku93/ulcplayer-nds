/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulc_Specs.h"
/**************************************/

//! This should be plenty, right?
//! Must be 2^n and <= 256
#define MAX_MSG 32

/**************************************/

ASM_FUNC_GLOBAL(ulc_Init)
ASM_FUNC_BEG   (ulc_Init, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Init:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r3,lr}
#endif
1:	LDR	r0, =ulc_MsgQueue
	MOV	r1, #0x00
	STR	r1, [r0, #0x00] @ RdIdx=WrIdx=0
1:	MOV	r0, #ULC_FIFOCHN
	LDR	r1, =ulc_FifoRecvMsg
	@MOV	r2, #0x00 @ Userdata is unused
	BL	fifoSetDatamsgHandler
#ifdef ARM7
2:	LDR	r0, =0x04000304 @ POWCNT2 |= SOUND
	LDR	r1, [r0]
	MOV	r2, #0x01
	ORR	r1, r2
	STR	r1, [r0]
	LDR	r0, =0x04000500 @ SOUNDCNT |= ENABLE | VOLUME(7Fh)
	LDR	r1, [r0]
	LDR	r2, =0x807F
	ORR	r1, r2
	STR	r1, [r0]
#endif
#ifdef ARM7
	POP	{r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_Init)

/**************************************/

@ r0: nBytes (unused)

ASM_FUNC_BEG(ulc_FifoRecvMsg, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

ulc_FifoRecvMsg:
	STMFD	sp!, {r4-r6,lr}
	LDR	r4, =ulc_MsgQueue
	MRS	r5, cpsr             @ [cpsr -> r5]
	ORR	r3, r5, #0x80        @ [I=1, pesky nested interrupts]
	MSR	cpsr, r3
1:	LDR	r3, [r4], #0x04      @ WrIdx|RdIdx<<16 -> r3, &MsgQueue -> r4
	MOV	r0, #ULC_FIFOCHN
	MOV	r1, #ULC_MAX_MSG_SIZE
	ADD	r6, r3, #0x01        @ (WrIdx+1)%MAX_MSG == RdIdx? (ie. queue is full?)
	AND	r6, r6, #MAX_MSG-1
	CMP	r6, r3, lsr #0x10
	BEQ	.LFifoRecvMsg_QueueIsFull
1:	MOV	r2, r3, lsl #0x10    @ fifoGetDatamsg(ULC_FIFOCHN, MAX_MSG_SIZE, &Queue[OldWrIdx])?
	ADD	r2, r4, r2, lsr #0x10-ULC_LOG2_MAX_MSG_SIZE
	BL	fifoGetDatamsg
	CMN	r0, #0x01
	BEQ	.LFifoRecvMsg_RecvError
1:	STRH	r6, [r4, #0x00-0x04] @ Message has been stored: Store ++WrIdx
	MSR	cpsr, r5             @ [restore cpsr]

.LFifoRecvMsg_Exit:
#ifdef ARM7
	LDMFD	sp!, {r4-r6,lr}
	BX	lr
#else
	LDMFD	sp!, {r4-r6,pc}
#endif

.LFifoRecvMsg_QueueIsFull:
.LFifoRecvMsg_RecvError:
	MSR	cpsr, r5             @ [restore cpsr]
	MOV	r0, #ULC_FIFOCHN     @ Reply with -1 (FIFO error)
	MVN	r1, #0x00
	BL	fifoSendValue32
#ifdef ARM7
	B	.LFifoRecvMsg_Exit
#else
	LDMFD	sp!, {r4-r6,pc}
#endif

ASM_FUNC_END(ulc_FifoRecvMsg)

/**************************************/

@ r0: &Msg
@ r1:  MsgSize

ASM_FUNC_GLOBAL(ulc_PushMsg)
ASM_FUNC_BEG   (ulc_PushMsg, ASM_MODE_ARM;ASM_SECTION_TEXT)

ulc_PushMsg:
	STMFD	sp!, {r4-r6,lr}
	LDR	r4, =ulc_MsgQueue
	MRS	r5, cpsr             @ [cpsr -> r5]
	ORR	r3, r5, #0x80        @ [I=1]
	MSR	cpsr, r3
1:      LDR	r3, [r4], #0x04      @ WrIdx|RdIdx<<16 -> r3, &MsgQueue -> r4
	MOV	r2, r1               @ [use stall cycles to do some more work]
	MOV	r1, r0
	ADD	r6, r3, #0x01        @ (WrIdx+1)%MAX_MSG == RdIdx? (ie. queue is full?)
	AND	r6, r6, #MAX_MSG-1
	CMP	r6, r3, lsr #0x10
	BEQ	.LPushMsg_QueueIsFull
1:	MOV	r0, r3, lsl #0x10    @ memcpy(&Queue[OldWrIdx], Msg, MsgSize)
	ADD	r0, r4, r0, lsr #0x10-ULC_LOG2_MAX_MSG_SIZE
	BL	memcpy
1:	STRH	r6, [r4, #0x00-0x04] @ Message has been stored: Store ++WrIdx
	MSR	cpsr, r5             @ [restore cpsr]
	MOV	r0, #0x01            @ Return TRUE

.LPushMsg_Exit:
#ifdef ARM7
	LDMFD	sp!, {r4-r6,lr}
	BX	lr
#else
	LDMFD	sp!, {r4-r6,pc}
#endif

.LPushMsg_QueueIsFull:
	MSR	cpsr, r5             @ [restore cpsr]
	MOV	r0, #0x00            @ Return FALSE (queue is full)
#ifdef ARM7
	B	.LPushMsg_Exit
#else
	LDMFD	sp!, {r4-r6,pc}
#endif

ASM_FUNC_END(ulc_PushMsg)

/**************************************/

@ r0: &Msg
@ r1:  MsgSize

ASM_FUNC_GLOBAL(ulc_PushMsgExt)
ASM_FUNC_BEG   (ulc_PushMsgExt, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PushMsgExt:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r3,lr}
#endif
0:	MOV	r2, r0           @ fifoSendDatamsg(ULC_FIFOCHN, MsgSize, Msg)?
	@MOV	r1, r1
	MOV	r0, #ULC_FIFOCHN
	BL	fifoSendDatamsg
	SUB	r0, #0x01        @ Return -1 on FIFO error
	BCC	.LPushMsgExt_Exit
1:	MOV	r0, #0x01        @ Message sent, return TRUE

.LPushMsgExt_Exit:
#ifdef ARM7
	POP	{r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_PushMsgExt)

/**************************************/

ASM_FUNC_GLOBAL(ulc_PushMsgExt_Wait)
ASM_FUNC_BEG   (ulc_PushMsgExt_Wait, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PushMsgExt_Wait:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r3,lr}
#endif
1:	MOV	r0, #ULC_FIFOCHN @ Wait for ACK
	BL	fifoCheckValue32
	CMP	r0, #0x00
	BEQ	1b
2:	MOV	r0, #ULC_FIFOCHN @ Return the value returned via FIFO ACK
	BL	fifoGetValue32
#ifdef ARM7
	POP	{r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_PushMsgExt_Wait)

/**************************************/

@ r0: &Msg
@ r1:  MsgSize

ASM_FUNC_GLOBAL(ulc_PushMsgExtSync)
ASM_FUNC_BEG   (ulc_PushMsgExtSync, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PushMsgExtSync:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r3,lr}
#endif
0:	MOV	r2, r0           @ fifoSendDatamsg(ULC_FIFOCHN, MsgSize, Msg)?
	@MOV	r1, r1
	MOV	r0, #ULC_FIFOCHN
	BL	fifoSendDatamsg
	SUB	r0, #0x01        @ Return -1 on FIFO error
	BCC	.LPushMsgExtSync_Exit
1:	MOV	r0, #ULC_FIFOCHN @ Wait for ACK
	BL	fifoCheckValue32
	CMP	r0, #0x00
	BEQ	1b
2:	MOV	r0, #ULC_FIFOCHN @ Return the value returned via FIFO ACK
	BL	fifoGetValue32

.LPushMsgExtSync_Exit:
#ifdef ARM7
	POP	{r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_PushMsgExtSync)

/**************************************/

ASM_FUNC_GLOBAL(ulc_Update)
ASM_FUNC_BEG   (ulc_Update, ASM_MODE_ARM;ASM_SECTION_TEXT)

ulc_Update:
	STMFD	sp!, {r4-r6,lr}
	LDR	r4, =ulc_MsgQueue
	MRS	r5, cpsr

.LUpdate_Loop:
	ORR	ip, r5, #0x80     @ [I=1]
	MSR	cpsr, ip
	LDR	r3, [r4, #0x00]   @ WrIdx|RdIdx<<16 -> r3
	CMP	r3, r3, ror #0x10 @ RdIdx == WrIdx? (ie. buffer is empty?)
	BNE	.LUpdate_InterpretMessage

.LUpdate_Exit:
	MSR	cpsr, r5 @ [restore cpsr]
#ifdef ARM7
	LDMFD	sp!, {r4-r6,lr}
	BX	lr
#else
	LDMFD	sp!, {r4-r6,pc}
#endif

.LUpdate_InterpretMessage:
	MOV	r6, r3, lsr #0x10       @ Prepare NewRdIdx=(RdIdx+1)%MAX_MSG -> r6
	ADD	r6, r6, #0x01
	AND	r6, r6, #MAX_MSG-1
	ADD	r3, r4, r3, lsr #0x10-ULC_LOG2_MAX_MSG_SIZE @ &Msg[RdIdx]-04h -> r3
	LDMIB	r3!, {r0,ip}            @ Msg.State -> r0, Msg.Type|NoACK -> ip, &Msg.Data[]-04h -> r3
	MOVS	lr, ip, lsl #0x01       @ Msg.Type<<1 -> lr, C=NoACK?
	ORRCS	r6, r6, #0x80000000     @ NewRdIdx|NoACK<<31 -> r6
	RSBS	r1, r0, #0x00           @ <- Ensure message has not been cancelled
	CMPCC	lr, #ULC_MSG_COUNT<<1   @ <- This check should not be needed, but whatever, play it safe
	LDRCC	pc, [pc, lr, lsl #0x02-1]
	BCS	.LUpdate_InterpretMessage_CommsError
	.word	.LUpdate_InterpretMessage_PLAYSTREAM
#ifdef ARM7
	.word	.LUpdate_InterpretMessage_PLAYBEGIN
#else
	.word	.LUpdate_InterpretMessage_CommsError
#endif
	.word	.LUpdate_InterpretMessage_PAUSE
	.word	.LUpdate_InterpretMessage_UNPAUSE
	.word	.LUpdate_InterpretMessage_STOP
#ifdef ARM7
	.word	.LUpdate_InterpretMessage_DECODEBLOCK
#else
	.word	.LUpdate_InterpretMessage_CommsError
#endif
	.word	.LUpdate_InterpretMessage_STREAMREFILL

@ lr: Func

.LUpdate_DispatchMessage:
	STRH	r6, [r4, #0x02] @ Store NewRdIdx
	MSR	cpsr, r5        @ [restore cpsr]
#ifdef ARM7
	ADR	lr, 1f          @ Call function
	BX	ip
#else
	BLX	ip
#endif
1:	TST	r6, #0x80000000 @ NoACK?
	MOVEQ	r1, r0          @  If not NoACK, send ACK
	MOVEQ	r0, #ULC_FIFOCHN
	BLEQ	fifoSendValue32
	B	.LUpdate_Loop

/**************************************/

@ Input:
@  r0: &State
@  r3: &MsgData[]-04h
@ Output:
@  r0-r3: Arguments
@  ip:    Func

.LUpdate_InterpretMessage_PLAYSTREAM:
	@MOV	r0, r0      @ State -> r0
	LDMIB	r3, {r1-r3} @ Flags -> r1, StreamBuffer -> r2, StreamSize -> r3
	LDR	ip, =ulc_PlayStream
	B	.LUpdate_DispatchMessage

#ifdef ARM7
.LUpdate_InterpretMessage_PLAYBEGIN:
	@MOV	r0, r0 @ State -> r0
	LDR	ip, =ulc_PlayBegin
	B	.LUpdate_DispatchMessage
#endif

.LUpdate_InterpretMessage_PAUSE:
	@MOV	r0, r0 @ State -> r0
	LDR	ip, =ulc_Pause
	B	.LUpdate_DispatchMessage

.LUpdate_InterpretMessage_UNPAUSE:
	@MOV	r0, r0 @ State -> r0
	LDR	ip, =ulc_Unpause
	B	.LUpdate_DispatchMessage

.LUpdate_InterpretMessage_STOP:
	@MOV	r0, r0 @ State -> r0
	LDR	ip, =ulc_Stop
	B	.LUpdate_DispatchMessage

#ifdef ARM7
.LUpdate_InterpretMessage_DECODEBLOCK:
	@MOV	r0, r0 @ State -> r0
	LDR	ip, =ulc_DecodeBlock
	B	.LUpdate_DispatchMessage
#endif

.LUpdate_InterpretMessage_STREAMREFILL:
	@MOV	r0, r0      @ State -> r0
	LDMIB	r3, {r1-r2} @ DstBuf -> r1, nBytes -> r2
	LDR	ip, =ulc_StreamRefill
	B	.LUpdate_DispatchMessage

.LUpdate_InterpretMessage_CommsError:
	ADR	ip, 1f
	B	.LUpdate_DispatchMessage
1:	MVN	r0, #0x00
	BX	lr

/**************************************/

ASM_FUNC_END(ulc_Update)

/**************************************/

ASM_FUNC_GLOBAL(ulc_Destroy)
ASM_FUNC_BEG   (ulc_Destroy, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Destroy:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r3,lr}
#endif
	LDR	r0, =ulc_MsgQueue
	MOV	r1, #0x00
	STR	r1, [r0, #0x00] @ RdIdx=WrIdx=0 (safety)
1:	MOV	r0, #ULC_FIFOCHN
	@MOV	r1, #0x00
	@MOV	r2, #0x00 @ Userdata is not used
	BL	fifoSetDatamsgHandler
#ifdef ARM7
	POP	{r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_Destroy)

/**************************************/

@ r0: &State

ASM_FUNC_GLOBAL(ulc_InvalidateMessages)
ASM_FUNC_BEG   (ulc_InvalidateMessages, ASM_MODE_ARM;ASM_SECTION_TEXT)

ulc_InvalidateMessages:
#ifdef ARM7
	STR	lr, [sp, #-0x04]!
#else
	STR	lr, [sp, #-0x08]!
#endif
	MRS	r1, cpsr          @ [cpsr -> r1]
	ORR	ip, r1, #0x80     @ [I=1]
	MSR	cpsr, ip
	LDR	r2, =ulc_MsgQueue
	LDR	r3, [r2, #0x00]   @ WrIdx|RdIdx<<16 -> r3
1:	CMP	r3, r3, ror #0x10 @ RdIdx == WrIdx? (ie. end of buffer?)
	BEQ	0f
	ADD	ip, r2, r3, lsr #0x10-ULC_LOG2_MAX_MSG_SIZE
	LDR	lr, [ip, #0x04]!  @ Msg.State -> ip
	SUBS	lr, lr, r0        @ Msg.State == State?
	STREQ	lr, [ip, #0x00]   @  Msg.State = NULL
	ADD	r3, r3, #0x01<<16 @ RdIdx++
	BIC	r3, r3, #(0xFF &~ (MAX_MSG-1))<<16
	B	1b
0:	MSR	cpsr, r1          @ [restore cpsr]
#ifdef ARM7
	LDR	lr, [sp], #0x04
	BX	lr
#else
	LDR	pc, [sp], #0x08
#endif

ASM_FUNC_END(ulc_InvalidateMessages)

/**************************************/

@ r0: &State
@ r1: &DstBuf
@ r2:  nBytes

ASM_FUNC_BEG(ulc_StreamRefill, ASM_MODE_THUMB;ASM_SECTION_FASTCODE)

ulc_StreamRefill:
#ifdef ARM7
	PUSH	{lr}
#else
	PUSH	{r1-r3,lr}
#endif
0:	LDR	r3, [r0, #0x08] @ Cb.ReadFunc(DstBuf, nBytes, ReadUser)
	MOV	r0, r1
	MOV	r1, r2
	ADD	r3, #0x20
	LDMIA	r3, {r2-r3}
#ifdef ARM7
	BL	.Lbxr3
	POP	{r3}
.Lbxr3:	BX	r3
#else
	BLX	r3
	POP	{r0-r3} @ Flush the data we just read (r0 = DstBuf, r1 = nBytes, r2 = Unused (old r3), r3 = Return (old lr))
.balign 4
	BX	pc
	NOP

ASM_MODE_ARM

.LStreamRefill_FlushBuffer:
1:	MCR	p15,0,r0,c7,c14,1 @ DC_CleanAndInvalidate()
	ADD	r0, r0, #0x20
	SUBS	r1, r1, #0x20
	BHI	1b
2:	MOV	r1, #0x00
	MCR	p15,0,r1,c7,c10,4 @ DC_WriteBufferDrain()
3:	BX	r3

#endif

ASM_FUNC_END(ulc_StreamRefill)

/**************************************/

ASM_DATA_BEG(ulc_MsgQueue, ASM_SECTION_BSS;ASM_ALIGN(4))

ulc_MsgQueue:
	.hword 0 @ [00h] WrIdx
	.hword 0 @ [02h] RdIdx
	.space ULC_MAX_MSG_SIZE * MAX_MSG

ASM_DATA_END(ulc_MsgQueue)

/**************************************/

#ifdef ARM7

ASM_DATA_GLOBAL(ulc_Log2Table)
ASM_DATA_BEG   (ulc_Log2Table, ASM_SECTION_RODATA;ASM_ALIGN(1))

@ Integer Log2[x], for x=2^n
@ Use as: ulc_Log2Table[0x077CB531 * x >> (32-5)]

ulc_Log2Table:
	.byte  0, 1,28, 2,29,14,24,3
	.byte 30,22,20,15,25,17, 4,8
	.byte 31,27,13,23,21,19,16,7
	.byte 26,12,18, 6,11, 5,10,9

ASM_DATA_END(ulc_Log2Table)

#endif

/**************************************/
//! EOF
/**************************************/
