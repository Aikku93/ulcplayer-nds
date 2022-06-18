/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "MainGraphicsDefines.inc"
/**************************************/

@ Generic cover art (struct CoverArt_t)

ASM_DATA_GLOBAL(Gfx_GenericCoverArt)
ASM_DATA_BEG   (Gfx_GenericCoverArt, ASM_SECTION_RODATA;ASM_ALIGN(4))

Gfx_GenericCoverArt:
	IncludeResource GfxBg-GenericCoverArt16x16.gfx
	IncludeResource GfxBg-GenericCoverArt64x64.gfx

ASM_DATA_END(Gfx_GenericCoverArt)

/**************************************/

@ Graphics are 8bpp tiles
@ Map contains a 256x192 tilemap
@ Pal contains 64 colours (Pal[0] = White), with colours 48..63 being used for text.

ASM_DATA_GLOBAL(GfxBg_SplashScreen_Gfx, GfxBg_SplashScreen_Map, GfxBg_SplashScreen_Pal)
ASM_DATA_BEG(GfxBg_SplashScreen_Gfx, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_SplashScreen_Gfx: IncludeResource GfxBg-SplashScreen.gfx.lz
ASM_DATA_END(GfxBg_SplashScreen_Gfx)
ASM_DATA_BEG(GfxBg_SplashScreen_Map, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_SplashScreen_Map: IncludeResource GfxBg-SplashScreen.map.lz
ASM_DATA_END(GfxBg_SplashScreen_Map)
ASM_DATA_BEG(GfxBg_SplashScreen_Pal, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_SplashScreen_Pal: IncludeResource GfxBg-SplashScreen.pal
ASM_DATA_END(GfxBg_SplashScreen_Pal)

/**************************************/

@ Graphics are 8bpp tiles
@ Map contains a 256x256 tilemap (Header/Footer) + 256x256 tilemap (Body)
@ Pal contains 128 colours (Pal[0] = Black), plus a further 128 colours for drawing operations (see BGDRAWPAL_x).

ASM_DATA_GLOBAL(GfxBg_MainWindow_Gfx, GfxBg_MainWindow_Map, GfxBg_MainWindow_Pal)
ASM_DATA_BEG(GfxBg_MainWindow_Gfx, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_MainWindow_Gfx: IncludeResource GfxBg-MainWindow.gfx.lz
ASM_DATA_END(GfxBg_MainWindow_Gfx)
ASM_DATA_BEG(GfxBg_MainWindow_Map, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_MainWindow_Map: IncludeResource GfxBg-MainWindow.map.lz
ASM_DATA_END(GfxBg_MainWindow_Map)
ASM_DATA_BEG(GfxBg_MainWindow_Pal, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxBg_MainWindow_Pal: IncludeResource GfxBg-MainWindow.pal
ASM_DATA_END(GfxBg_MainWindow_Pal)

@ Graphics are 16x16 bitmaps

ASM_DATA_GLOBAL(GfxObj_PlaybackModes_Gfx)
ASM_DATA_BEG   (GfxObj_PlaybackModes_Gfx, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxObj_PlaybackModes_Gfx: IncludeResource GfxObj-PlaybackMode.gfx.lz
ASM_DATA_END(GfxObj_PlaybackModes_Gfx)

/**************************************/

@ Fonts are structued as:
@ struct Font_t {
@   uint32_t nGlyphs;
@   uint8_t  CellW;    // Must be a multiple of 8
@   uint8_t  CellH     // Not restricted to multiples of 8
@   uint8_t  BaseX;    // Baseline shift
@   uint8_t  BaseY;
@   uint8_t  Width[(nGlyphs + 3) &~ 3]; // Glyph spacing
@   uint32_t PxData[]; // 4bpp
@ }

ASM_DATA_GLOBAL(GfxFont_NotoSans8, GfxFont_NotoSans9, GfxFont_NotoSans10, GfxFont_NotoSans12)

ASM_DATA_BEG(GfxFont_NotoSans8, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxFont_NotoSans8: IncludeResource GfxFont-NotoSans8.fnt
ASM_DATA_END(GfxFont_NotoSans8)
ASM_DATA_BEG(GfxFont_NotoSans9, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxFont_NotoSans9: IncludeResource GfxFont-NotoSans9.fnt
ASM_DATA_END(GfxFont_NotoSans9)
ASM_DATA_BEG(GfxFont_NotoSans10, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxFont_NotoSans10: IncludeResource GfxFont-NotoSans10.fnt
ASM_DATA_END(GfxFont_NotoSans10)
ASM_DATA_BEG(GfxFont_NotoSans12, ASM_SECTION_RODATA;ASM_ALIGN(4))
	GfxFont_NotoSans12: IncludeResource GfxFont-NotoSans12.fnt
ASM_DATA_END(GfxFont_NotoSans12)

/**************************************/
//! EOF
/**************************************/
