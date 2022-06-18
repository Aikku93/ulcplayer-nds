/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

ASM_DATA_GLOBAL(Gfx_State_ArtistsWindow)
ASM_DATA_BEG   (Gfx_State_ArtistsWindow, ASM_SECTION_BSS;ASM_ALIGN(4))

Gfx_State_ArtistsWindow:
	.word 0 @ [00h] VScroll     [.8fxp]
	.word 0 @ [04h] VScrollRate [.8fxp]

ASM_DATA_END(Gfx_State_ArtistsWindow)

/**************************************/

@ r4:     [Reserved: &Main_State]
@ r5:     [Reserved:  MenuScrollPos]
@ r6..fp: [Available/Pushed]

ASM_FUNC_GLOBAL(Gfx_DrawArtistsWindow)
ASM_FUNC_BEG   (Gfx_DrawArtistsWindow, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_DrawArtistsWindow:
	RSB	r0, r5, #SCROLLOFFS_ARTISTS     @ xDrawOffs -> r0
	LDR	r1, =Gfx_State_ArtistsWindow
	LDR	r2, =TrackListing_ArtistsOrder
	LDRH	r3, [r4, #0x12]                 @ nListings -> r3
	B	Gfx_DrawPlaylist

ASM_FUNC_END(Gfx_DrawArtistsWindow)

/**************************************/
//! EOF
/**************************************/
