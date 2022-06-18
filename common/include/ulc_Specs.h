/**************************************/
#pragma once
/**************************************/

/*!
  File header magic value.
!*/
#define ULC_FILE_MAGIC ('U' | 'L'<<8 | 'C'<<16 | '2'<<24)

/*!
  This controls the maximum block size allowed for
  decoding. A larger size uses more memory, but allows
  higher coding gain (up to a limit, anyway; BlockSize=4096
  tends to start degrading from pre/post-echo artifacts.
!*/
#define ULC_MIN_BLOCK_SIZE_LOG2 6
#define ULC_MIN_BLOCK_SIZE (1 << ULC_MIN_BLOCK_SIZE_LOG2)
#define ULC_MAX_BLOCK_SIZE_LOG2 11
#define ULC_MAX_BLOCK_SIZE (1 << ULC_MAX_BLOCK_SIZE_LOG2)

/*!
  This controls support for stereo decoding.
  Support for stereo audio requires double the memory
  usage for the lapping and playback buffers.
!*/
#define ULC_STEREO_SUPPORT 1

/*!
  This chooses whether to use a LUT for the trig terms
  or a quadrature oscillator. The oscillator is ever so
  slightly slower than the LUT method and is somewhat
  less accurate, but uses ~8kB less ARM7 RAM.
!*/
#define ULC_USE_QUADRATURE_OSC 1

/*!
  This controls the bitdepth of the audio, excluding the
  sign bit (eg. 16bit coefficients would set this to 15).
  This should be set as high as possible, regardless of
  the output audio quality, as IMDCT requires a lot of
  recursive computation and the error propagates between
  each step. The final 8-point DCT stages are also not
  particularly accurate, but as long as this precision
  is kept high, the rounding error should be kept in the
  bits that will be discarded for output.
  I'm honestly not sure what the theoretical maximum is
  here. Each step of the DCT algorithm has an infinity
  norm of 2.0, but that assumes 'any' signal, which is
  not actually the case here, as we have normalized the
  signal in the encoding stages. Setting this value to
  28 doesn't appear to cause internal overflow, but I
  can't 100% guarantee that this is the case.
  This value must NOT be larger than 28. In theory, it's
  possible to set this to 29, but this requires special
  handling in ulc_DecodeBlock() (the shift factor can
  become 0, which requires clearing the LSR flag). If set
  to anything larger, MDCT coefficients will overflow.
  NOTE: This refers to the internal precision, not the
  final audio output; this is always 16bit for NDS.
!*/
#define ULC_COEF_PRECISION 20

/*!
  FIFO communication channel (ARM7/ARM9 interwork).
  libnds /really/ puts up a fight to stop you using
  assembler alongside its definitions, so we have to
  hardcode a value here. :/
!*/
#define ULC_FIFOCHN /*FIFO_USER_01*/15

/**************************************/

//! ulc_State_t::Flags
#define ULC_STATE_FLAGBITS_STEREO   0 //! Mono/stereo toggle
#define ULC_STATE_FLAGBITS_PAUSED   1 //! Output is paused
#define ULC_STATE_FLAGBITS_ARM7SRC  2 //! Playback was started on ARM7
#define ULC_STATE_FLAGBITS_STOPPING 3 //! Output is stopping (filling silence until everything has played)
#define ULC_STATE_FLAGBITS_FIXEDCHN 4 //! Fixed channels
#define ULC_STATE_FLAGS_STEREO   (1 << ULC_STATE_FLAGBITS_STEREO)
#define ULC_STATE_FLAGS_PAUSED   (1 << ULC_STATE_FLAGBITS_PAUSED)
#define ULC_STATE_FLAGS_ARM7SRC  (1 << ULC_STATE_FLAGBITS_ARM7SRC)
#define ULC_STATE_FLAGS_STOPPING (1 << ULC_STATE_FLAGBITS_STOPPING)
#define ULC_STATE_FLAGS_FIXEDCHN (1 << ULC_STATE_FLAGBITS_FIXEDCHN)

//! ulc_Msg_t::Type
#define ULC_MSG_PLAYSTREAM   0x00 //! ulc_PlayStream()
#define ULC_MSG_PLAYBEGIN    0x01 //! ulc_PlayBegin()    - ARM7 Exclusive
#define ULC_MSG_PAUSE        0x02 //! ulc_Pause()
#define ULC_MSG_UNPAUSE      0x03 //! ulc_Unpause()
#define ULC_MSG_STOP         0x04 //! ulc_Stop()
#define ULC_MSG_DECODEBLOCK  0x05 //! ulc_DecodeBlock()  - Asynchronous (no ACK generated), ARM7 Exclusive
#define ULC_MSG_STREAMREFILL 0x06 //! ulc_StreamRefill() - Asynchronous (no ACK generated)
#define ULC_MSG_COUNT        0x07
#define ULC_MSG_TAG_NOACK    0x80000000 //! Signals to not generate an ACK after message dispatch

