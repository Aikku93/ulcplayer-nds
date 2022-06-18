/**************************************/
#include "AsmMacros.h"
/**************************************/
#include "ulcPlayer.h"
/**************************************/
#include "MainDefines.inc"
#include "MainGraphicsDefines.inc"
/**************************************/

@ Visualizer analysis bands
@ This will always try to approximate ERB bands
@ NOTE: We are using overlap-add DFT here, and
@ ANALYSIS_SIZE refers to the size of this DFT
.equ NBANDS_LOG2,         4
.equ NBANDS,             (1<<NBANDS_LOG2)
.equ ANALYSIS_SIZE_LOG2, (2*NBANDS_LOG2)
.equ ANALYSIS_SIZE,      (1<<ANALYSIS_SIZE_LOG2)
.if ANALYSIS_SIZE > CAPTURE_SIZE
	.error "Analysis size too large; increase capture size"
.endif

/**************************************/

@ Band visualization
@ Aspect ratio calculation:
@  r = Tan[Pi / (NBANDS*(a+b))] / 2
@ where
@  a = WedgeWidth = 1.0
@  b = OutlineWidth/2 = (15 / 16) / 2
@ OutlineWidth is divided by 2 to force the wedges to overlap their outlines.
@ This is very close to:
@  r ~= 105 / (NBANDS*100-40)
.equ BAND_MINRADIUS,   (32<<13) @ .13fxp
.equ BAND_RADIUS_NORM, (9216)   @ (((MAXRADIUS-MINRADIUS)<<13) << 16) / MAXAVGAMPLITUDE (where MAXAVGAMPLITUDE is .31fxp)
.equ BAND_WEDGE_THICKNESS, ((105<<16) / (NBANDS*100 - 40)) @ .16fxp (aspect ratio)

/**************************************/

ASM_DATA_BEG(Gfx_State_Visualizer, ASM_SECTION_BSS;ASM_ALIGN(4))

Gfx_State_Visualizer:
	.hword 0 @ [00h] [Reserved]
	.hword 0 @ [02h] RainbowScroll [.8fxp]
	.word  0 @ [04h] VisualizerMode (0 = Wedges, 1 = Blob)

ASM_DATA_END(Gfx_State_Visualizer)

/**************************************/

