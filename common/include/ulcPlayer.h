/**************************************/
#pragma once
/**************************************/

//! Audio capture stuff
#define CAPTURE_FIFOCHN   (14)
#define CAPTURE_PERIOD    (1024)   //! 32728Hz
#define CAPTURE_SIZE_LOG2 (10)
#define CAPTURE_SIZE      (1<<CAPTURE_SIZE_LOG2)
#define CAPTURE_SIN1_2    (0x0065) //! 2^16 *   Sin[0.5*Pi/1024] (windowing)
#define CAPTURE_2SIN1_2   (0x00C9) //! 2^16 * 2*Sin[0.5*Pi/1024] (windowing, update parameter for "magic circle" oscillator)

/**************************************/
//! EOF
/**************************************/
