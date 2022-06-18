/**************************************/
#pragma once
/**************************************/

//! Hardware timer consumed by NK_Timer
//! NOTE: Must not be 0.
#define NK_TIMER_HWTIMER 1

/**************************************/
#ifndef __ASSEMBLER__
/**************************************/
#ifdef __cplusplus
extern "C" {
#endif
/**************************************/
#include <stdint.h>
/**************************************/

//! [20h] Timer structure
struct NK_Timer_t {
	uint64_t Target; //! [00h] Burst tick
	uint32_t Phase;  //! [08h] Period phase (unused when Period == 0)
	uint32_t Period; //! [0Ch] Periodicity (in cycles; 0 = No repeat)
	void (*CbFunc)(void *User);     //! [10h] Callback routine
	void  *CbUser;                  //! [14h] Callback userdata
	struct NK_Timer_t *Prev, *Next; //! [18h] Linked-list previous/next
};

/**************************************/

//! NK_Timer_Init()
//! Description: Initialize software timer system.
//! Arguments: None.
//! Returns: Nothing; software timers initialized.
//! Notes:
//!  -The software timer system relies on the ticker
//!   system; it should have been initialized prior to
//!   initializing the timer system.
//!  -This function may be called more than once. Any
//!   subsequent calls after the first one are ignored.
void NK_Timer_Init(void);

//! NK_Timer_Enqueue(Timer)
//! Description: Enqueue timer for execution.
//! Arguments:
//!  Timer: Timer to enqueue.
//! Returns: Nothing; timer enqueued.
void NK_Timer_Enqueue(struct NK_Timer_t *Timer);

//! NK_Timer_Schedule(Delta)
//! Description: Prepare HW timer for firing.
//! Arguments:
//!  Delta: Ticks until timer burst.
//! Returns: Nothing; HW timer scheduled.
//! Notes:
//!  -When Delta <= 0, the timer will fire in 1 tick.
void NK_Timer_Schedule(int64_t Delta);

/**************************************/

//! NK_Timer_Timer_Create  (Timer, Delta,     CbFunc, CbUser)
//! NK_Timer_Timer_CreateEx(Timer, BurstTick, CbFunc, CbUser)
//! Description: Create a countdown timer.
//! Arguments:
//!   Timer:     Timer handle.
//!   Delta:     Cycles until burst.
//!   BurstTick: Tick at which the timer bursts.
//!   CbFunc:    Burst callback routine.
//!   CbUser:    Burst callback userdata.
//! Returns: Nothing; timer is enqueued.
//! Notes:
//!  -Delta is rounded off to the nearest tick (see NK_TICK_CYCLES_PER_TICK).
//!  -CbFunc is called in IRQ mode; it must exit as soon as possible.
void NK_Timer_Create  (struct NK_Timer_t *Timer, uint64_t Delta,     void (*CbFunc)(void*), void *CbUser);
void NK_Timer_CreateEx(struct NK_Timer_t *Timer, uint64_t BurstTick, void (*CbFunc)(void*), void *CbUser);

/**************************************/

//! NK_Timer_Timer_CreatePeriodic  (Timer, Period, CbFunc, CbUser)
//! NK_Timer_Timer_CreatePeriodicEx(Timer, Period, CbFunc, CbUser, PreBurstTick)
//! Description: Create a periodically-repeating timer.
//! Arguments:
//!   Timer:        Timer handle.
//!   Period:       Period (in cycles) per burst cycle.
//!   CbFunc:       Burst callback routine.
//!   CbUser:       Burst callback userdata.
//!   PreBurstTick: Tick from which the burst timer begins counting.
//! Returns: Nothing; timer is enqueued.
//! Notes:
//!  -Sub-tick accuracy (see NK_TICK_CYCLES_PER_TICK) is maintained by keeping
//!   track of the timer's phase relative to ticks. The callback is handled in
//!   tick accuracy, and may cause execution timing jitter.
//!  -CbFunc is called in IRQ mode; it must exit as soon as possible.
void NK_Timer_CreatePeriodic  (struct NK_Timer_t *Timer, uint32_t Period, void (*CbFunc)(void*), void *CbUser);
void NK_Timer_CreatePeriodicEx(struct NK_Timer_t *Timer, uint32_t Period, void (*CbFunc)(void*), void *CbUser, uint64_t PreBurstTick);

/**************************************/

//! NK_Timer_Stop(Timer)
//! Description: Stop a timer.
//! Arguments:
//!   Timer: Timer handle.
//! Returns: Nothing; timer removed from the queue.
//! Notes:
//!  -Due to the high priority of timer execution (IRQ-level), a timer may still
//!   trigger until this routine returns. Programs should take this into account.
void NK_Timer_Stop(struct NK_Timer_t *Timer);

/**************************************/
#ifdef __cplusplus
}
#endif
/**************************************/
#endif
/**************************************/
//! EOF
/**************************************/
