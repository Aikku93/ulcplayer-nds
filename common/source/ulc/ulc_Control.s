/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulc.h"
#include "ulc_Specs.h"
/**************************************/

@ r0: &State
@ r1: &FileData
@ r2:  Flags

ASM_FUNC_GLOBAL(ulc_Play)
ASM_FUNC_BEG   (ulc_Play, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Play:
	MOV	r3, #0x00 @ PlayEx(State, FileData, Flags, Cb=NULL)
	@MOV	r2, r2
	@MOV	r1, r1
	@MOV	r0, r0
	@B	ulc_PlayEx

ASM_FUNC_END(ulc_Play)

/**************************************/

@ r0: &State
@ r1: &FileData
@ r2:  Flags
@ r3: &Cb

ASM_FUNC_GLOBAL(ulc_PlayEx)
ASM_FUNC_BEG   (ulc_PlayEx, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PlayEx:
	PUSH	{r3,lr}
	MOV	r3, r2 @ PlayStream(State, StreamBuffer=FileData, StreamSize=0, Flags, Cb)
	MOV	r2, #0x00
	@MOV	r1, r1
	@MOV	r0, r0
	BL	.LPlayStream_Core
#ifdef ARM7
	POP	{r2-r3}
	BX	r3
#else
	POP	{r3,pc}
#endif

ASM_FUNC_END(ulc_PlayEx)

/**************************************/

@ r0:     &State
@ r1:     &StreamBuffer
@ r2:      StreamSize
@ r3:      Flags
@ sp+00h: &Cb

ASM_FUNC_GLOBAL(ulc_PlayStream)
ASM_FUNC_BEG   (ulc_PlayStream, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PlayStream:
.LPlayStream_FillBuffer:
	PUSH	{r0-r4,lr}
	MOV	r4, r0          @ State -> r4

.LPlayStream_FillBuffer_ReadHeader:
1:	MOV	r0, #0x00       @ Seek(0, SET)
	MOV	r1, #ULC_STREAMCB_SEEK_SET
	LDR	r2, [sp, #0x18]
	ADD	r2, #0x28
	LDMIA	r2, {r2-r3}
#ifdef ARM7
	BL	.Lbxr3
#else
	BLX	r3
#endif
2:	LDR	r0, [sp, #0x04] @ Read(StreamBuffer, sizeof(Header))
	MOV	r1, #0x18
	LDR	r2, [sp, #0x18]
	ADD	r2, #0x20
	LDMIA	r2, {r2-r3}
#ifdef ARM7
	BL	.Lbxr3
#else
	BLX	r3
#endif

.LPlayStream_FillBuffer_ReadStreamData:
1:	LDR	r0, [sp, #0x04] @ Seek(Header.StreamOffs, SET)
	LDR	r0, [r0, #0x14]
	MOV	r1, #ULC_STREAMCB_SEEK_SET
	LDR	r2, [sp, #0x18]
	ADD	r2, #0x28
	LDMIA	r2, {r2-r3}
#ifdef ARM7
	BL	.Lbxr3
#else
	BLX	r3
#endif
2:	LDR	r0, [sp, #0x04] @ Read(StreamBuffer+sizeof(Header), StreamSize-sizeof(Header))
	LDR	r1, [sp, #0x08]
	ADD	r0, #0x18
	SUB	r1, #0x18
	LDR	r2, [sp, #0x18]
	ADD	r2, #0x20
	LDMIA	r2, {r2-r3}
#ifdef ARM7
	BL	.Lbxr3
#else
	BLX	r3
#endif

@ We reset the state so that all Play() routines can go through here
.LPlayStream_FillBuffer_ResetState:
#ifdef ARM7
	LDR	r0, [sp, #0x14]
	MOV	lr, r0
	POP	{r0-r4}
	ADD	sp, #0x04
#else
	LDR	r0, [sp, #0x14] @ 8-byte cache alignment -_-
	LDR	r4, [sp, #0x10]
	MOV	lr, r0
	POP	{r0-r3}
	ADD	sp, #0x08
#endif

/**************************************/

@ r0:     &State
@ r1:     &StreamBuffer (or &FileData)
@ r2:      StreamSize (or 0)
@ r3:      Flags
@ sp+00h: &Cb

.LPlayStream_Core:
	MOV	ip, r3          @ Flags -> ip (r3 now free)
	LDR	r3, [sp, #0x00] @ Store State.Cb
	STR	r3, [r0, #0x08]
#ifdef ARM7
	MOV	r3, lr
	PUSH	{r3-r7}
#else
	PUSH	{r3-r7,lr}
#endif
	MOV	r4, r0          @ State -> r4
	MOV	r5, ip          @ Flags -> r5
1:	MOV	r6, #0x00       @ Set State.OutBuf = NULL
	STR	r6, [r4, #0x0C]
	STR	r1, [r4, #0x14] @ Set State.StreamBuffer
	STR	r2, [r4, #0x18] @ Set State.StreamSize
#ifndef ARM7
	CMP	r2, #0x00       @ Streaming (StreamSize != 0)?
	BEQ	0f
	MOV	r3, r1          @  Flush StreamBuffer
	BLX	.LPlayStream_Core_FlushStreamBuffer
0:
#endif

.LPlayStream_SanityCheck:
	LDR	r0, =ULC_FILE_MAGIC  @ Check header magic, block size, and channel count
	LDR	r2, [r1, #0x00]      @ File.Magic -> r2 != MAGIC?
	LDRH	r3, [r1, #0x04]      @ File.BlockSize -> r3 == 0 || !IsPowerOf2(File.BlockSize) || File.BlockSize >= MAX_BLOCK_SIZE || File.BlockSize < MIN_BLOCK_SIZE?
	CMP	r2, r0
	BNE	.LPlayStream_InvalidFile
	LDR	r7, [r1, #0x0C]      @ File.RateHz -> r7
	LDRH	r0, [r1, #0x10]      @ File.nChan -> r0 > 1 + STEREO_SUPPORT || File.nChan == 0?
	NEG	r2, r3
	BEQ	.LPlayStream_InvalidFile
	AND	r2, r3
	CMP	r2, r3
	BNE	.LPlayStream_InvalidFile
	LSR	r2, r3, #ULC_MAX_BLOCK_SIZE_LOG2+1
	BNE	.LPlayStream_InvalidFile
	LSL	r2, r3, #0x20-ULC_MIN_BLOCK_SIZE_LOG2
	BNE	.LPlayStream_InvalidFile
#if ULC_STEREO_SUPPORT
	SUB	r2, r0, #0x01
	CMP	r2, #0x02-1
	BHI	.LPlayStream_InvalidFile
#else
	CMP	r0, #0x01
	BNE	.LPlayStream_InvalidFile
#endif
1:	STRH	r3, [r4, #0x1C]      @ Set State.BlockSize
	SUB	r6, r0, #0x01        @ StateFlags = (nChan == 2)*STEREO | Paused*START_PAUSED
#if ULC_STEREO_SUPPORT && ULC_STATE_FLAGBITS_STEREO != 0
	LSL	r6, #ULC_STATE_FLAGBITS_STEREO
#endif
	LSR	r0, r5, #ULC_PLAY_FLAGBITS_START_PAUSED_BIT+1
	BCC	1f
	ADD	r6, #ULC_STATE_FLAGS_PAUSED
1:	SUB	r0, r7, #0x01        @ nOutBuf = Ceil[(RateHz/8) / BlockSize] = Ceil[RateHz / (8*BlockSize)] = (RateHz-1) / (8*BlockSize) + 1 -> r7
	LSL	r3, #0x03-1          @ ie. buffer at least 0.125 seconds
10:	LSR	r0, #0x01
	LSR	r3, #0x01
	BNE	10b
	MOV	r1, r7               @ [RateHz -> r1]
	ADD	r7, r0, #0x01
	CMP	r7, #0x02            @ Clip at minimum 2 buffers
	BHI	1f
	MOV	r7, #0x02
1:	STRB	r7, [r4, #0x01]      @ Set State.nOutBuf
2:	LDR	r0, =16756991        @ Get playback period = APU_RATE/RateHz
	@MOV	r1, r1
	BL	__udivsi3
	LDRH	r3, [r4, #0x1C]      @ BlockSize -> r3
	LSL	r0, #0x01            @ Store State.Timer.Period = Period*HW_RATE/APU_RATE*BlockSize (janky haxx m8, but out of room in the structure...)
	MUL	r0, r3
	STR	r0, [r4, #0x20+0x0C]

@ LapBufBytes = sizeof(int32_t)*(BlockSize/2)*nChan
@ OutBufBytes = sizeof(int16_t)*BlockSize*nOutBuf*nChan
@ TotalBytes  = LapBufBytes + OutBufBytes
@             = nChan*BlockSize*2*(1 + nOutBuf)
.LPlayStream_AllocateOutBuf:
	ADD	r0, r7, #0x01   @ malloc(TotalBytes)?
	LSL	r0, #0x01
	MUL	r0, r3
#if ULC_STEREO_SUPPORT
	LSR	r1, r6, #ULC_STATE_FLAGBITS_STEREO+1
	BCC	0f
	ADD	r0, r0
0:
#endif
#ifndef ARM7
	MOV	r7, r0          @ OriginalAllocSize -> r7
	ADD	r0, #0x20       @ TotalBytes += CACHE_LINE_SIZE (alignment padding + storage for original malloc() data)
#endif
	BL	malloc
	MOV	r1, r0
	BEQ	.LPlayStream_Exit
#ifndef ARM7
	ADD	r0, #0x20       @ Move to the aligned memory, and place a hidden pointer to original malloc() data
	LSR	r0, #0x05
	LSL	r0, #0x05
	SUB	r0, #0x04
	STMIA	r0!, {r1}
#endif
	STR	r0, [r4, #0x0C] @ Set State.OutBuf
#ifndef ARM7
	BLX	.LPlayStream_AllocateOutBuf_InvalidateOutBuf
#endif

.LPlayStream_BeginPlayback:
	LSR	r0, r5, #ULC_PLAY_FLAGBITS_FIXEDCHN_BIT+1
	BCC	0f
	ADD	r6, #ULC_STATE_FLAGS_FIXEDCHN
	LSL	r0, r5, #0x18-ULC_PLAY_FLAGBITS_LCHAN_STARTBIT @ L|R are next to each other
	LSR	r0, #0x18
	STRB	r0, [r4, #0x1E] @ Set State.Chans
0:	STRB	r6, [r4, #0x1F] @ Set State.Flags
#ifdef ARM7
	MOV	r0, r4          @ Try to start playback
	BL	ulc_PlayBegin
#else
	MOV	r5, #ULC_MSG_PLAYBEGIN
	PUSH	{r4-r5}         @ Message ARM7 requesting playback
	BLX	.LPlayStream_BeginPlayback_FlushState
	MOV	r0, sp
	MOV	r1, #ULC_MSG_PLAYBEGIN_SIZE
	BL	ulc_PushMsgExtSync
	ADD	sp, #0x08
#endif
	ADD	r1, r0, #0x01   @ Check for FALSE result and FIFOERROR result
	CMP	r1, #0x01
	BLS	.LPlayStream_BeginPlayback_Error
0:	@MOV	r0, #0x01       @ Return TRUE

.LPlayStream_Exit:
	MOV	r1, #0x00 @ Handle callback and exit
	BL	ulc_HandleExitCallback
#ifdef ARM7
	POP	{r3-r7}
.Lbxr3:	BX	r3
#else
	POP	{r3-r7,pc}
#endif

.LPlayStream_InvalidFile:
	MOV	r0, #0x00 @ Return FALSE
#ifdef ARM7
	B	.LPlayStream_Exit
#else
	POP	{r3-r7,pc}
#endif

/**************************************/

@ r0:  Result
@ r4: &State
@ r6:  Flags

.LPlayStream_BeginPlayback_Error:
	MOV	r7, r0          @ Stash Result -> r7
0:	LDR	r0, [r4, #0x0C] @ Free OutBuf
#ifndef ARM7
	SUB	r0, #0x04       @ <- Make sure to free from the hidden pointer
	LDR	r0, [r0]
#endif
	BL	free
0:	MOV	r0, r7          @ Return Result
#ifdef ARM7
	B	.LPlayStream_Exit
#else
	POP	{r3-r7,pc}
#endif

#ifndef ARM7

ASM_MODE_ARM

@ r2:  Len (will be destroyed)
@ r3: &Buf (will be destroyed)

.LPlayStream_Core_FlushStreamBuffer:
1:	MCR	p15,0,r3,c7,c14,1 @ DC_CleanAndInvalidateLine()
	ADD	r3, r3, #0x20
	SUBS	r2, r2, #0x20
	BHI	1b
2:	MOV	r2, #0x00
	MCR	p15,0,r2,c7,c10,4 @ DC_WriteBufferDrain()
	BX	lr

@ r0: &Buf (will be destroyed)
@ r7:  Len (will be destroyed)

.LPlayStream_AllocateOutBuf_InvalidateOutBuf:
1:	MCR	p15,0,r0,c7,c6,1 @ DC_InvalidateLine()
	ADD	r0, r0, #0x20
	SUBS	r7, r7, #0x20
	BHI	1b
2:	BX	lr

@ r4: &State

.LPlayStream_BeginPlayback_FlushState:
	ADD	ip, r4, #0x20
	MCR	p15,0,r4,c7,c14,1 @ DC_CleanAndInvalidateLines(State, sizeof(State))
	MCR	p15,0,ip,c7,c14,1 @ <- We need to flush the timer, because we stored the playback period here
	MOV	ip, #0x00
	MCR	p15,0,ip,c7,c10,4 @ DC_WriteBufferDrain()
	BX	lr

#endif

ASM_FUNC_END(ulc_PlayStream)

/**************************************/

@ r0: &State

ASM_FUNC_GLOBAL(ulc_Pause)
ASM_FUNC_BEG   (ulc_Pause, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Pause:
#ifndef ARM7
	MOV	r1, #ULC_MSG_PAUSE
	@MOV	r0, r0
	PUSH	{r0-r2,lr}
	MOV	r0, sp
	MOV	r1, #ULC_MSG_PAUSE_SIZE
	BL	ulc_PushMsgExtSync
	MOV	r1, #0x08
	BL	ulc_HandleExitCallback
	POP	{r1-r3,pc}
#else
	MOV	r3, lr
	PUSH	{r3-r4}
0:	LDR	r3, [r0, #0x10] @ Make sure NextData != NULL (ie. that we are playing)
	CMP	r3, #0x00
	BEQ	4f
	LDRB	r3, [r0, #0x1F] @ Flags |= PAUSED
	LSR	r2, r3, #ULC_STATE_FLAGBITS_PAUSED+1 @ <- Early exit when already paused
	BCS	3f
	ADD	r3, #ULC_STATE_FLAGS_PAUSED
	STRB	r3, [r0, #0x1F]
1:	LDR	r4, =0x04000400
	LDRB	r3, [r0, #0x1E] @ Chans -> r3
	MOV	r1, #0xF0
	LSL	r2, r3, #0x04
	AND	r2, r1          @ ChanL*10h -> r2
	AND	r3, r1          @ ChanR*10h -> r3
	STR	r1, [r4, r2]    @ Stop ChanL (bit31=0, nothing else matters here)
	STR	r1, [r4, r3]    @ Stop ChanR
2:	MOV	r4, r0          @ State -> r4
	ADD	r0, #0x20       @ Stop timer
	BL	NK_Timer_Stop
	MOV	r0, #0x01       @ Return TRUE
3:	MOV	r1, #0x08       @ Handle callback and exit
	BL	ulc_HandleExitCallback_CPUCheckIsLocal
	POP	{r3-r4}
	BX	r3
4:	MOV	r0, #0x00       @ Return FALSE (nothing to pause)
	B	3b
#endif

ASM_FUNC_END(ulc_Pause)

/**************************************/

@ r0: &State

ASM_FUNC_GLOBAL(ulc_Unpause)
ASM_FUNC_BEG   (ulc_Unpause, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Unpause:
#ifndef ARM7
	MOV	r1, #ULC_MSG_UNPAUSE
	@MOV	r0, r0
	PUSH	{r0-r2,lr}
	MOV	r0, sp
	MOV	r1, #ULC_MSG_UNPAUSE_SIZE
	BL	ulc_PushMsgExtSync
	MOV	r1, #0x08
	BL	ulc_HandleExitCallback
	POP	{r1-r3,pc}
#else
	MOV	r1, r9
	MOV	r2, r8
	MOV	r3, lr
	PUSH	{r1-r7}
	MOV	r4, r0 @ State -> r4
	LDR	r5, =0x04000400

@ OutBufOffs = LapBufBytes
@ LapBufBytes = sizeof(int32_t)*(BlockSize/2)*nChan
@             = 2*BlockSize*nChan
.LUnpause_ClearOutBuf:
	LDR	r3, [r0, #0x10] @ Make sure NextData != NULL (ie. that we are playing)
	LDRB	r1, [r4, #0x1F] @ Flags -> r1
	CMP	r3, #0x00
	BEQ	.LUnpause_ExitFail
	LDR	r0, [r4, #0x0C] @ OutBuf -> r0
	LSR	r3, r1, #ULC_STATE_FLAGBITS_PAUSED+1
	LDRB	r3, [r4, #0x01] @ nOutBuf -> r3
	LDRH	r2, [r4, #0x1C] @ BlockSize -> r2
	BCC	.LUnpause_ExitFail @ <- Early exit when not already paused
	SUB	r1, #ULC_STATE_FLAGS_PAUSED
	STRB	r1, [r4, #0x1F] @ Flags &= ~PAUSE
	MUL	r3, r2          @ nSamples = BlockSize*nOutBuf * nChan
	LSL	r2, #0x01       @ OutBufOffs -> r2
#if ULC_STEREO_SUPPORT
	LSR	r1, #ULC_STATE_FLAGBITS_STEREO+1
	BCC	1f
	ADD	r3, r3
	ADD	r2, r2
1:
#endif
	ADD	r0, r2          @ Mem = OutBuf
	MOV	r1, #0x00       @ Val = 0
	LSL	r2, r3, #0x01   @ Cnt = nSamples*sizeof(int16_t)
	STRB	r1, [r4, #0x00] @ [WrBufIdx=0]
	BL	memset

.LUnpause_AllocateChannels:
	LDRH	r0, [r4, #0x1E]      @ Check for fixed channels
	LSR	r1, r0, #0x08+ULC_STATE_FLAGBITS_FIXEDCHN+1
	BCC	1f
	LSL	r1, r0, #0x1C-4
	LSL	r0, #0x1C-0
	LSR	r1, #0x1C
	LSR	r0, #0x1C-4
	LSL	r1, #0x04
	ADD	r6, r5, r0           @ &ChanL -> r6
	ADD	r7, r5, r1           @ &ChanR -> r7
	B	0f
1:	MOV	r9, r5               @ <- Anything that is not a channel index will be fine
	BL	.LUnpause_StealChannel
	ADD	r6, r5, r0           @ &ChanL -> r6
	MOV	ip, r0               @ ChanLIdx -> ip
	BL	.LUnpause_StealChannel
	ADD	r7, r5, r0           @ &ChanR -> r7
	LSL	r0, #0x04            @ State.Chans = ChanLIdx | ChanRIdx<<4
	ADD	r0, ip
	LSR	r0, #0x04
	STRB	r0, [r4, #0x1E]
0:	LDR	r0, [r4, #0x0C]      @ OutBuf -> r0
	LDRB	r1, [r4, #0x01]      @ nOutBuf -> r1
	LDRH	r2, [r4, #0x1C]      @ BlockSize -> r2
	LDRB	r3, [r4, #0x1F]      @ Flags -> r3
	LSL	r5, r2, #0x01        @ OutBufOffs -> r5
	LSL	r1, #0x01            @ BufLenBytes = nOutBuf*BlockSize * sizeof(int16_t) -> r1
	MUL	r1, r2
#if ULC_STEREO_SUPPORT
	LSL	r3, #0x1F-ULC_STATE_FLAGBITS_STEREO
	BPL	0f
	LSL	r5, #0x01
0:
#endif
	ADD	r0, r5
	STR	r6, [r6, #0x00]      @ SOUNDXCNT(ChanL).CNT = [Disabled]
	STR	r7, [r7, #0x00]      @ SOUNDXCNT(ChanR).CNT = [Disabled]
1:	STR	r0, [r6, #0x04]      @ SOUNDXCNT(ChanL).SAD
#if ULC_STEREO_SUPPORT
	LSL	r3, #0x01
	BCC	10f
	ADD	r0, r1               @ Skip to right channel only with STEREO
10:
#endif
	STR	r0, [r7, #0x04]      @ SOUNDXCNT(ChanR).SAD
2:	LDR	r0, [r4, #0x20+0x0C] @ SOUNDXCNT(ChanL/ChanR).{TMR,PNT} = {-Period*APU_RATE/HW_RATE,0}
20:	LSR	r0, #0x01            @ <- Need to divide by BlockSize as well, because we stored Period*BlockSize in the structure
	LSR	r2, #0x01
	BNE	20b
21:	NEG	r0, r0
	LSL	r0, #0x10
	LSR	r0, #0x10
	STR	r0, [r6, #0x08]
	STR	r0, [r7, #0x08]
3:	LSR	r0, r1, #0x02        @ SOUNDXCNT(ChanL/ChanR).LEN = BufLenBytes / sizeof(u32)
	STR	r0, [r6, #0x0C]
	STR	r0, [r7, #0x0C]
4:	LDR	r0, =0xA800007F      @ SOUNDXCNT(ChanL).CNT = VOL(7Fh) | PAN(00h) | LOOPED | PCM16 | ENABLE
	LDR	r1, =0xA87F007F      @ SOUNDXCNT(ChanR).CNT = VOL(7Fh) | PAN(7Fh) | LOOPED | PCM16 | ENABLE
	STR	r0, [r6, #0x00]
	STR	r1, [r7, #0x00]

.LUnpause_StartTimer:
	MOV	r0, r4          @ Start block timer: NK_Timer_CreatePeriodic(&State.Timer, Period*BlockSize, ulc_TmrBurstCb, State)
	ADD	r0, #0x20       @ NOTE: Period*BlockSize is pre-stored in the timer structure as a
	LDR	r1, [r0, #0x0C] @ hack because we ran out of room to hold it in the main structure.
	LDR	r2, =ulc_BlockTimerBurst
	MOV	r3, r4
	BL	NK_Timer_CreatePeriodic
	MOV	r0, #0x01 @ Return TRUE

.LUnpause_Exit:
	MOV	r1, #0x10
	BL	ulc_HandleExitCallback_CPUCheckIsLocal
	POP	{r1-r7}
	MOV	r9, r1
	MOV	r8, r2
	BX	r3

.LUnpause_ExitFail:
	MOV	r0, #0x00 @ Return FALSE
	B	.LUnpause_Exit

@ r5: &SOUNDXCNT(0).CNT
@ r9:  LockedChannel
@ Clobbers r0,r1,r2,r3,r7,r8 (yeesh)

.LUnpause_StealChannel:
	MOV	r0, #0x00     @ BestChanIdx -> r0
	MVN	r1, r0        @ BestChanVol -> r8
	LSR	r1, #0x01
	MOV	r8, r1
	MOV	r2, #0x10     @ nChanRem -> r2
	MOV	r3, r5        @ &Chans[] -> r3
1:	LDR	r1, [r3]      @ If channel is disabled, set Vol=-1
	ASR	r7, r1, #0x1F
	ORR	r1, r7
	BMI	2f
	LSL	r7, r1, #0x16 @ Get volume divider
	LSR	r7, #0x1E
	LSL	r1, #0x20-8   @ Mask volume
	LSR	r1, r7        @ Adjust for volume divider
	CMP	r7, #0x03
	SBC	r7, r7
	ADD	r7, #0x01
	LSR	r1, r7
	CMP	r1, r8        @ Compare to best candidate
	BGE	3f
2:	CMP	r2, r9        @ Locked?
	BEQ	3f
	MOV	r0, r2        @ Set new best candidate
	MOV	r8, r1
3:	ADD	r3, #0x10     @ Next channel?
	SUB	r2, #0x01
	BNE	1b
0:	MOV	r9, r0        @ Set next LockedChannel
	NEG	r0, r0
	ADD	r0, #0x10     @ Form final index (nMaxChan + (ChanIdx-nMaxChan) = ChanIdx)
	LSL	r0, #0x04     @ Stop channel and return ChanIdx*10h
	STR	r2, [r5, r0]
	BX	lr

#endif

ASM_FUNC_END(ulc_Unpause)

/**************************************/

@ r0: &State

ASM_FUNC_GLOBAL(ulc_Stop)
ASM_FUNC_BEG   (ulc_Stop, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_Stop:
#ifndef ARM7
	PUSH	{r4,lr}
	MOV	r4, r0          @ State -> r4
0:	BLX	.LStop_InvalidateState
	LDR	r1, [r4, #0x10] @ Before we do anything else, make sure NextData != NULL (ie. that we are playing)
	CMP	r1, #0x00       @ If nothing is playing, return FALSE
	BEQ	.LStop_NotPlaying
1:	@MOV	r0, r4          @ First, send a PAUSE message to release hardware resources
	BL	ulc_Pause
2:	MOV	r0, r4          @ Invalidate further messages for this player
	BL	ulc_InvalidateMessages
3:	LDR	r0, [r4, #0x0C] @ Free OutBuf (making sure to read from the hidden pointer)
	SUB	r0, #0x04
	LDR	r0, [r0]
	BL	free
4:	MOV	r0, r4          @ Finally, send a STOP message to ARM7 to finish up
	MOV	r1, #ULC_MSG_STOP
	PUSH	{r0-r1}
	MOV	r0, sp
	MOV	r1, #ULC_MSG_STOP_SIZE
	BL	ulc_PushMsgExtSync
	ADD	sp, #0x08
5:	MOV	r1, #0x18
	BL	ulc_HandleExitCallback
	POP	{r4,pc}

.LStop_NotPlaying:
	MOV	r0, #0x00
	POP	{r4,pc}

@ r4: &State

ASM_MODE_ARM

.LStop_InvalidateState:
	@ADD	ip, r4, #0x20
	MCR	p15,0,r4,c7,c6,1 @ DC_InvalidateLines(State)
	@MCR	p15,0,ip,c7,c6,1 @ We do not read from the Timer data, so only flush the "main" state
	BX	lr

#else
	MOV	r3, lr
	PUSH	{r3-r5}
	MOV	r4, r0          @ State -> r4
	LDR	r0, [r4, #0x10] @ Make sure NextData != NULL, or return FALSE (nothing to stop)
	LDRB	r5, [r4, #0x1F] @ Flags -> r5
	CMP	r0, #0x00
	BEQ	6f
1:	LSR	r1, r5, #ULC_STATE_FLAGBITS_PAUSED+1  @ If we are still playing, pause
	BCS	2f
10:	@MOV	r0, r4
	BL	ulc_Pause
2:	LSR	r0, r5, #ULC_STATE_FLAGBITS_ARM7SRC+1 @ If the source is ARM7, we need to free OutBuf
	BCC	3f
20:	LDR	r0, [r4, #0x0C]
	BL	free
3:	MOV	r0, #0x00       @ Set NextData=NULL to mark that playback has ended
	STR	r0, [r4, #0x10]
4:	MOV	r0, r4          @ Invalidate further messages for this player
	BL	ulc_InvalidateMessages
5:	MOV	r0, #0x01       @ Return TRUE
6:	MOV	r1, #0x18
	BL	ulc_HandleExitCallback_CPUCheckIsLocal
	POP	{r3-r5}
	BX	r3
#endif

ASM_FUNC_END(ulc_Stop)

/**************************************/

#ifdef ARM7

@ r0:  Result
@ r1:  CallbackOffs
@ r4: &State

ASM_FUNC_BEG(ulc_HandleExitCallback_CPUCheckIsLocal, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_HandleExitCallback_CPUCheckIsLocal:
	LDRB	r2, [r4, #0x1F]
	LSR	r2, #ULC_STATE_FLAGBITS_ARM7SRC+1
	BCS	ulc_HandleExitCallback
	BX	lr

ASM_FUNC_END(ulc_HandleExitCallback_CPUCheckIsLocal)

#endif

/**************************************/

@ r0:  Result
@ r1:  CallbackOffs
@ r4: &State

ASM_FUNC_GLOBAL(ulc_HandleExitCallback)
ASM_FUNC_BEG   (ulc_HandleExitCallback, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_HandleExitCallback:
#ifdef ARM7
	MOV	r3, lr
	PUSH	{r3,r5}
#else
	PUSH	{r5,lr}
#endif
	LDR	r2, [r4, #0x08] @ State.Cb -> r2?
	MOV	r5, r0          @ Result -> r5
	CMP	r2, #0x00
	BEQ	2f
1:	ADD	r1, r2          @ Callback[CallbackOffs].{User,Func} -> r1,r3?
	LDMIA	r1, {r1,r3}
	CMP	r3, #0x00
	BEQ	2f
#ifdef ARM7
	BL	3f
#else
	BLX	r3
#endif
	MOV	r0, r5          @ Restore Result and exit
#ifdef ARM7
2:	POP	{r3,r5}
3:	BX	r3
#else
2:	POP	{r5,pc}
#endif

ASM_FUNC_END(ulc_HandleExitCallback)

/**************************************/

#ifdef ARM7

@ r0: &State

ASM_FUNC_GLOBAL(ulc_PlayBegin)
ASM_FUNC_BEG   (ulc_PlayBegin, ASM_MODE_THUMB;ASM_SECTION_TEXT)

ulc_PlayBegin:
	MOV	r3, lr
	PUSH	{r3-r5}
	MOV	r4, r0          @ State -> r4
1:	LDR	r2, [r4, #0x14] @ FileHeader(=StreamBuffer) -> r2
	MOV	r1, #0x00
	LDR	r3, [r2, #0x08] @ FileHeader.nBlocks -> r3
	@STRB	r1, [r4, #0x00] @ State.WrBufIdx         = 0 (will be reset on Unpause())
	STRH	r1, [r4, #0x02] @ State.LastSubBlockSize = 0
	STR	r3, [r4, #0x04] @ State.nBlkRem          = FileHeader.nBlocks
	MOV	r3, #0x18       @ State.NextData         = FileHeader + sizeof(FileHeader)
	ADD	r3, r2
	STR	r3, [r4, #0x10]

@ LapBufBytes = sizeof(int32_t)*(BlockSize/2)*nChan
@             = 2*BlockSize*nChan
.LPlayBegin_ClearLapBuf:
	LDR	r0, [r4, #0x0C] @ LapBuf -> r0
	MOV	r1, #0x00       @ FillValue = 0 -> r1
	LDRH	r2, [r4, #0x1C] @ BlockSize -> r2
	LDRB	r5, [r4, #0x1F] @ Flags -> r5
	LSL	r2, #0x01       @ FillSize = LapBufBytes
#if ULC_STEREO_SUPPORT
	LSR	r3, r5, #ULC_STATE_FLAGBITS_STEREO+1
	BCC	0f
	ADD	r2, r2
0:
#endif
	BL	memset

.LPlayBegin_BeginPlayback:
	LSR	r0, r5, #ULC_STATE_FLAGBITS_PAUSED+1
	BCS	2f
1:	ADD	r5, #ULC_STATE_FLAGS_PAUSED @ Unpause() needs the PAUSE bit set
	STRB	r5, [r4, #0x1F]
	MOV	r0, r4
	BL	ulc_Unpause
2:	MOV	r0, #0x01 @ Return TRUE

.LPlayBegin_Exit:
	POP	{r3-r5}
	BX	r3

ASM_FUNC_END(ulc_PlayBegin)

#endif

/**************************************/

#ifdef ARM7

@ r0: &State

ASM_FUNC_BEG(ulc_BlockTimerBurst, ASM_MODE_THUMB;ASM_SECTION_FASTCODE)

ulc_BlockTimerBurst:
	LDR	r1, =ULC_MSG_DECODEBLOCK | ULC_MSG_TAG_NOACK
	@MOV	r0, r0
	PUSH	{r0-r1,lr}
	MOV	r0, sp
	MOV	r1, #ULC_MSG_DECODEBLOCK_SIZE
	BL	ulc_PushMsg
	ADD	sp, #0x08
	POP	{r3}
	BX	r3

ASM_FUNC_END(ulc_BlockTimerBurst)

#endif

/**************************************/
//! EOF
/**************************************/
