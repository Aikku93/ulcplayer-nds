/**************************************/
#pragma once
/**************************************/

/*

Implicit Structure Definitions
------------------------------

struct CoverArt_t {
	uint16_t Gfx16x16[16*16]; // [0000h] ABGR1555 bitmap
	uint16_t Gfx64x64[64*64]; // [0200h] ABGR1555 bitmap
};

struct TrackListing_t {
	char *TrackName;             // [00h] Title
	char *Artist;                // [04h] Artist
	char *Filename;              // [08h] Filename (bit31=Unplayable, bit30=Inbuilt song (ie. this is a pointer to data))
	struct CoverArt_t *CoverArt; // [0Ch] Pointer to cover art
	uint32_t RateHz;             // [10h] Playback rate (Hz)
	uint16_t RateKbps;           // [14h] Playback rate (kbps)
	uint16_t nChan;              // [16h] Number of channels
	uint32_t Duration;           // [18h] Playback time (seconds)
	uint32_t r1;                 // [1Ch]
};

struct DrawArea_t {
	void   *GfxMem;
	uint8_t TileX0, TileY0, nTilesX, nTilesY;
}

struct DrawBox_t {
	struct DrawArea_t *DrawArea; //! Bit0..1: Alignment (0 = Left, 1 = Center, 2 = Right)
	uint8_t x, y, w, h;          //! w and h are specified as Width-1, Height-1 (eg. w=255 means Width==256)
};

//! Notes about Touch events:
//!  -If the FirstTouch event is not used, then a Touch event will be generated instead
//!  -Until movement is detected, the event handler will be the first one that matches
//!   the TouchXY position. If the detected movement is not supported by that handler,
//!   then if a new handler supports it, this handler will be used from then onward;
//!   if no supported handler is found, movement will stay locked on the handler that
//!   was originally detected based on TouchXY.
//!  -If HoldTicks==0, all Touch events (other than FirstTouch) will be interpreted as
//!   Drag events.
struct TouchEventHandler_t {
	union {
		uint8_t BoundingBox[4]; //! Bounding box x0,x1,y0,y1 (x1 and y1 are inclusive)
		struct {
			uint8_t  x, y;    //! Center x,y and radius
			uint16_t Radius2; //! Squared radius
		} BoundingCircle;
	} Boundary;              //! [00h] Boundary
	uint16_t Flags;          //! [04h] Bit0 = Allow X movement, Bit1 = Allow Y movement, Bit2 = Bounding circle
	uint16_t Priority;       //! [06h] Handler priority (FFFF = Highest priority)
	uint16_t TapTicks;       //! [08h] Ticks before a Touch is interpreted as a Tap gesture
	uint16_t HoldTicks;      //! [0Ah] Ticks before a Touch is interpreted as a Drag gesture
	void    *Userdata;       //! [0Ch] Userdata for callbacks
	struct TouchEventHandler_t *Prev, *Next; //! [10h] Linked list pointers
	void (*TouchCb)(int x, int y, int Dx, int Dy, void *Userdata); //! [18h] Called when a Touch gesture is detected
	void (*TapCb)(int x, int y, void *Userdata);                   //! [1Ch] Called when a Tap gesture is detected
	void (*DragCb)(int x, int y, int Dx, int Dy, void *Userdata);  //! [20h] Called when a Drag gesture is detected
	void (*ReleaseCb)(int xLast, int yLast, void *Userdata);       //! [24h] Called when a Touch or Drag event is completed
};

*/

/**************************************/

//! Small macro for including resource files
.macro IncludeResource x
	.incbin "../source/res/\x"
.endm

/**************************************/

//! Maximum number of songs allowed in listings
.equ MAX_TRACKS, 1024 //! Max 32767

//! Draw bias for x/y coordinates and drawbox alignment
//! The bias lets us adjust packed register values without
//! overflow issues on sign changes.
.equ DRAW_BIAS,            2048 //! (1<<12)/2 (12bit x/y position in function arguments)
.equ DRAWBOX_ALIGN_LEFT,   0
.equ DRAWBOX_ALIGN_CENTER, 1
.equ DRAWBOX_ALIGN_RIGHT,  2

//! Size of the streaming buffer
//! This should be kept small enough that we stream as
//! little data as possible at a time from flashcart,
//! while also taking into account the playback kbps.
//! eg.
//!  A stream at 600kbps would be reading ~73KiB per
//!  second. With a buffer size of 8KiB, the streaming
//!  routines will fetch 73/8 ~= 9 times per second,
//!  which turns into ~18 times per second at 4KiB
//!  chunks (due filling when half empty).
.equ STREAMING_BUFFER_SIZE, (8*1024) //! 8KiB

//! TrackListing_t::Filename tags
.equ TRACKLISTING_UNPLAYABLE, 0x80000000
.equ TRACKLISTING_INBUILT,    0x40000000
.equ TRACKLISTING_FLAGS_MASK, 0xC0000000

/**************************************/
//! EOF
/**************************************/
