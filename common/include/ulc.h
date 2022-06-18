/**************************************/
#pragma once
/**************************************/

//! ulc_Play()::Flags
//! ulc_PlayEx()::Flags
//! ulc_PlayStream()::Flags
#define ULC_PLAY_FLAGBITS_START_PAUSED_BIT 0
#define ULC_PLAY_FLAGBITS_FIXEDCHN_BIT     1
#define ULC_PLAY_FLAGBITS_LCHAN_STARTBIT   2
#define ULC_PLAY_FLAGBITS_RCHAN_STARTBIT   6
#define ULC_PLAY_FLAGS_START_PAUSED  (1 << ULC_PLAY_FLAGBITS_START_PAUSED_BIT)
#define ULC_PLAY_FLAGS_FIXEDCHN      (1 << ULC_PLAY_FLAGBITS_FIXEDCHN_BIT)
#define ULC_PLAY_FLAGS_SETCHANS(l,r) (ULC_PLAY_FLAGS_FIXEDCHN | (l)<<ULC_PLAY_FLAGBITS_LCHAN_STARTBIT | (r)<<ULC_PLAY_FLAGBITS_RCHAN_STARTBIT)

//! ulc_StreamingCb_t::SeekFunc()::Origin
#define ULC_STREAMCB_SEEK_SET 0 //! SEEK_SET
#define ULC_STREAMCB_SEEK_CUR 1 //! SEEK_CUR

