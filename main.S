#include <avr/io.h>
#define MYOSCAL 0xA5
#define BURSTLEN 32
#define BURSTSTART 0x60
#define PBUFLEN 88
#define PBUFSTART BURSTSTART+BURSTLEN
#define PBUFEND PBUFSTART+PBUFLEN
#define INRATE 44100
#define OUTRATE 62500
#define OUTINC 46242
#define SETBUSY sbi _SFR_IO_ADDR(PORTB), 2
#define CLRBUSY cbi _SFR_IO_ADDR(PORTB), 2
#define SETACK cbi _SFR_IO_ADDR(PORTB), 0
#define CLRACK sbi _SFR_IO_ADDR(PORTB), 0


outcntlo	=	2
outcnthi	=	3
inposlo		=	4
inposhi		=	5
outpos0		=	6
outpos1		=	7
outpos2		=	8
outpos3		=	9
inratelo	=	10
inratehi	=	11
outratelo	=	12
outratehi	=	13
outinclo	=	14
outinchi	=	15


pbufwptr	=	16
pbufrptr	=	17
initreg		=	18 // This reg used in ioinit
t1reg0		=	19

i0reg0		=	20
i0reg1		=	21
i0reg2		=	22
i0reg3		=	23
// i0 will get any free regs... these ATM not used
i0reg4		=	24
// A flag for whether stereo is on....
stereoflag	=	25

t1regX		=	26 // X ptr lo
i0regY		=	28 // Y ptr lo
i0regZ		=	30 // Z ptr lo

// These are well... problematic sometimes
// We just zero 'em and ignore after
invreg0		=	27
invreg1		=	29
invreg2		=	31
// this register always zero
zeroreg		=	1


.section .text
	.global main
main:
	rcall ioinit
1:	
	rjmp 1b
	
convertinit:
	clr inposlo
	clr inposhi
	clr outpos0
	clr outpos1
	clr outpos2
	clr outpos3
	clr outcntlo
	clr outcnthi
	ret

	.global INT0_vect
INT0_vect:
	out _SFR_IO_ADDR(GIMSK), zeroreg 
	in i0reg0, _SFR_IO_ADDR(SREG)
	sei
	SETACK
	ldi i0reg2, 16
	ldi i0regY, BURSTSTART
	

0:	
	SBIC _SFR_IO_ADDR(PINB), 6
	RJMP 0b
	
1:
	IN i0reg1, _SFR_IO_ADDR(PINA)
	SETBUSY
	ST Y+, i0reg1
2:	
	SBIS _SFR_IO_ADDR(PINB), 6
	RJMP 2b
	IN i0reg1, _SFR_IO_ADDR(PINA)
	CLRBUSY
	ST Y+, i0reg1
	dec i0reg2
	brne 0b

	cpi i0reg1, 0xFA
	brne 0f
	rcall I0_cmdvalidate
	// returns validity in T flag ; T=1 ==> jmp to command exec
	brts I0_cmdexec
0:

	ldi i0regZ, BURSTSTART
	ldi i0reg3, 32
	sbrc stereoflag, 0
	ldi i0reg3, 16

0:	
	ld i0reg1, Z+
	sbrc stereoflag, 0
	ld i0reg2, Z+
1:
	// convertoutput
	cp inposlo, outpos2
	cpc inposhi, outpos3
	brne 4f	// break
	cp outcntlo, outratelo
	cpc outcnthi, outratehi
	breq 3f // after if
	mov i0regY, pbufwptr
	st Y+, i0reg1
	sbrc stereoflag, 0
	st Y+, i0reg2
	cpi i0regY, PBUFEND
	brne 2f
	ldi i0regY, PBUFSTART
2:	
	cp i0regY, pbufrptr
	breq 2b
	mov pbufwptr, i0regY
	sec
	adc outcntlo, zeroreg
	adc outcnthi, zeroreg
3:
	add outpos0, outinclo
	adc outpos1, outinchi
	adc outpos2, zeroreg
	adc outpos3, zeroreg
	rjmp 1b
4:
	sec
	adc inposlo, zeroreg
	adc inposhi, zeroreg
	
	cp inposlo, inratelo
	cpc inposhi, inratehi
	brne 5f // end of convertoutput
	clr inposlo
	clr inposhi
	clr outpos2
	clr outpos3
	clr outcntlo
	clr outcnthi
5:
	dec i0reg3
	brne 0b

6:
	ldi i0reg2, _BV(INT0)
	out _SFR_IO_ADDR(SREG), i0reg0 // Restoring SREG ==> cli too
	out _SFR_IO_ADDR(GIFR), i0reg2
	out _SFR_IO_ADDR(GIMSK), i0reg2
	CLRACK
	reti

