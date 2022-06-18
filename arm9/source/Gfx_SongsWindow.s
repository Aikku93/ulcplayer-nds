/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

ASM_DATA_GLOBAL(Gfx_State_SongsWindow)
ASM_DATA_BEG   (Gfx_State_SongsWindow, ASM_SECTION_BSS;ASM_ALIGN(4))

Gfx_State_SongsWindow:
	.word 0 @ [00h] VScroll     [.8fxp]
	.word 0 @ [04h] VScrollRate [.8fxp]

ASM_DATA_END(Gfx_State_SongsWindow)

/**************************************/

@ r4:     [Reserved: &Main_State]
@ r5:     [Reserved:  MenuScrollPos]
@ r6..fp: [Available/Pushed]

ASM_FUNC_GLOBAL(Gfx_DrawSongsWindow)
ASM_FUNC_BEG   (Gfx_DrawSongsWindow, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_DrawSongsWindow:
	RSB	r0, r5, #SCROLLOFFS_SONGS       @ xDrawOffs -> r0
	LDR	r1, =Gfx_State_SongsWindow
	LDR	r2, =TrackListing_SongsOrder
	LDRH	r3, [r4, #0x10]                 @ nListings -> r3
	B	Gfx_DrawPlaylist

ASM_FUNC_END(Gfx_DrawSongsWindow)

/**************************************/
//! EOF
/**************************************/