/**************************************/
#ifndef __ASSEMBLER__
/**************************************/
#include <stdint.h>
/**************************************/
#include "NK_Timer.h"
/**************************************/
#ifdef __cplusplus
extern "C" {
#endif
/**************************************/

//! [18h] ULC File Header
struct ulc_FileHeader_t {
	uint32_t Magic;        //! [00h] Magic value/signature
	uint16_t BlockSize;    //! [04h] Transform block size
	uint16_t MaxBlockSize; //! [06h] Largest block size (in bytes; 0 = Unknown)
	uint32_t nBlocks;      //! [08h] Number of blocks
	uint32_t RateHz;       //! [0Ch] Playback rate
	uint16_t nChan;        //! [10h] Channels in stream
	uint16_t RateKbps;     //! [12h] Nominal coding rate
	uint32_t StreamOffs;   //! [14h] Offset of data stream
};

//! [40h] ULC State Structure
//! OutBuf[] layout:
//!  int32_t LapBuf[nChan][BlockSize/2]
//!  int16_t OutBuf[nChan][nOutBuf][BlockSize]
//! Notes:
//!  -Do NOT manually modify anything here; consider everything volatile.
//!  -When playback has finished, ::NextData will be set to NULL and if
//!   a Stop callback is present, that will be called also.
struct ulc_CbList_t {
	//! These functions correspond to states that may have
	//! occurred internally (eg. end of playback), and not
	//! just manually-issued control commands.
	void (*PlayUser);                //! [00h] ulc_Play()/ulc_PlayEx()/ulc_PlayStream()
	void (*PlayFunc)(int Result, void *User);
	void (*PauseUser);               //! [08h] ulc_Pause()
	void (*PauseFunc)(int Result, void *User);
	void (*UnpauseUser);             //! [10h] ulc_Unpause()
	void (*UnpauseFunc)(int Result, void *User);
	void (*StopUser);                //! [18h] ulc_Stop()
	void (*StopFunc)(int Result, void *User);

	//! These functions are used with streamed audio only
	//! and are not used with ulc_Play() or ulc_PlayEx().
	//! If streaming audio is not being used within this
	//! callback structure, these items are not needed.
	//! ARM9: It is not necessary to cache-clean output
	//! from ReadFunc(); this is handled internally.
	void *ReadUser;                  //! [20h] Read stream data
	void (*ReadFunc)(void *Dst, uint32_t nBytes, void *User);
	void *SeekUser;                  //! [28h] Seek in stream
	void (*SeekFunc)(int32_t Offset, uint32_t Origin, void *User);
};
struct ulc_State_t {
	uint8_t   WrBufIdx;         //! [00h] Buffer to next write to (Shifted 1 bit left)
	uint8_t   nOutBuf;          //! [01h] Number of output buffers
	uint16_t  LastSubBlockSize; //! [02h] Last subblock size processed
	uint32_t  nBlkRem;          //! [04h] Blocks remaining in playback
	struct ulc_CbList_t *Cb;    //! [08h] Callbacks list (this can be NULL)
	      void *OutBuf;         //! [0Ch] Decoding buffers
	const void *NextData;       //! [10h] Next data to read from
	      void *StreamBuffer;   //! [14h] Streaming buffer
	uint32_t  StreamSize;       //! [18h] Stream buffer size (0 = Unstreamed)
	uint16_t  BlockSize;        //! [1Ch] Block size
	uint8_t   Chans;            //! [1Eh] Hardware channels (L/R in lower/upper nybble respectively)
	uint8_t   Flags;            //! [1Fh] Internal flags
	struct NK_Timer_t Timer;    //! [20h] Block timer
};

/**************************************/

//! ulc_Init()
//! Description: Initialize ulc-codec decoder facilities.
//! Arguments: None.
//! Returns: Nothing; decoding facilities initialized.
void ulc_Init(void);

//! ulc_Update()
//! Description: Update decoding state.
//! Arguments: None.
//! Returns: Nothing; decoding state updated.
//! Notes:
//!  -This routine should be called every so often, preferably in a
//!   thread that has lower priority than the "main logic" thread, so
//!   that sound handling occurs in the background. Depending on the
//!   BlockSize of any streams playing, there should be a small amount
//!   of leeway in the timing for this routine; this is guaranteed to
//!   be at least 0.125 seconds (a little over 7 frames), but it must
//!   be noted that playback decoding may take up to 2 frames, thus
//!   reducing the available leeway time.
//!  -Decoder callbacks are handled here, so it is recommended to not
//!   call this function in IRQ mode.
//!  -Streaming is handled inside this routine. Depending on the size
//!   of the streaming buffer, this may take a while to read the card
//!   data.
//!  -ARM7: Block decoding occurs during this call, which may take an
//!   exceedingly long amount of time, depending on how many decoders
//!   are operating, as well as transform block size. Overall CPU use
//!   is generally ~35% per stream, but the function call itself will
//!   generally take a very long time to exit between decoding calls.
void ulc_Update(void);

//! ulc_InvalidateMessages(State)
//! Description: Clear remaining commands for this state.
//! Arguments:
//!  State: Decoder state structure.
//! Returns: Nothing; commands invalidated.
//! Notes:
//!  -This is an internal function, and should not need to be called
//!   manually. This is used when Stop() is called, so that if we
//!   received further commands (eg. STREAM_REFILL) before we finish
//!   destroying the playback state, they will be safely ignored
//!   rather than being interpreted.
void ulc_InvalidateMessages(struct ulc_State_t *State);

//! ulc_Play      (State, FileData, Flags)
//! ulc_PlayEx    (State, FileData, Flags, Cb)
//! ulc_PlayStream(State, StreamBuffer, StreamSize, Flags, Cb)
//! ulc_Pause     (State)
//! ulc_Unpause   (State)
//! ulc_Stop      (State)
//! Description: Control decoding state.
//! Arguments:
//!   State:        Decoder state structure.
//!   FileData:     Pointer to ulc file data.
//!   Flags:        Playback flags (see ULC_PLAY_FLAGS_x).
//!   Cb:           Pointer to callback structure.
//!   StreamBuffer: Pointer to buffer to contain streaming data.
//!   StreamSize:   Size of the above StreamBuffer (in bytes).
//! Returns:
//!  On success: 1 is returned.
//!  On failure: 0 is returned.
//!  On FIFO error: -1 is returned.
//! Notes:
//!  -StreamSize must be a multiple of 32 bytes.
//!  -When streaming, a stream-refill callback will be issued via the
//!   Cb.ReadFunc callback, with nBytes always being a multiple of 32,
//!   and DstBuf being aligned to StreamBuffer's alignment (mod 32).
//!  -ARM9: Ensure StreamBuffer is aligned to 32 bytes.
//!  -ARM9: Ensure ulc_State_t is aligned to cache lines (32 bytes).
//!  -ARM9: When using ulc_Play() or ulc_PlayEx(), FileData cannot be
//!         cache-cleaned automatically, and must be done by the user.
int ulc_Play      (struct ulc_State_t *State, const void *FileData, uint32_t Flags);
int ulc_PlayEx    (struct ulc_State_t *State, const void *FileData, uint32_t Flags, const struct ulc_CbList_t *Cb);
int ulc_PlayStream(struct ulc_State_t *State, void *StreamBuffer, uint32_t StreamSize, uint32_t Flags, const struct ulc_CbList_t *Cb);
int ulc_Pause     (struct ulc_State_t *State);
int ulc_Unpause   (struct ulc_State_t *State);
int ulc_Stop      (struct ulc_State_t *State);

/**************************************/
#ifdef __cplusplus
}
#endif
/**************************************/
#endif
/**************************************/
//! EOF
/**************************************/
