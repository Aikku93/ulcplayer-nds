/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulc.h"
/**************************************/
#include "MainDefines.inc"
/**************************************/

@ r0: Idx (ListIdx | 8000h*ArtistsListings)

ASM_FUNC_GLOBAL(Main_PlayTrack)
ASM_FUNC_BEG   (Main_PlayTrack, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Main_PlayTrack:
	PUSH	{r3-r7,lr}
	MOV	r7, r0                       @ Idx -> r7
	LSL	r0, #0x20-15
	LDR	r1, =TrackListing_SongsOrder
	BCC	0f
	LDR	r1, =TrackListing_ArtistsOrder
0:	LSR	r0, #0x20-15-1               @ TrackListingIdx = Order[Idx] -> r0
	LDRH	r0, [r1, r0]
	LDR	r4, =Main_State              @ State -> r4
	LDR	r5, =TrackListings
	MOV	r1, #0x01                    @ State.Busy = TRUE
	STRB	r1, [r4, #0x0C]
	ADD	r1, r0, #0x01                @ <- Check for FFFFh marker
	LSR	r1, #0x10
	BNE	.LPlayTrack_Exit_Error
	LSL	r0, #0x05                    @ Track = &TrackListings[TrackListingIdx] -> r5
	ADD	r5, r0
1:	LDR	r0, [r5, #0x08]              @ Filename -> r0
	LSL	r6, r0, #0x01                @ Check for "unplayable" flag
	BCS	.LPlayTrack_Exit_Error
	LSL	r6, #0x01                    @ Check for "inbuilt" flag
	BCS	.LPlayTrack_Inbuilt
	LDR	r1, =0                       @ FileDesc = open(Filename, O_RDONLY) -> r6?
	BL	open
	MOV	r6, r0
	BMI	.LPlayTrack_MarkUnplayable
0:	MOV	r0, #0x20
	ADD	r0, r4
	BL	ulc_Stop
	LDR	r2, =StreamingCbList
	MOV	r0, #0x20                    @ Try to begin playback
	ADD	r0, r4
	LDR	r1, =StreamingBuffer
	STR	r2, [sp, #0x00]
	STR	r6, [r2, #0x20]              @ Set ReadUser=FileDesc
	STR	r6, [r2, #0x28]              @ Set SeekUser=FileDesc
	LDR	r2, =STREAMING_BUFFER_SIZE
	LDR	r3, =ULC_PLAY_FLAGS_SETCHANS(0,2)
	BL	ulc_PlayStream
	CMP	r0, #0x00
	BLE	.LPlayTrack_CloseFile_MarkUnplayable

.LPlayTrack_PlaybackOk:
	STRH	r7, [r4, #0x0E] @ Store PlayingTrack_Idx = Idx
	STR	r5, [r4, #0x18] @ Store PlayingTrack = Track
	STR	r6, [r4, #0x1C] @ Store PlayingTrack_File = FileDesc
	MOV	r0, #0x01       @ Return TRUE

.LPlayTrack_Exit:
	MOV	r1, #0x00       @ State.Busy = FALSE
	STRB	r1, [r4, #0x0C]
	POP	{r3-r7,pc}

.LPlayTrack_CloseFile_MarkUnplayable:
	MOV	r0, r6          @ Not able to be played :(
	BL	fclose

.LPlayTrack_MarkUnplayable:
	LDR	r0, [r5, #0x08] @ Set "unplayable" flag and exit
	MOV	r1, #0x01
	LSL	r1, #0x1F
	ORR	r0, r1
	STR	r0, [r5, #0x08]

.LPlayTrack_Exit_Error:
	MOV	r0, #0x00       @ Return FALSE
	B	.LPlayTrack_Exit

.LPlayTrack_Inbuilt:
	MOV	r0, #0x20
	ADD	r0, r4
	BL	ulc_Stop
	MOV	r0, #0x20
	ADD	r0, r4
	LSR	r1, r6, #0x02 @ No need for streaming these songs
	LDR	r2, =ULC_PLAY_FLAGS_SETCHANS(0,2)
	LDR	r3, =StreamingCbList
	BL	ulc_PlayEx
	CMP	r0, #0x00
	BLE	.LPlayTrack_MarkUnplayable
	MOV	r6, #0x00     @ Does not use a file, so set FileDesc=NULL
	B	.LPlayTrack_PlaybackOk

ASM_FUNC_END(Main_PlayTrack)

/**************************************/

@ r0: IgnorePlaybackMode
@ r1: SeekDelta

ASM_FUNC_GLOBAL(Main_SeekTrack)
ASM_FUNC_BEG   (Main_SeekTrack, ASM_MODE_THUMB;ASM_SECTION_TEXT)

Main_SeekTrack:
	PUSH	{r4-r6,lr}
	LDR	r4, =Main_State

.LSeekTrack_HandleShuffleAndRepeat:
	LDRH	r5, [r4, #0x0E]   @ PlayingTrack_Idx -> r5
	LDRB	r2, [r4, #0x0D]   @ PlaybackMode -> r2
	LSL	r3, r5, #0x20-15  @ nListings -> r6
	LDRH	r6, [r4, #0x10]
	BCC	0f
	LDRH	r6, [r4, #0x12]
0:	CMP	r0, #0x00         @ If we are ignoring PlaybackMode, jumps straight to the next track
	BNE	.LSeekTrack_PlayNext
	LSR	r3, r2, #0x01     @ RepeatMode -> r3, Shuffle -> C?
	BCS	.LSeekTrack_Shuffle
0:	CMP	r3, #0x01         @ RepeatMode == Single: Repeat same song
	BEQ	.LSeekTrack_TryPlay
	BCC	.LSeekTrack_Exit  @ RepeatMode == Off: Stop playback
0:	MOV	r1, #0x01         @ RepeatMode == All: Play next
	@B	.LSeekTrack_PlayNext

.LSeekTrack_PlayNext:
0:	LSL	r0, r5, #0x20-15  @ Idx = Wrap(Idx+n)
	LSR	r0, #0x20-15
	ADD	r0, r1
	CMP	r0, r6
	BCC	1f
	ASR	r2, r1, #0x1F     @ <- Assume we underflow with Delta < 0, and overflow with Delta > 0
	ADD	r0, r6, r2
	EOR	r0, r2
	SUB	r5, r0
1:	ADD	r5, r1
.LSeekTrack_TryPlay:
	MOV	r0, r5
	BL	Main_PlayTrack
	ASR	r1, #0x1F         @ Skip by +/-1 track from this point forward
	LSL	r1, #0x01
	ADD	r1, #0x01
	CMP	r0, #0x00
	BEQ	0b

.LSeekTrack_Exit:
	POP	{r4-r6,pc}

.LSeekTrack_Shuffle:
	CMP	r3, #0x01         @ <- RepeatMode == Single takes preference
	BEQ	.LSeekTrack_TryPlay
0:	LDR	r2, [r4, #0x04]   @ Update Xorshift seed -> r2
	BLX	.LSeekTrack_ShuffleARM
	STR	r2, [r4, #0x04]
	CMP	r1, #0x01         @ Delta == 0?
	SBC	r0, r0            @  Delta = 1
	SUB	r1, r0
	B	.LSeekTrack_PlayNext

ASM_MODE_ARM

.LSeekTrack_ShuffleARM:
	EOR	r2, r2, r2, lsl #0x0D
	EOR	r2, r2, r2, lsr #0x11
	EOR	r2, r2, r2, lsl #0x05
	UMULL	r0, r1, r2, r6    @ Delta = Rand[] * nListings -> r1
	BX	lr

ASM_FUNC_END(Main_SeekTrack)

/**************************************/

@ r0: Result [unused]

ASM_FUNC_BEG(StreamingCb_Stop, ASM_MODE_THUMB;ASM_SECTION_TEXT)

StreamingCb_Stop:
	PUSH	{r4,lr}
	LDR	r4, =Main_State
	LDR	r0, [r4, #0x1C]   @ Close file handle (if any)
	MOV	r1, #0x00
	STR	r1, [r4, #0x1C]   @ [PlayingTrack_File = NULL]
	CMP	r0, #0x00
	BEQ	0f
	BL	close
0:	LDRB	r0, [r4, #0x0C]   @ State.Busy -> r0
	CMP	r0, #0x00         @  State.Busy == TRUE: We are manually playing
	BNE	0f                @  something, so skip playing the next track
	@MOV	r0, #0x00         @ Seek to next track
	MOV	r1, #0x01
	BL	Main_SeekTrack
0:	POP	{r4,pc}

ASM_FUNC_END(StreamingCb_Stop)

/**************************************/

@ r0: &Dst
@ r1:  nBytes
@ r2: &FileDesc

ASM_FUNC_BEG(StreamingCb_Read, ASM_MODE_THUMB;ASM_SECTION_TEXT)

StreamingCb_Read:
	PUSH	{r3,lr}
	MOV	r3, r0 @ read(FileDesc, Dst, nBytes)
	MOV	r0, r2
	MOV	r2, r1
	MOV	r1, r3
	BL	read
	POP	{r3,pc}

ASM_FUNC_END(StreamingCb_Read)

/**************************************/

@ r0:  Offset
@ r1:  Origin
@ r2: &FileDesc

ASM_FUNC_BEG(StreamingCb_Seek, ASM_MODE_THUMB;ASM_SECTION_TEXT)

StreamingCb_Seek:
	PUSH	{r3,lr}
	MOV	r3, r0 @ lseek(FileDesc, Offset, Origin)
	MOV	r0, r2
	MOV	r2, r1
	MOV	r1, r3
	BL	lseek
	POP	{r3,pc}

ASM_FUNC_END(StreamingCb_Seek)

/**************************************/

ASM_DATA_BEG(StreamingCbList, ASM_SECTION_DATA;ASM_ALIGN(8))

StreamingCbList:
	.word 0,0 @ Play
	.word 0,0 @ Pause
	.word 0,0 @ Unpause
	.word 0,StreamingCb_Stop @ Stop
	.word 0,StreamingCb_Read @ Read (ReadUser will be set to FILE handle)
	.word 0,StreamingCb_Seek @ Seek (SeekUser will be set to FILE handle)

ASM_DATA_END(StreamingCbList)

/**************************************/

ASM_DATA_BEG(StreamingBuffer, ASM_SECTION_BSS;ASM_ALIGN(32))

StreamingBuffer:
	.space STREAMING_BUFFER_SIZE

ASM_DATA_END(StreamingBuffer)

/**************************************/
//! EOF
/**************************************/
