/**************************************/
#include "AsmMacros.h"
/**************************************/

ASM_DATA_GLOBAL(NK_Timer_Queue)
ASM_DATA_BEG   (NK_Timer_Queue, ASM_SECTION_FASTDATA;ASM_ALIGN(4))

NK_Timer_Queue:
	.word 0 @ Next timer to burst

ASM_FUNC_END(NK_Timer_Queue)

/**************************************/
//! EOF
/**************************************/
