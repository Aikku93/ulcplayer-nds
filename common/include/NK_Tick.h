/**************************************/
#pragma once
/**************************************/

//! Hardware timer consumed by NK_Tick
//! NOTE: Must always be 0.
#define NK_TICK_HWTIMER 0

//! Cycles per timer tick
//! Can be 64 (1.9us), 256 (7.6us), or 1024 (30.6us)
//! NOTE: Cycles are counted in terms of bus timing (ie. 33MHz).
//! NOTE: Larger values have less overhead at the cost of jitter.
#define NK_TICK_LOG2_CYCLES_PER_TICK 10
#define NK_TICK_CYCLES_PER_TICK (1 << NK_TICK_LOG2_CYCLES_PER_TICK)

/**************************************/
#ifndef __ASSEMBLER__
/**************************************/
#ifdef __cplusplus
extern "C" {
#endif
/**************************************/
#include <stdint.h>
/**************************************/

//! NK_Tick_Init()
//! Description: Initialize ticker system.
//! Arguments: None.
//! Returns: Nothing; ticker system initialized.
void NK_Tick_Init(void);

/**************************************/

//! NK_Tick_Poll()
//! Description: Poll the current tick.
//! Arguments: None.
//! Returns: Number of ticks since initialization.
//! Notes:
//!  -To handle wraparound when comparing two values,
//!   compare the SIGNED difference against 0. eg.
//!    (A >= B) -> ((int64_t)(A - B) >= 0)
//!   This gives correct results for differences of up to
//!   2^63-1 ticks, which should be more than enough for
//!   most use cases.
uint64_t NK_Tick_Poll(void);

/**************************************/

//! NK_Tick_MsecToTicks(x)
//! Description: Convert from milliseconds to ticks.
//! Arguments:
//!   x: Number of milliseconds.
//! Returns: Number of ticks for specified milliseconds (rounded down).
//! Notes:
//!  -Base formula: Ms/1000 * HW_FREQ_HZ * 2^-NK_TICK_LOG2_CYCLES_PER_TICK
//!  -Maximum milliseconds (without overflow): 7D269F68Ah (9331.9 hours)
NK_INLINE uint64_t NK_Tick_MsecToTicks(uint64_t x) {
	return x * 0x20BA7ED9ULL >> (14+NK_TICK_LOG2_CYCLES_PER_TICK);
}

//! NK_Tick_TicksToMsec(x)
//! Description: Convert from ticks to milliseconds.
//! Arguments:
//!   x: Number of ticks.
//! Returns: Number of milliseconds for specified ticks (rounded down).
//! Notes:
//!  -Base formula: Ticks * 2^NK_TICK_LOG2_CYCLES_PER_TICK / HW_FREQ_HZ * 1000
//!  -Maximum ticks (without overflow): 105D3F6C8h.
//!   Depending on NK_TICK_LOG2_CYCLES_PER_TICK, this is equivalent to:
//!    NK_TICK_LOG2_CYCLES_PER_TICK == 6:   2.33 hours
//!    NK_TICK_LOG2_CYCLES_PER_TICK == 8:   9.32 hours
//!    NK_TICK_LOG2_CYCLES_PER_TICK == 10: 37.28 hours
//!  -This can never return a value larger than 7FFFFFFh, so return is 32bit.
NK_INLINE uint32_t NK_Tick_TicksToMsec(uint64_t x) {
	return (uint32_t)(x * 0xFA4D3ED1ULL >> (47-NK_TICK_LOG2_CYCLES_PER_TICK));
}

/**************************************/
#ifdef __cplusplus
}
#endif
/**************************************/
#endif
/**************************************/
//! EOF
/**************************************/