//! ulc_Msg_t
#define ULC_MSG_PLAYSTREAM_SIZE   (0x08 + 0x0C)
#define ULC_MSG_PLAYBEGIN_SIZE    (0x08 + 0x00)
#define ULC_MSG_PAUSE_SIZE        (0x08 + 0x00)
#define ULC_MSG_UNPAUSE_SIZE      (0x08 + 0x00)
#define ULC_MSG_STOP_SIZE         (0x08 + 0x00)
#define ULC_MSG_DECODEBLOCK_SIZE  (0x08 + 0x00)
#define ULC_MSG_STREAMREFILL_SIZE (0x08 + 0x08)
#define ULC_LOG2_MAX_MSG_SIZE 5
#define ULC_MAX_MSG_SIZE (1 << ULC_LOG2_MAX_MSG_SIZE)

/**************************************/
#ifndef __ASSEMBLER__
/**************************************/
#ifdef __cplusplus
extern "C" {
#endif
/**************************************/
#include <stdint.h>
/**************************************/

//! This is used a lot, so forward declare
struct ulc_State_t;

/**************************************/

//! Message structure
struct ulc_Msg_t {
	struct ulc_State_t *State;
	uint32_t Type;

	union {
		//! ULC_MSG_PLAYSTREAMEX
		struct {
			uint32_t Flags;
			void    *StreamBuffer;
			uint32_t StreamSize;
		} PlayStreamEx;

		//! ULC_MSG_PLAYBEGIN
		struct {
			//! Empty
		} PlayBegin;

		//! ULC_MSG_PAUSE
		struct {
			//! Empty
		} Pause;

		//! ULC_MSG_UNPAUSE
		struct {
			//! Empty
		} Unpause;

		//! ULC_MSG_STOP
		struct {
			//! Empty
		} Stop;

		//! ULC_MSG_DECODEBLOCK
		struct {
			//! Empty
		} DecodeBlock;

		//! ULC_MSG_STREAMREFILL
		struct {
			void    *DstBuf;
			uint32_t nBytes;
		} StreamRefill;
	};
};

//! Message pushing routines.
//!  -ulc_PushMsg() pushes a message to the local FIFO queue.
//!   Returns TRUE on success, or FALSE on failure (queue is full).
//!  -ulc_PushMsgExt() pushes a message to the external FIFO queue
//!   in an asynchronous manner.
//!   Returns -1 on FIFO error, or TRUE on success.
//!  -ulc_PushMsgExt_Wait() spinlocks until an ACK response is
//!   received from the external CPU. Do NOT use this on messages
//!   that operate asynchronously, or the CPU will lock up.
//!   Returns -1 on FIFO error, or the return value from a request
//!   generated in a prior call to ulc_PushMsgExt().
//!  -ulc_PushMsgExtSync() pushes a message to the external FIFO
//!   queue in a synchronous manner. Do NOT use this on messages
//!   that operate asynchronously, or the CPU will lock up.
//!   Returns -1 on FIFO error, or the return value from the request.
int ulc_PushMsg        (struct ulc_Msg_t *Msg, uint32_t MsgSize);
int ulc_PushMsgExt     (struct ulc_Msg_t *Msg, uint32_t MsgSize);
int ulc_PushMsgExt_Wait(void);
int ulc_PushMsgExtSync (struct ulc_Msg_t *Msg, uint32_t MsgSize);

/**************************************/

#ifdef ARM7

struct ulc_State_t;

//! This function clears out the state structure (except for buffer
//! and callback allocation, which was the whole point of splitting
//! this function out from PlayStream()), prepares for playback and
//! then "unpauses" playback if desired.
int ulc_PlayBegin(struct ulc_State_t *State);

//! This is a small function to push a DECODEBLOCK message to the
//! local FIFO queue. It's called after every BlockSize samples
//! have played.
void ulc_BlockTimerBurst(struct ulc_State_t *State);

//! This decodes a block's worth of audio. This should not be called
//! manually, and is instead handled via a timer.
//! This issues STREAMREFILL messages to the CPU that started playback
//! when the buffer becomes <50% full.
void ulc_DecodeBlock(struct ulc_State_t *State);

#endif

/**************************************/
#ifdef __cplusplus
}
#endif
/**************************************/
#endif
/**************************************/
//! EOF
/**************************************/
