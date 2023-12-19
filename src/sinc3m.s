#==============================================================================
# sinc3m filter V.2
#==============================================================================
# void sinc3m(in buffered port:32 ip, int &control, int& result)
#						r0					r1			r2
#==============================================================================
# Receives data by 32 bits
# Decimates by 256
# Result is 16 bit
# First bit arriving at port becomes LSB
# Occupies one core
#==============================================================================
# r0 - temporary
# r1 - temporary, incoming data
# r2 - max, max power
# r3, r4, r5 - DELTA1, CN1, CN2
# r6, r7, r8 - DN1, DN3, DN5
# r9 - 0
# r10 - bit counter
#==============================================================================

#==============================================================================
# RO constant section
	.section	.cp.rodata, "ac", @progbits
	.align	4
top:
	.word		0x10000

	.set		MAXPOWER, 25
maxpower:
	.word		MAXPOWER
max:
	.word		1 << MAXPOWER
#==============================================================================
# RW data section
#	.section	.dp.data, "awd", @progbits
#	.align	4

#==============================================================================
# code section
	.text
	.align		2

	.globl		sinc3m
	.globl		sinc3m.nstackwords
	.linkset	sinc3m.nstackwords, 24
	.globl		sinc3m.maxthreads
	.linkset	sinc3m.maxthreads, 0
	.globl		sinc3m.maxtimers
	.linkset	sinc3m.maxtimers, 0
	.globl		sinc3m.maxchanends
	.linkset	sinc3m.maxchanends, 0

	.cc_top		sinc3m.function, sinc3m

sinc3m:
	entsp	24
	stw		r0, sp[1]
	stw		r1, sp[2]
	stw		r2, sp[3]
	stw		r3, sp[4]
	stw		r4, sp[5]
	stw		r5, sp[6]
	stw		r6, sp[7]
	stw		r7, sp[8]
	stw		r8, sp[9]
	stw		r9, sp[10]
	stw		r10, sp[11]

	ldc		r9, 0
	mov		r10, r9

loop:
	ldw		r0, sp[1]
	in		r0, res[r0]		# get next bits
	mov		r1, r0			# save input copy
	ldw		r2, cp[maxpower]
.L10:
	add		r5, r5, r4		# CN2=CN2+CN1
	zext	r5, r2

	add		r4, r4, r3		# CN1=CN1+DELTA1
	zext	r4, r2

	mov		r0, r10
	zext	r0, 5			# current bit number
	shr		r0, r1, r0		# shift current bit to LSB
	zext	r0, 1			# mask it

	add		r3, r3, r0		# DELTA1=DELTA1+BIT
	zext	r3, r2

	add		r10, r10, 1		# increment bit number
	mov		r0, r10
	zext	r0, 5			# check bit number for 32
	bt		r0, .L10
	mov		r0, r10
	zext	r0, 8			# check bit number for 256
	bt		r0, loop

	mov		r10, r9			# clear bit counter
	ldw		r2, cp[max]		# restore max

	sub		r1, r5, r6		# CN3=DN0(CN2)-DN1
	mov		r6, r5			# CN2 becomes new DN1
	lss		r0, r1, r9		# <0 ?
	bf		r0, .L20
	add		r1, r1, r2		# +MAX
.L20:
	sub		r0, r1, r7		# CN4=CN3-DN3
	mov		r7, r1			# CN3 becomes new DN3
	lss		r1, r0, r9		# <0 ?
	bf		r1, .L30
	add		r0, r0, r2		# +MAX
.L30:
	sub		r1, r0, r8		# CN5=CN4-DN5
	mov		r8, r0			# CN4 becomes new DN5
	lss		r0, r1, r9		# <0 ?
	bf		r0, .L40
	add		r1, r1, r2		# +MAX
.L40:
	shr		r1, r1, 8		# cut 8 LSB
	ldw		r0, cp[top]
	sub		r1, r0, r1		# result = top - value

	ldw		r0, sp[3]
	stw		r1, r0[0]		# save result

	ldw		r0, sp[2]
	ldw		r0, r0[0]
	bf		r0, .L50		# check for exit
	bu		loop
.L50:
	ldw		r10, sp[11]
	ldw		r9, sp[10]
	ldw		r8, sp[9]
	ldw		r7, sp[8]
	ldw		r6, sp[7]
	ldw		r5, sp[6]
	ldw		r4, sp[5]
	ldw		r3, sp[4]
	retsp	24

	.cc_bottom	sinc3m.function
