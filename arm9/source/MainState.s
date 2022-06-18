/**************************************/
#include "AsmMacros.h"
/**************************************/

@ Need ALIGN(32) for ::DecoderState

ASM_DATA_GLOBAL(Main_State)
ASM_DATA_BEG   (Main_State, ASM_SECTION_BSS;ASM_ALIGN(32))

Main_State:
	.word  0    @ [00h] FadeInAlpha       (.32fxp, only used during startup)
	.word  0    @ [04h] XorshiftSeed
	.hword 0    @ [08h] MenuScrollPos
	.hword 0    @ [0Ah] MenuScrollTarget
	.byte  0    @ [0Ch] BusyFlag          (0 = Ready, 1 = Busy)
	.byte  0    @ [0Dh] PlaybackMode      (Shuffle | RepeatMode(=Off/Single/All)<<1)
	.hword 0    @ [0Eh] PlayingTrack_Idx  (Index | 8000h*ArtistsListings)
	.hword 0    @ [10h] nListings_Songs
	.hword 0    @ [12h] nListings_Artists
	.word  0    @ [14h] FooterHScroll     (int32_t, .8fxp)
	.word  0    @ [18h] PlayingTrack      (struct TrackListing_t*)
	.word  0    @ [1Ch] PlayingTrack_File (int, File descriptor)
0:	.space 0x40 @ [20h] DecoderState      (struct ulc_State_t)

ASM_DATA_END(Main_State)

/**************************************/
//! EOF
/**************************************/
