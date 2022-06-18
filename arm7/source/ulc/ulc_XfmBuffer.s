/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulc_Specs.h"
/**************************************/

@ Note that TmpBuffer must be placed right after XfmBuffer.

ASM_DATA_GLOBAL(ulc_XfmBuffer, ulc_TmpBuffer)
ASM_DATA_BEG(ulc_XfmBuffer, ASM_SECTION_BSS;ASM_ALIGN(4))

ulc_XfmBuffer: .space 0x04*ULC_MAX_BLOCK_SIZE
ulc_TmpBuffer: .space 0x04*ULC_MAX_BLOCK_SIZE

ASM_DATA_END(ulc_XfmBuffer)

/**************************************/
//! EOF
/**************************************/
