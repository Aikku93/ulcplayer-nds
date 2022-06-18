/**************************************/
#include "AsmMacros.h"
/**************************************/

ASM_DATA_GLOBAL(NK_Tick_HighTick)
ASM_DATA_BEG   (NK_Tick_HighTick, ASM_SECTION_FASTDATA;ASM_ALIGN(8))

NK_Tick_HighTick:
	.word  0 @ Bits 16..47
	.hword 0 @ Unused
	.hword 0 @ Bits 48..63

ASM_FUNC_END(NK_Tick_HighTick)

/**************************************/
//! EOF
/**************************************/
