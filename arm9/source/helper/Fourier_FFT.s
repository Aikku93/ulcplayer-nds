/**************************************/
#include "AsmMacros.h"
/**************************************/

@ Depends on size of cexp array (Fourier_FFT_Cexp.bin)
.equ FFT_MAXSIZE_LOG2, 10

/**************************************/

@ r0: &In (int32_t[N])
@ r1:  N (must be >= 8)
@ r2: &Out (uint64_t[N/2], outputs N/2 real |X|^2, no Nyquist or negative frequencies)
@ NOTE: DFT output is scaled by N prior to energy calculation.

ASM_FUNC_GLOBAL(Fourier_FFTrAbs2)
ASM_FUNC_BEG   (Fourier_FFTrAbs2, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Fourier_FFTrAbs2:
	STMFD	sp!, {r0-r1,r4-sl,lr}
	@MOV	r0, r0                  @ Z = FFT(z = {Re=In[n*2+0], Im=In[n*2+1]})
	MOV	r1, r1, lsr #0x01
	@MOV	r2, r2
	MOV	r9, r2                  @ Dst -> r9
	BL	Fourier_FFT
	LDMFD	sp!, {r0,r2}
	LDR	r3, =Fourier_FFT_Cexp
	CLZ	lr, r2
	SUBS	lr, lr, #0x1E-FFT_MAXSIZE_LOG2
	MOV	ip, #0x04               @ Stride -> ip
	MOVNE	ip, ip, lsl lr
	ADD	r1, r0, r2, lsl #0x03-1 @ Prepare for untangling
0:	LDRD	r4, [r0]                @ DC = Z[0].Re + Z[0].Im
	SUB	r2, r2, #0x02
	ADD	r4, r4, r5
	SMULL	r6, r7, r4, r4
	STRD	r6, [r9], #0x08
1:	LDRD	r4, [r0, #0x08]!        @ Z[k] -> r4
	LDRD	r6, [r1, #-0x08]!       @ Z[N/2-k] -> r6
	LDR	r8, [r3, ip]!           @ w(=E^(-I*2*Pi*k/N) -> r8 [Re|Im<<16, .15fxp]
	ADD	r4, r4, r6              @ Xe[k] =    (Z[k] + Z*[N/2-k])/2 -> r4,r5 (scaled by 2)
	SUB	r5, r5, r7
	RSB	r6, r4, r6, lsl #0x01   @ Xo[k] = -I*(Z[k] - Z*[N/2-k])/2 -> r7,r6 (scaled by 2, swapped registers)
	ADD	r7, r5, r7, lsl #0x01
	RSB	lr, r7, #0x00           @ t = Xo[k] * w -> r7,r6 (scale by 2 dropped in SMULWx)
	SMULWB	r7, r7, r8
	SMLAWT	r7, r6, r8, r7
	SMULWB	r6, r6, r8
	SMLAWT	r6, lr, r8, r6
	ADD	r4, r7, r4, asr #0x01   @ X[k] = Xe[k] + t (and back to unscaled here)
	ADD	r5, r6, r5, asr #0x01
	SMULL	r6, r7, r4, r4          @ |X|^2 -> r6,r7
	SMLAL	r6, r7, r5, r5
	SUBS	r2, r2, #0x02
	STRD	r6, [r9], #0x08
	BNE	1b
2:	LDMFD	sp!, {r4-sl,pc}

ASM_FUNC_END(Fourier_FFTrAbs2)

/**************************************/

@ r0: &Buf (int32_t[N][2] - Re,Im pairs)
@ r1:  N (must be >= 4)
@ r2: &Tmp (int32_t[N][2] - Re,Im pairs)
@ NOTE: DFT output is scaled by N.

ASM_FUNC_GLOBAL(Fourier_FFT)
ASM_FUNC_BEG   (Fourier_FFT, ASM_MODE_ARM;ASM_SECTION_FASTCODE)

Fourier_FFT:
	CMP	r1, #0x04
	BEQ	.LFFT_4
	STMFD	sp!, {r3-fp,lr}

.LSplit:
	@MOV	r2, r2                  @ &xe[] -> r2
	ADD	r3, r2, r1, lsl #0x03-1 @ &xo[] -> r3
	SUB	r1, r1, r1, lsl #0x10
1:	LDMIA	r0!, {r4-fp}            @ Split x[] into xe[], xo[]
	STMIA	r2!, {r4-r5,r8-r9}
	STMIA	r3!, {r6-r7,sl-fp}
	ADDS	r1, r1, #0x04<<16
	BCC	1b

.LRecurse:
	SUB	r4, r0, r1, lsl #0x03   @ Restore Buf -> r4
	SUB	r5, r2, r1, lsl #0x03-1 @ Restore Tmp -> r5 (contains xe[], xo[])
	MOV	r6, r1
1:	MOV	r0, r5                  @ xe[] -> Xe[]
	MOV	r1, r6, lsr #0x01
	MOV	r2, r4
	BL	Fourier_FFT
	ADD	r0, r5, r6, lsl #0x03-1 @ xo[] -> Xo[]
	MOV	r1, r6, lsr #0x01
	ADD	r2, r4, r6, lsl #0x03-1
	BL	Fourier_FFT

.LCombine:
	CLZ	r0, r6
	SUBS	r0, r0, #0x1E-FFT_MAXSIZE_LOG2
	MOV	r1, #0x04
	MOVNE	r1, r1, lsl r0
	LDR	r2, =Fourier_FFT_Cexp
	MOV	r3, r6, lsl #0x03-1
0:	LDRD	sl, [r5, r3]            @ Xo[k] -> sl,fp
	LDRD	r8, [r5], #0x08         @ Xe[k] -> r8,r9
	SUB	r6, r6, #0x02
	ADD	r8, r8, sl              @ X[k]     = Xe[k] + q -> r8,r9
	ADD	r9, r9, fp
	SUB	sl, r8, sl, lsl #0x01   @ X[k+N/2] = Xe[k] - q -> sl,fp
	SUB	fp, r9, fp, lsl #0x01
	STRD	sl, [r4, r3]
	STRD	r8, [r4], #0x08
1:	LDRD	sl, [r5, r3]            @ Xo[k] -> sl,fp
	LDRD	r8, [r5], #0x08         @ Xe[k] -> r8,r9
	LDR	r0, [r2, r1]!           @ w(=E^(I*2*Pi*k/N) -> r0 [Re|Im<<16, .15fxp]
	RSB	ip, sl, #0x00           @ q = Xo[k] * w* -> sl,fp (w is conjugated for DFT vs iDFT)
	SMULWB	sl, sl, r0
	SMLAWT	sl, fp, r0, sl
	SMULWB	fp, fp, r0
	SMLAWT	fp, ip, r0, fp
	ADD	r8, r8, sl, lsl #0x01   @ X[k]     = Xe[k] + q -> r8,r9
	ADD	r9, r9, fp, lsl #0x01
	SUB	sl, r8, sl, lsl #0x01+1 @ X[k+N/2] = Xe[k] - q -> sl,fp
	SUB	fp, r9, fp, lsl #0x01+1
	STRD	sl, [r4, r3]
	STRD	r8, [r4], #0x08
	SUBS	r6, r6, #0x02
	BNE	1b

.LFFT_Exit:
	LDMFD	sp!, {r3-fp,pc}

/**************************************/

@ r0: &Buf

.LFFT_4:
	STMFD	sp!, {r4-r8,lr}
1:	LDMIA	r0, {r1-r8}           @ x0,x1,x2,x3 -> r1,r2, r3,r4, r5,r6, r7,r8
	ADD	r1, r1, r5            @ a0 = x0 + x2 -> r1,r2
	ADD	r2, r2, r6
	SUB	r5, r1, r5, lsl #0x01 @ b0 = x0 - x2 -> r5,r6
	SUB	r6, r2, r6, lsl #0x01
	ADD	r3, r3, r7            @ a1 = x1 + x3 -> r3,r4
	ADD	r4, r4, r8
	SUB	ip, r3, r7, lsl #0x01 @ b1 = x1 - x3 -> ip,lr (!)
	SUB	lr, r4, r8, lsl #0x01
2:	ADD	r1, r1, r3            @ X[0] = a0 + a1 -> r1,r2
	ADD	r2, r2, r4
	SUB	r7, r5, lr            @ X[3] = b0 + I*b1 -> r7,r8
	ADD	r8, r6, ip
	SUB	r5, r1, r3, lsl #0x01 @ X[2] = a0 - a1 -> r5,r6
	SUB	r6, r2, r4, lsl #0x01
	ADD	r3, r7, lr, lsl #0x01 @ X[1] = b0 - I*b1 -> r3,r4
	SUB	r4, r8, ip, lsl #0x01
3:	STMIA	r0, {r1-r8}
	LDMFD	sp!, {r4-r8,pc}

/**************************************/

ASM_FUNC_END(Fourier_FFT)

/**************************************/

@ E^(I*Pi*k/MAXSIZE) [Re | Im<<16, .15fxp]

ASM_DATA_GLOBAL(Fourier_FFT_Cexp)
ASM_DATA_BEG   (Fourier_FFT_Cexp, ASM_SECTION_FASTDATA;ASM_ALIGN(8))

Fourier_FFT_Cexp:
	.incbin "../source/helper/Fourier_FFT_Cexp.bin"

ASM_DATA_END(Fourier_FFT_Cexp)

/**************************************/
//! EOF
/**************************************/