ASM_FUNC_GLOBAL(Gfx_DrawVisualizerScreen)
ASM_FUNC_BEG   (Gfx_DrawVisualizerScreen, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Gfx_DrawVisualizerScreen:
	MOV	r3, #0x00 @ GetBandPower_Chan = 0
	STMFD	sp!, {r3-fp,lr}

@ NOTE: c is negated for better PSNR and to get a "free" 16bit FFFFh mask
@ NOTE: Oscillator is of "magic circle" type, hence why one oscillator
@ is offset by 0.5 samples.
.LGetBandPower_ChanLoop:
.LGetBandPower_ApplyWindow:
	LDR	ip, [sp, #0x00]
	LDR	r0, =Gfx_Visualizer_CaptureBuffer
	LDR	r2, =-CAPTURE_SIN1_2  @ c = Cos[(0.5    )*Pi/CAPTURE_SIZE + Pi/2]
	MOV	r3, #0x01<<16         @ s = Sin[(0.5-0.5)*Pi/CAPTURE_SIZE + Pi/2]
	ADD	r0, r0, ip, lsl #0x01+CAPTURE_SIZE_LOG2
	ADD	r1, r0, #0x02 * CAPTURE_SIZE
	LDR	ip, =CAPTURE_2SIN1_2 | (-CAPTURE_2SIN1_2)<<16
.macro ApplyWindow a, b @ a = x[n] | x[n+1]<<16, b = x[N-1-(n+1)] | x[N-1-n]<<16
	SMULWB	lr, r2, \a            @ X[n]
	MOV	\a, \a, lsr #0x10
	ORR	\a, \a, lr, lsl #0x10 @ x[n+1] | X[n]<<16
	SMULWT	lr, r2, \b            @ X[N-1-n]
	SMLAWT	r2, r3, ip, r2        @ [c -= s*k]
	SMLAWB	r3, r2, ip, r3        @ [s += c*k]
	AND	lr, lr, r2, lsr #0x10 @ X[N-1-n] | x[N-1-(n+1)]<<16
	ORR	\b, lr, \b, lsl #0x10
	SMULWB	lr, r2, \a            @ X[n+1]
	MOV	\a, \a, lsr #0x10
	ORR	\a, \a, lr, lsl #0x10 @ X[n] | X[n+1]
	SMULWT	lr, r2, \b            @ X[N-1-(n+1)]
	SMLAWT	r2, r3, ip, r2        @ [c -= s*k]
	SMLAWB	r3, r2, ip, r3        @ [s += c*k]
	AND	lr, lr, r2, lsr #0x10 @ X[N-1-(n+1)] | X[N-1-n]<<16
	ORR	\b, lr, \b, lsl #0x10
.endm
1:	LDMIA	r0, {r4-r7}
	LDMDB	r1, {r8-fp}
	ApplyWindow r4, fp
	ApplyWindow r5, sl
	ApplyWindow r6, r9
	ApplyWindow r7, r8
	STMIA	r0!, {r4-r7}
	STMDB	r1!, {r8-fp}
	CMP	r0, r1
	BNE	1b

@ NOTE: We scale up here to get 1.31 accuracy
.equ PRESUM_SCALE, ((-1)<<(31 - 15 - CAPTURE_SIZE_LOG2))
.LGetBandPower_ApplyPresum:
	SUB	r0, r0, #0x02*CAPTURE_SIZE/2 @ SrcBeg  = &WindowedCaptureBuffer[]
	LDR	r3, =Gfx_Visualizer_ProcessingBuffer
.if ANALYSIS_SIZE < CAPTURE_SIZE
	ADD	r1, r0, #0x02*ANALYSIS_SIZE  @ SrcNext = &WindowedCaptureBuffer[] + ANALYSIS_SIZE
	LDR	r2, =(PRESUM_SCALE&0xFFFF) | (CAPTURE_SIZE/ANALYSIS_SIZE-2-1)<<16 | (-ANALYSIS_SIZE)<<20
1:	LDMIA	r0!, {r4-r7}                 @ Sum and expand the first two blocks to 32bit Dst
	LDMIA	r1!, {r8-fp}
	SMULBB	ip, r2, r4
	SMULBT	lr, r2, r4
	SMLABB	ip, r2, r8, ip
	SMLABT	lr, r2, r8, lr
	STMIA	r3!, {ip,lr}
	SMULBB	ip, r2, r5
	SMULBT	lr, r2, r5
	SMLABB	ip, r2, r9, ip
	SMLABT	lr, r2, r9, lr
	STMIA	r3!, {ip,lr}
	SMULBB	ip, r2, r6
	SMULBT	lr, r2, r6
	SMLABB	ip, r2, sl, ip
	SMLABT	lr, r2, sl, lr
	STMIA	r3!, {ip,lr}
	SMULBB	ip, r2, r7
	SMULBT	lr, r2, r7
	SMLABB	ip, r2, fp, ip
	SMLABT	lr, r2, fp, lr
	STMIA	r3!, {ip,lr}
	ADDS	r2, r2, #0x08<<20            @ --nRem?
	BCC	1b
2:	SUB	r3, r3, #0x04*ANALYSIS_SIZE  @ Rewind Dst
	SUB	r2, r2, #ANALYSIS_SIZE<<20   @ nRem = ANALYSIS_SIZE
20:	LDMIA	r3, {r4-r7}                  @ Combine remaining blocks into the 32bit block
	LDMIA	r1!, {r8-fp}
	SMLABB	r4, r2, r8, r4
	SMLABT	r5, r2, r8, r5
	SMLABB	r6, r2, r9, r6
	SMLABT	r7, r2, r9, r7
	STMIA	r3!, {r4-r7}
	LDMIA	r3, {r4-r7}
	SMLABB	r4, r2, sl, r4
	SMLABT	r5, r2, sl, r5
	SMLABB	r6, r2, fp, r6
	SMLABT	r7, r2, fp, r7
	STMIA	r3!, {r4-r7}
	ADDS	r2, r2, #0x08<<20            @ --nRem?
	BCC	20b
21:	SUBS	r2, r2, #0x01<<16            @ Next block
	BCS	2b
.else
	LDR	r2, =(PRESUM_SCALE&0xFFFF) | (-ANALYSIS_SIZE)<<16
1:	LDMIA	r0!, {r8-fp}                 @ Expand
	SMULBB	r4, r2, r8
	SMULBT	r5, r2, r8
	SMULBB	r6, r2, r9
	SMULBT	r7, r2, r9
	SMULBB	r8, r2, sl
	SMULBT	r9, r2, sl
	SMULBB	sl, r2, fp
	SMULBT	fp, r2, fp
	STMIA	r3!, {r4-fp}
	ADDS	r2, r2, #0x08<<16            @ --nRem?
	BCC	1b
.endif

.LGetBandPower_ApplyDFT:
	SUB	r0, r3, #0x04*ANALYSIS_SIZE  @ In  = &ProcessingBuffer.In[]
	MOV	r1, #ANALYSIS_SIZE           @ N   = ANALYSIS_SIZE
	ADD	r2, r0, #0x04*ANALYSIS_SIZE  @ Out = &ProcessingBuffer.Out[]
	BL	Fourier_FFTrAbs2

@ NOTE: Hardware Sqrt in use here
.LGetBandPower_GetFinalAmplitudes:
	LDR	ip, [sp, #0x00]
	LDR	r0, =Gfx_Visualizer_BandAmplitudes
	LDR	r1, =Gfx_Visualizer_ProcessingBuffer + 0x04*ANALYSIS_SIZE
	LDR	r2, =Gfx_Visualizer_Bandwidths
	MOV	r3, #NBANDS
	ADD	r0, r0, ip, lsl #0x02+NBANDS_LOG2
	LDR	ip, =0x040002B1 @ Hardware Sqrt registers -> ip (with bit0=1)
1:	LDRB	lr, [r2], #0x01 @ Bandwidth -> lr
	LDRD	r4, [r1], #0x08 @ Accumulate power for this band (make sure to divide by N (sum) * N^2 (Amplitude bandwidth multiply) before summing)
	SUB	lr, lr, lr, lsl #0x10
	ADDS	lr, lr, #0x01<<16
	MOV	r4, r4, lsr #NBANDS_LOG2*3
	ORR	r4, r4, r5, lsl #0x20-NBANDS_LOG2*3
	MOV	r5, r5, lsr #NBANDS_LOG2*3
	BCS	11f
10:	LDRD	r6, [r1], #0x08
	MOV	r6, r6, lsr #NBANDS_LOG2*3
	ORR	r6, r6, r7, lsl #0x20-NBANDS_LOG2*3
	ADDS	r4, r4, r6
	ADC	r5, r5, r7, lsr #NBANDS_LOG2*3
	ADDS	lr, lr, #0x01<<16
	BCC	10b
11:	STRD	r4, [ip, #0x08-1] @ Get Amplitude = Sqrt[Power] -> r4
	STRH	ip, [ip, #0x00-1] @ <- As long as bit0=1, this is fine
110:	LDRH	r4, [ip, #0x00-1]
	TST	r4, #0x8000
	BNE	110b
	LDR	r5, [ip, #0x04-1] @ Amplitude *= Bandwidth
	MUL	r4, r5, lr
12:	LDR	r5, [r0]          @ OldAmplitude -> r5
	RSBS	r4, r5, r4, lsr #0x01 @ Apply lowpass filter (looks a bit nicer) (slow-ish attack, slower decay)
	ADDCC	r4, r5, r4, asr #0x03
	ADDCS	r4, r5, r4, asr #0x01
	STR	r4, [r0], #0x04
	SUBS	r3, r3, #0x01
	BNE	1b

.LGetBandPower_NextChan:
	LDR	r1, [sp, #0x00]          @ ++Chan?
	ADD	r1, r1, #0x01
	STR	r1, [sp, #0x00]
	CMP	r1, #0x02
	BNE	.LGetBandPower_ChanLoop
0:	SUB	r5, r0, #0x04*2 * NBANDS @ Rewind BandAmplitudes[] -> r5

/**************************************/

.LDrawSpectrum:
	LDR	r4, =0x04000400 @ &GXFIFO -> r4
	MOV	r0, #0x01
	STR	r0, [r4, #0x40] @ MTXMODE = POS
	STR	r0, [r4, #0x54] @ MtxPos = IDENTITY
0:	LDR	r0, =Gfx_Visualizer_Backdrop_DisplayList
	BL	.LDrawSpectrum_DrawDisplayList
	LDR	lr, =Gfx_State_Visualizer
	LDR	sl, =Gfx_Visualizer_RainbowColourLUT
	LDR	fp, [lr, #0x00] @ ColLUTOffs = RainbowScroll -> fp
	LDR	r6, =Fourier_FFT_Cexp + 0x04*(1024/NBANDS/2)
	SUB	fp, fp, #0x0178<<16
	STR	fp, [lr, #0x00] @ RainbowScroll -= 1 + 120/256
	ORR	fp, fp, #0x0100 @ ColLUTMask | ColLUTOffs<<(32-8) -> fp
	ORR	fp, fp, #0x00FE

@ r4: &GXFIFO
@ r5: &BandAmplitudes
@ r6: &CexpLUT
@ r7:  nBandsRem
@ r8:  Chan * 0x04 * NBANDS
@ r9:  Cexp (Re | Im<<16)
@ sl: &ColourLUT
@ fp:  ColLUTMask(0x02*255) | ColLUTOffs<<(32-8)

.LDrawSpectrum_DrawWedges:
	MOV	r8, #0x01                     @ Draw L then R chans
0:	MOV	r7, #NBANDS
1:	LDR	r0, [r5], r8, lsl #0x02       @ Update display matrix
	LDR	r1, [r6], r8, lsl #0x02+(10-NBANDS_LOG2) @ <- NOTE: Depends on size of cexp array
	LDR	r2, =BAND_WEDGE_THICKNESS
	BL	.LDrawSpectrum_UpdateMatrix
	AND	r1, fp, fp, lsr #0x20-8-1     @ Set wedge colour and draw
	LDRH	r1, [sl, r1]
	ADD	fp, fp, r8, lsl #0x20-8 + (8 - (1+NBANDS_LOG2)-1)
	LDR	r0, =Gfx_Visualizer_Wedge_DisplayList
	STR	r1, [r4, #0x80]
	BL	.LDrawSpectrum_DrawDisplayList
2:	SUBS	r7, r7, #0x01                 @ Next band?
	BNE	1b
3:	RSBS	r8, r8, #0x00                 @ R channel? Begin moving backwards
	ADDMI	r5, r5, #0x04*(NBANDS-1)
	ADDMI	r6, r6, r8, lsl #0x02+(10-NBANDS_LOG2) @ <- NOTE: Depends on size of cexp array
	ADDMI	fp, fp, r8, lsl #0x20-8 + (8 - (1+NBANDS_LOG2)-1)
	BMI	0b
4:	B	.LDrawSpectrum_Finish

.LDrawSpectrum_Finish:
	MOV	r0, #0x01
	STR	r0, [r4, #0x0140]             @ SWAPBUFFERS = MANUALSORT

.LRequestCapture_Exit:
	LDR	r2, =Gfx_Visualizer_CaptureBuffer
	MOV	r3, #0x02*2*CAPTURE_SIZE
	MOV	r1, r2
1:	MCR	p15,0,r2,c7,c6,1 @ DC_InvalidateLine()
	ADD	r2, r2, #0x20
	SUBS	r3, r3, #0x20
	BHI	1b
1:	MOV	r0, #CAPTURE_FIFOCHN
	@LDR	r1, =Gfx_Visualizer_CaptureBuffer
	BL	fifoSendAddress
	LDMFD	sp!, {r3-fp,pc}

/**************************************/

@ r0: &List
@ r4: &GXFIFO
@ Trashes r0-r2

.LDrawSpectrum_DrawDisplayList:
	LDR	r1, [r0], #0x04 @ nWords -> r1
1:	LDR	r2, [r0], #0x04
	SUBS	r1, r1, #0x01
	STR	r2, [r4]
	BNE	1b
2:	BX	lr

/**************************************/

@ r0:  Amplitude
@ r1:  Cexp
@ r2:  Stretch [.16fxp, ie. aspect ratio]
@ r4: &REG_GX
@ r7:  nBandsRem
@ r8:  Chan (+1 = Left, -1 = Right)
@ Trashes r0-r3,ip
@ Forms the final matrix: MTX_LOAD_4x3 = TransMtx.RotMtx.ScaleMtx

.LDrawSpectrum_UpdateMatrix:
	LDR	r3, =BAND_RADIUS_NORM @ yScale = MINRADIUS + RADIUSNORM*Amplitude -> r3 [.13fxp]
	LDR	ip, =BAND_MINRADIUS
	SMLAWB	r3, r0, r3, ip
	MOV	ip, #0x00             @ xScale = Stretch * yScale -> r2 [.13fxp]
	SMULWB	r2, r3, r2
	CMP	r8, #0x00             @ Check channel (CCW for L chan, CW for R chan)
	SMULWB	r0, r2, r1            @ c*xScale -> r0 [.13 + .15 - .16 = .12fxp]
	SMULWT	r2, r2, r1            @ s*xScale -> r2
	STR	r0, [r4, #0x5C]       @  {c*xScale, s*xScale, 0}
	RSBGT	r2, r2, #0x00
	STR	r2, [r4, #0x5C]
	STR	ip, [r4, #0x5C]
	SMULWT	r0, r3, r1            @ s*yScale -> r0
	SMULWB	r2, r3, r1            @ c*yScale -> r2
	RSBLT	r0, r0, #0x00
	STR	r0, [r4, #0x5C]       @  {-s*yScale, c*yScale, 0}
	STR	r2, [r4, #0x5C]
	STR	ip, [r4, #0x5C]
	MOV	r0, #0x01<<12
	MOV	r3, #(256/2)<<4
	MOV	r2, #(192/2)<<4
	STR	ip, [r4, #0x5C]       @   {0, 0, 1}
	STR	ip, [r4, #0x5C]
	STR	r0, [r4, #0x5C]
	RSB	ip, r7, #NBANDS
	ADDLT	ip, ip, #NBANDS
	STR	r3, [r4, #0x5C]       @   {xTrans=256/2, yTrans=192/2, zTrans=BandIdx)}
	STR	r2, [r4, #0x5C]
	STR	ip, [r4, #0x5C]
	BX	lr

/**************************************/

ASM_FUNC_END(Gfx_DrawVisualizerScreen)

/**************************************/

@ Must be aligned to cache lines
ASM_DATA_BEG(Gfx_Visualizer_CaptureBuffer, ASM_SECTION_BSS;ASM_ALIGN(32))

Gfx_Visualizer_CaptureBuffer:
	.space 0x02*2 * CAPTURE_SIZE @ int16_t[2][CAPTURE_SIZE]

ASM_DATA_END(Gfx_Visualizer_CaptureBuffer)

/**************************************/

ASM_DATA_BEG(Gfx_Visualizer_BandAmplitudes, ASM_SECTION_BSS;ASM_ALIGN(8))

Gfx_Visualizer_BandAmplitudes:
	.space 0x04*2 * NBANDS @ L/R amplitudes
Gfx_Visualizer_ProcessingBuffer:
	.space 0x04 * ANALYSIS_SIZE @ In(int32_t[ANALYSIS_SIZE])
	.space 0x04 * ANALYSIS_SIZE @ Temp(int32_t[ANALYSIS_SIZE]) / Out(uint64_t[ANALYSIS_SIZE/2])

ASM_DATA_END(Gfx_Visualizer_BandAmplitudes)

/**************************************/

ASM_DATA_BEG(Gfx_Visualizer_Backdrop_DisplayList, ASM_SECTION_RODATA;ASM_ALIGN(4))

Gfx_Visualizer_Backdrop_DisplayList:
	.word (1f-0f) / 0x04
0:	.word 0x4020292A @ TEXIMAGE_PARAM, POLYGON_ATTR, COLOR, BEGIN_VTXS
	.word 0x1ED00000 @  TEXIMAGE_PARAM = OFFSET(0) | WIDTH(256) | HEIGHT(256) | FORMAT_DIRECT
	.word 0x001F0080 @  POLYGON_ATTR   = FRONT_DRAW | ALPHA(31)
	.word 0x7FFF     @  COLOR          = {r=31,g=31,b=31}
	.word 1          @  BEGIN_VTXS     = QUADS
	.word 0x25222322 @ TEXCOORD, VTX_16, TEXCOORD, VTX_XY
	.word 0x00000000 @  TEXCOORD = {s=0,t=0}
	.word 0x00000000 @  VTX_16   = {x=0,y=0,z=Just before clip plane}
	.word 0x0FFF
	.word 0x0C000000 @  TEXCOORD = {s=0,t=192}
	.word 0x0C000000 @  VTX_XY   = {x=0,y=192}
	.word 0x25222522 @ TEXCOORD, VTX_XY, TEXCOORD, VTX_XY
	.word 0x0C001000 @  TEXCOORD = {s=256,t=192}
	.word 0x0C001000 @  VTX_XY   = {x=256,y=192}
	.word 0x00001000 @  TEXCOORD = {s=256,t=0}
	.word 0x00001000 @  VTX_XY   = {x=256,y=0}
	.word 0x00000041 @ END_VTXS[, NOP][, NOP][, NOP]
1:

ASM_FUNC_END(Gfx_Visualizer_Backdrop_DisplayList)

/**************************************/

ASM_DATA_BEG(Gfx_Visualizer_Bandwidths, ASM_SECTION_RODATA;ASM_ALIGN(1))

@ Approximately ERB
@ Should sum to ANALYSIS_SIZE/2, but less than that will also work
Gfx_Visualizer_Bandwidths:
.macro GenerateBandwidths Idx=1
	@ This is a hacky way of doing it, but it sums to ANALYSIS_SIZE/2
	.if \Idx <= NBANDS / 2
		.byte \Idx
	.else
		.byte \Idx - 1
	.endif
	.if (\Idx+1) <= NBANDS
		GenerateBandwidths (\Idx+1)
	.endif
.endm
	GenerateBandwidths

ASM_DATA_END(Gfx_Visualizer_Bandwidths)

/**************************************/

ASM_DATA_BEG(Gfx_Visualizer_Wedge_DisplayList, ASM_SECTION_RODATA;ASM_ALIGN(4))

Gfx_Visualizer_Wedge_DisplayList:
	.word (1f-0f) / 0x04
0:	@ Wedge
	.word 0x2340292A @ TEXIMAGE_PARAM, POLYGON_ATTR, BEGIN_VTXS, VTX_16
	.word 0          @  TEXIMAGE_PARAM = 0
	.word 0x01080080 @  POLYGON_ATTR   = FRONT_DRAW | ALPHA(8) | POLYGON_ID(1) - No antialias :(
	.word 0          @  BEGIN_VTXS     = TRIS
	.word 0xFFF00010 @  VTX_16 = {x=+1,y=-1,z=+2}
	.word 0x0002
	.word 0x00252025 @ VTX_XY, COLOR, VTX_XY[, NOP]
	.word 0xFFF0FFF0 @  VTX_XY = {x=-1,y=-1}
	.word 0x7FFF     @  COLOR  = {r=31,g=31,b=31}
	.word 0x00000000 @  VTX_XY = {x=0,y=0}
	@ Wedge outline
	.word 0x23402941 @ END_VTXS, POLYGON_ATTR, BEGIN_VTXS, VTX_16
	.word 0x001F0080 @  POLYGON_ATTR = FRONT_DRAW | ALPHA(31)
	.word 2          @  BEGIN_VTXS   = TRISTRIP
	.word 0x00000000 @  VTX_16 = {x=0,y=0,z=+1}
	.word 0x0001
	.word 0x25252525 @ VTX_XY, VTX_XY, VTX_XY, VTX_XY
	.word 0xFFF0FFF0 @  VTX_XY = {x=-1,y=-1}
	.word 0xFFEFFFE1 @  VTX_XY = {x=-1-a,y=-1-b} (a=15/16, b=1/16)
	.word 0xFFF00010 @  VTX_XY = {x=+1,y=-1}
	.word 0xFFEF001F @  VTX_XY = {x=+1+a,y=-1-b}
	.word 0x00000025 @ VTX_XY[, NOP][, NOP][, NOP]
	.word 0x00000000 @  VTX_XY = {x=0,y=0}
	.word 0x00000041 @ END_VTXS[, NOP][, NOP][, NOP]
1:

ASM_DATA_END(Gfx_Visualizer_Wedge_DisplayList)

/**************************************/

@ 256-point rainbow LUT

ASM_DATA_BEG(Gfx_Visualizer_RainbowColourLUT, ASM_SECTION_RODATA;ASM_ALIGN(2))

Gfx_Visualizer_RainbowColourLUT:
	.word 0x801F801F,0x841F841F,0x881F881F,0x901F8C1F,0x981F941F,0x9C1F981F,0xA41FA01F,0xAC1FA81F
	.word 0xB41FB01F,0xBC1FB81F,0xC41FC01F,0xCC1FC81F,0xD41FD01F,0xDC1FD81F,0xE41FE01F,0xEC1FE81F
	.word 0xF01FF01F,0xF81FF41F,0xFC1FF81F,0xFC1FFC1F,0xFC1EFC1F,0xFC1DFC1E,0xFC1CFC1D,0xFC1BFC1C
	.word 0xFC1AFC1A,0xFC18FC19,0xFC17FC17,0xFC15FC16,0xFC13FC14,0xFC12FC12,0xFC10FC11,0xFC0EFC0F
	.word 0xFC0CFC0D,0xFC0BFC0C,0xFC09FC0A,0xFC08FC08,0xFC06FC07,0xFC05FC05,0xFC03FC04,0xFC02FC03
	.word 0xFC01FC02,0xFC00FC01,0xFC00FC00,0xFC20FC00,0xFC40FC20,0xFC60FC40,0xFCA0FC80,0xFCC0FCA0
	.word 0xFD00FCE0,0xFD40FD20,0xFD80FD60,0xFDC0FDA0,0xFE00FDE0,0xFE20FE00,0xFE60FE40,0xFEA0FE80
	.word 0xFEE0FEC0,0xFF20FF00,0xFF40FF40,0xFF80FF60,0xFFA0FFA0,0xFFC0FFC0,0xFFE0FFE0,0xFFE0FFE0
	.word 0xFBE0FBE0,0xF7E0F7E0,0xF3E0F3E0,0xEBE0EFE0,0xE7E0EBE0,0xDFE0E3E0,0xDBE0DFE0,0xD3E0D7E0
	.word 0xCFE0CFE0,0xC7E0CBE0,0xBFE0C3E0,0xB7E0BBE0,0xB3E0B3E0,0xABE0AFE0,0xA3E0A7E0,0x9FE0A3E0
	.word 0x97E09BE0,0x93E097E0,0x8FE08FE0,0x8BE08BE0,0x87E087E0,0x83E083E0,0x83E083E0,0x83E183E1
	.word 0x83E283E2,0x83E483E3,0x83E583E4,0x83E783E6,0x83E883E7,0x83EA83E9,0x83EC83EB,0x83ED83EC
	.word 0x83EF83EE,0x83F183F0,0x83F383F2,0x83F583F4,0x83F683F6,0x83F883F7,0x83FA83F9,0x83FB83FA
	.word 0x83FC83FC,0x83FE83FD,0x83FF83FE,0x83FF83FF,0x83FF83FF,0x83BF83DF,0x839F83BF,0x837F839F
	.word 0x833F835F,0x831F831F,0x82DF82FF,0x829F82BF,0x825F827F,0x821F823F,0x81DF81FF,0x819F81BF
	.word 0x815F817F,0x811F813F,0x80FF811F,0x80BF80DF,0x809F809F,0x805F807F,0x803F805F,0x801F801F

ASM_DATA_END(Gfx_Visualizer_RainbowColourLUT)

/**************************************/
//! EOF
/**************************************/
