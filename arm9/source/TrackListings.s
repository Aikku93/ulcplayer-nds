/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainDefines.inc"
/**************************************/

//! Number of inbuilt tracks
.equ N_INBUILT_TRACKS, 1
.global N_INBUILT_TRACKS

/**************************************/

@ Inbuilt tracks

ASM_DATA_BEG(TrackListing_InbuiltTrackData, ASM_SECTION_RODATA)

TrackListing_InbuiltTrackData:
1:	.balign 1; TrackListing_Inbuilt_TrackName1:   .asciz "Lastig"
	.balign 1; TrackListing_Inbuilt_Artist1:      .asciz "Sefa & Crypton"
	.balign 4; TrackListing_Inbuilt_FileData1:    IncludeResource music/Sefa_Crypton_-_Lastig.ulc
	.balign 4; TrackListing_Inbuilt_CovertArt1:   IncludeResource music/Sefa_Crypton_-_Lastig.gfx
	.equ       TrackListing_Inbuilt_RateHz1,      32728
	.equ       TrackListing_Inbuilt_AvgRateKbps1, 32
	.equ       TrackListing_Inbuilt_nChan1,       2
	.equ       TrackListing_Inbuilt_Duration1,    64
/*
2:	.balign 1; TrackListing_Inbuilt_TrackName2:   .asciz "Track Name"
	.balign 1; TrackListing_Inbuilt_Artist2:      .asciz "Artist Name"
	.balign 4; TrackListing_Inbuilt_FileData2:    IncludeResource File.ulc
	.balign 4; TrackListing_Inbuilt_CovertArt2:   IncludeResource FileImages.gfx
	.equ       TrackListing_Inbuilt_RateHz2,      32728
	.equ       TrackListing_Inbuilt_AvgRateKbps2, 32
	.equ       TrackListing_Inbuilt_nChan2,       2
	.equ       TrackListing_Inbuilt_Duration2,    3*60 @ In seconds
// ... and so on
*/
ASM_DATA_END(TrackListing_InbuiltTrackData)

/**************************************/
//! Below does not need modification
/**************************************/

@ Track listing slots (struct TrackListing_t)

.macro ExpandInternalListings Idx=1
ASM_DATA_GLOBAL(TrackListing_Inbuilt\Idx)
TrackListing_Inbuilt\Idx:
	.word  TrackListing_Inbuilt_TrackName\Idx
	.word  TrackListing_Inbuilt_Artist\Idx
	.word  TrackListing_Inbuilt_FileData\Idx + TRACKLISTING_INBUILT
	.word  TrackListing_Inbuilt_CovertArt\Idx
	.word  TrackListing_Inbuilt_RateHz\Idx
	.hword TrackListing_Inbuilt_AvgRateKbps\Idx
	.hword TrackListing_Inbuilt_nChan\Idx
	.word  TrackListing_Inbuilt_Duration\Idx
	.word  0
.if (\Idx+1) <= N_INBUILT_TRACKS
	ExpandInternalListings (\Idx+1)
.endif
.endm

ASM_DATA_GLOBAL(TrackListings)
ASM_DATA_BEG   (TrackListings, ASM_SECTION_DATA;ASM_ALIGN(4))

TrackListings:
	ExpandInternalListings
	.space 0x20 * (MAX_TRACKS-N_INBUILT_TRACKS)

ASM_DATA_END(TrackListings)

/**************************************/

@ Track listings (Songs-order)

ASM_DATA_GLOBAL(TrackListing_SongsOrder)
ASM_DATA_BEG   (TrackListing_SongsOrder, ASM_SECTION_BSS;ASM_ALIGN(2))

TrackListing_SongsOrder:
	.space 0x02 * MAX_TRACKS

ASM_DATA_END(TrackListing_SongsOrder)

/**************************************/

@ Track listings (Artists-order)
@ When encountering FFFFh, print the next track's Artist as a heading

ASM_DATA_GLOBAL(TrackListing_ArtistsOrder)
ASM_DATA_BEG   (TrackListing_ArtistsOrder, ASM_SECTION_BSS;ASM_ALIGN(2))

TrackListing_ArtistsOrder:
	.space 0x02 * MAX_TRACKS

ASM_DATA_END(TrackListing_ArtistsOrder)

/**************************************/
//! EOF
/**************************************/
