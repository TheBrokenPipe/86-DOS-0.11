;This is a disk boot routine for the 1771/1791 type disk
;controllers.  It would normally reside on track 0,
;sector 1, to be loaded by the "B" command of the
;monitor at address 200H.  By changing the equates
;below, it may be configured to load any size of
;program at any address.  The program is assumed to
;occupy consecutive sectors starting at track 0, sector
;2, and will begin exection at its load address (which
;must be a 16-byte boundary) with the Instruction
;Pointer set to zero.

; Variations are available for the Cromemco 4FDC with
; large disks, the 4FDC with small disks, the Tarbell
; single-density controller, and the Tarbell double-
; density controller. Select one.

CROMEMCOSMALL:	EQU	0
CROMEMCOLARGE:	EQU	1
TARBELLSINGLE:	EQU	0
TARBELLDOUBLE:	EQU	0

LOAD:	EQU	400H	;Address to load program
SEG:	EQU	40H	;LOAD/10H
SECTOR:	EQU	51	;No. of 128-byte sectors to load
BOOTER:	EQU	200H	;"B" command puts booter here

;**************************************************************

CROMEMCO:	EQU	CROMEMCOLARGE+CROMEMCOSMALL
TARBELL:	EQU	TARBELLSINGLE+TARBELLDOUBLE

WD1771:	EQU	CROMEMCO+TARBELLSINGLE
WD1791:	EQU	TARBELLDOUBLE

SMALL:	EQU	CROMEMCOSMALL
LARGE:	EQU	CROMEMCOLARGE+TARBELL

	IF	SMALL
MAXSECT:EQU	18
	ENDIF

	IF	LARGE
MAXSECT:EQU	26
	ENDIF

	IF	TARBELL
DISK:	EQU	78H
	ENDIF

	IF	CROMEMCO
DISK:	EQU	30H
	ENDIF

	IF	WD1771
READCOM:EQU	88H
	ENDIF

	IF	WD1791
READCOM:EQU	80H
	ENDIF

	IF	CROMEMCOLARGE
WAITBYTE:EQU	0B1H
	ENDIF

	IF	CROMEMCOSMALL
WAITBYTE:EQU	0A1H
	ENDIF

	ORG	BOOTER
	PUT	100H

	XOR	AX,AX
	MOV	DS,AX
	MOV	ES,AX
	MOV	SS,AX
	UP
	MOV	DI,LOAD
	MOV	DX,SECTOR
	MOV	BL,2
SECT:
	MOV	AL,BL
	OUTB	DISK+2
	MOV	CX,128

	IF	TARBELL
	INB	DISK		;Get head load status
	ENDIF

	IF	CROMEMCO
	INB	DISK+4		;Get head load status
	ENDIF

	TEST	AL,20H
	MOV	AL,READCOM
	JNZ	OUTCOM
	MOV	AL,READCOM+4
OUTCOM:
	OUTB	DISK

	IF	CROMEMCO
	MOV	AL,WAITBYTE
	OUT	DISK+4		;Turn on hardware wait
	ENDIF

READ:
	INB	DISK+4

	IF	TARBELL
	ROL	AL
	JNC	DONE
	ENDIF

	IF	CROMEMCO
	ROR	AL
	JC	DONE
	ENDIF

	INB	DISK+3
	STOB
	LOOP	READ
GETSTAT:
	INB	DISK+4

	IF	TARBELL
	ROL	AL
	JC	GETSTAT
	ENDIF

	IF	CROMEMCO
	ROR	AL
	JNC	GETSTAT
	ENDIF

DONE:
	IN	DISK
	AND	AL,9CH
	JNZ	SECT
	DEC	DX
	JZ	BOOT
	INC	BL
	CMP	BL,MAXSECT+1
	JNZ	SECT
	XOR	BL,BL
	INC	DX
	MOV	AL,58H		;Step in with update
	OUTB	DISK
	JP	GETSTAT

BOOT:
	MOV	AX,SEG
	MOV	SS,AX
	MOV	ES,AX
	MOV	DS,AX
	JMP	0,SEG