I0_cmdexec:
	cli
	ldi i0regZ, BURSTSTART
	rcall convertinit
	ldd inratelo, Z+2
	ldd inratehi, Z+4
	ldd outinclo, Z+6
	ldd outinchi, Z+8
	ldd stereoflag, Z+10
	dec stereoflag // 1-2 to 0-1	
	ldi pbufwptr, PBUFSTART
	ldi pbufrptr, PBUFSTART
	cp outinclo, zeroreg
	cpc outinchi, zeroreg
	brne 1f // ok
	ldi i0reg1, 0xFF
	mov outinclo, i0reg1
	mov outinchi, i0reg1
1:	rjmp 6b


I0_cmdvalidate:
	clt
	ldi i0regZ, BURSTSTART
	ld i0reg1, Z+
	ld i0reg2, Z+
	cpi i0reg1, 0xAA
	brne 2f // fail
	cpi i0reg2, 0x55
	brne 2f // fail
	// There are many more "rules" in the cmd packet,
	// That could be checked, but before problems arise,
	// we won't bother (it's 3 uniq bytes 32-byte aligned already)
	set
2:	
	ret

	.global TIMER1_OVF1_vect
TIMER1_OVF1_vect:
	in t1reg0, _SFR_IO_ADDR(SREG)
	cp pbufwptr, pbufrptr
	breq 2f // No data branch
	mov t1regX, pbufrptr
	inc pbufrptr
	sbrc stereoflag,0
	rjmp stereo_T1OVF
	cpi pbufrptr, PBUFEND
	brne 1f
	ldi pbufrptr, PBUFSTART
1:
	out _SFR_IO_ADDR(SREG), t1reg0
	ld t1reg0, X
	out _SFR_IO_ADDR(OCR1B), t1reg0
	out _SFR_IO_ADDR(OCR1A), t1reg0
	reti

2:
	out _SFR_IO_ADDR(SREG), t1reg0
	reti

stereo_T1OVF:
	inc pbufrptr
	cpi pbufrptr, PBUFEND
	brne 1f
	ldi pbufrptr, PBUFSTART
1:
	out _SFR_IO_ADDR(SREG), t1reg0
	ld t1reg0, X+
	out _SFR_IO_ADDR(OCR1B), t1reg0
	ld t1reg0, X
	out _SFR_IO_ADDR(OCR1A), t1reg0
	reti
	

ioinit:
	cli
	clr invreg0
	clr invreg1
	clr invreg2
	clr zeroreg
	clr stereoflag
	ldi initreg, MYOSCAL
	out _SFR_IO_ADDR(OSCCAL), initreg
	ldi initreg, 0x80
	out _SFR_IO_ADDR(OCR1B), initreg
	out _SFR_IO_ADDR(OCR1A), initreg
	ldi pbufwptr, PBUFSTART
	ldi pbufrptr, PBUFSTART
	out _SFR_IO_ADDR(DDRA), zeroreg 
	out _SFR_IO_ADDR(PORTA), zeroreg
	ldi initreg, 0x0F
	out _SFR_IO_ADDR(DDRB), initreg
	ldi initreg, _BV(6)
	out _SFR_IO_ADDR(PORTB), initreg
	in initreg, _SFR_IO_ADDR(PLLCSR)
	ori initreg, _BV(PLLE)
	out _SFR_IO_ADDR(PLLCSR), initreg
1:
	in initreg, _SFR_IO_ADDR(PLLCSR)
	sbrs initreg, PLOCK
	rjmp 1b
	ori initreg, _BV(PCKE)
	out _SFR_IO_ADDR(PLLCSR), initreg
	ldi initreg, _BV(COM1B1) | _BV(COM1A1) | _BV(PWM1A) |  _BV(PWM1B)
	out _SFR_IO_ADDR(TCCR1A), initreg
	ldi initreg, 0xFF
	out _SFR_IO_ADDR(OCR1C), initreg
	ldi initreg, _BV(CS11) | _BV(CS10)
//	ldi initreg, _BV(CS12)
	out _SFR_IO_ADDR(TCCR1B), initreg
	ldi initreg, _BV(TOIE1)
	out _SFR_IO_ADDR(TIMSK), initreg
	ldi initreg, 0xFF
	out _SFR_IO_ADDR(TIFR), initreg
	in initreg, _SFR_IO_ADDR(MCUCR)
	ori initreg, _BV(ISC01)
	out _SFR_IO_ADDR(MCUCR), initreg
	ldi initreg, _BV(INT0)
	out _SFR_IO_ADDR(GIMSK), initreg
	out _SFR_IO_ADDR(GIFR), initreg
	CLRBUSY
	CLRACK
	// convert init
	rcall convertinit
	ldi initreg, lo8(INRATE)
	mov inratelo, initreg
	ldi initreg, hi8(INRATE)
	mov inratehi, initreg
	ldi initreg, lo8(OUTRATE)
	mov outratelo, initreg
	ldi initreg, hi8(OUTRATE)
	mov outratehi, initreg
	ldi initreg, lo8(OUTINC)
	mov outinclo, initreg
	ldi initreg, hi8(OUTINC)
	mov outinchi, initreg
	reti // sei+ret
