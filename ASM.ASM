; Seattle Computer Products 8086 Assembler  version 2.00
;   by Tim Paterson
; Runs on the 8086 under 86-DOS

FCB:	EQU	5CH
EOL:	EQU	13	;ASCII carriage return
OBJECT:	EQU	100H	;DEFAULT "PUT" ADDRESS

;System call function codes
PRINTMES: EQU	9
OPEN:	EQU	15
CLOSE:	EQU	16
DELETE:	EQU	19
READ:	EQU	20
SETDMA:	EQU	26
MAKE:	EQU	22
SEQWRT:	EQU	21

;The following equates define some token values returned by GETSYM
UNDEFID:EQU	0	;Undefined identifier (including no nearby RET)
CONST:	EQU	1	;Constant (including $)
REG:	EQU	2	;8-bit register
XREG:	EQU	3	;16-bit register (except segment registers)
SREG:	EQU	4	;Segment register

	ORG	100H
	PUT	100H

	JMP	BEGIN

CPYRHT:	DB	'Copyright 1979 by Seattle Computer Products, Inc.'
	DB	13,10,13,10,'$'

BEGIN:
	MOV	SP,STACK
	MOV	DX,HEADER
	MOV	CL,PRINTMES
	CALL	SYSTEM
	MOV	DX,CPYRHT
	CALL	SYSTEM
	MOV	AL,[FCB+17]
	MOV	[SYMFLG],AL	;Save symbol table request flag
	MOV	BX,FCB+9	;Point to file extension
	MOV	AL,[BX]		;Get source drive letter
	CALL	CHKDSK		;Valid drive?
	OR	AL,AL
	JZ	DEFAULT		;If no extension, use existing drive spec
	MOV	[FCB],AL
DEFAULT:
	INC	BX
	MOV	AL,[BX]		;Get HEX file drive letter
	CMP	AL,'Z'		;Suppress HEX file?
	JZ	L0000
	CALL	CHKDSK
L0000:	
	MOV	[HEXFCB],AL
	INC	BX
	MOV	AL,[BX]		;Get PRN file drive letter
	CMP	AL,'Z'		;Suppress PRN file?
	JZ	NOPRN
	CMP	AL,'X'		;PRN file to console?
	JZ	NOPRN
	CALL	CHKDSK
NOPRN:
	MOV	[LSTFCB],AL
	CALL	ADDEXT
	MOV	DX,FCB
	MOV	CL,OPEN
	CALL	SYSTEM
	MOV	BX,NOFILE
	INC	AL
	JNZ	$+5
	JMP	PRERR
	XOR	AL,AL
	MOV	[FCB+32],AL	;Zero Next Record field
	MOV	DX,HEXFCB
	CALL	MAKFIL
	MOV	DX,LSTFCB
	CALL	MAKFIL
	MOV	BX,0FFH
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]
	MOV	BX,START+1	;POINTER TO NEXT BYTE OF INTERMEDIATE CODE
	MOV	[CODE],BX
	MOV	[IY],START	;POINTER TO CURRENT RELOCATION BYTE
	MOV	BX,0
	MOV	[PC],BX		;DEFAULT PROGRAM COUNTER
	MOV	[BASE],BX	;POINTER TO ROOT OF ID TREE=NIL
	MOV	[RETPT],BX	;Pointer to last RET record
	DEC	BX
	MOV	[LSTRET],BX	;Location of last RET
	MOV	BX,[6]		;HL=END OF MEMORY
	MOV	[HEAP],BX	;BACK END OF SYMBOL TABLE SPACE
	MOV	AL,4
	MOV	[BCOUNT],AL	;CODE BYTES PER RELOCATION BYTE
	XOR	AL,AL
	MOV	[IFFLG],AL	;NOT WITHIN IF/ENDIF
	MOV	[CHKLAB],AL	;LOOKUP ALL LABELS

;Assemble each line of code

LOOP:
	CALL	NEXTCHR		;Get first character on line
	CMP	AL,1AH
	JZ	ENDJ
	MOV	AL,-1		;Flag that no tokens have been read yet
	MOV	[SYM],AL
	CALL	ASMLIN		;Assemble the line
	MOV	AL,[SYM]
	CMP	AL,-1		;Any tokens found on line?
	JNZ	L0002
	CALL	GETSYM		;If no tokens read yet, read first one
L0002:	
	CMP	AL,';'
	JZ	ENDLN
	CMP	AL,EOL
	JZ	ENDLN
	MOV	AL,14H		;Garbage at end of line error
	JP	ENDLIN
ENDJ:	JMP	END

ENDLN:
	XOR	AL,AL		;Flag no errors on line
ENDLIN:
;AL = error code for line. Stack depth unknown
	MOV	SP,STACK
	CALL	NEXLIN
	JP	LOOP

NEXLIN:
	MOV	CH,0C0H		;Put end of line marker and error code (AL)
	CALL	PUTCD
	CALL	GEN1
	MOV	AL,[CHR]
GETEOL:
	CMP	AL,10
	JZ	RET
	CMP	AL,1AH
	JZ	ENDJ
	CALL	NEXTCHR		;Scan over comments for linefeed
	JP	GETEOL

ABORT:
	MOV	BX,NOMEM
PRERR:
	XCHG	DX,BX
	MOV	CL,PRINTMES
	CALL	SYSTEM
	JMP	0

MAKFIL:
	MOV	SI,DX
	LODB			;Get drive select byte
	CMP	AL,20H		;If not valid, don't make file
	JNC	RET
	PUSH	DX
	INC	DX
	MOV	BX,FCB+1
	MOV	CX,8
	UP
	MOV	SI,BX
	MOV	DI,DX
	REP
	MOVB			;Copy source file name
	MOV	DX,DI
	MOV	BX,SI
	POP	DX
	MOV	CL,DELETE
	CALL	SYSTEM
	MOV	CL,MAKE
	CALL	SYSTEM
	MOV	BX,NOSPAC
	INC	AL		;Success?
	JZ	PRERR
	MOV	CL,OPEN
	JMP	SYSTEM

ADDEXT:
	MOV	DX,FCB+9
	MOV	BX,EXTEND	;Set extension to ASM
	MOV	CX,7
	UP
	MOV	SI,BX
	MOV	DI,DX
	REP
	MOVB
	MOV	DX,DI
	MOV	BX,SI
	RET

CHKDSK:
	SUB	AL,' '		;If not present, set zero flag
	JZ	RET
	SUB	AL,20H
	JZ	DSKERR		;Must be in range A-W
	CMP	AL,'X'-'@'
	JC	RET
DSKERR:
	MOV	BX,BADDSK
	JP	PRERR

ERROR:
	MOV	AL,CL
	JMP	ENDLIN

NEXTCHR:
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]
	INC	BL
	JNZ	GETCH
;Buffer empty so refill it
	MOV	DX,80H
	MOV	CL,SETDMA
	CALL	SYSTEM
	XCHG	DX,BX
	MOV	DX,FCB
	MOV	CL,READ
	CALL	SYSTEM
	OR	AL,AL
	MOV	AL,1AH		;Possibly signal End of File
	JNZ	NOMOD		;If nothing read
GETCH:
	MOV	AL,[BX]
NOMOD:
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]
	MOV	[CHR],AL
	RET


MROPS:

; Get two operands and check for certain types, according to flag byte
; in CL. OP code in CH. Returns only if immediate operation.

	PUSH	CX		;Save type flags
	CALL	GETOP
	PUSH	DX		;Save first operand
	CALL	GETOP2
	POP	BX		;First op in BX, second op in DX
	MOV	AL,SREG		;Check for a segment register
	CMP	AL,BH
	JZ	SEGCHK
	CMP	AL,DH
	JZ	SEGCHK
	MOV	AL,CONST	;Check if the first operand is immediate
	MOV	CL,26
	CMP	AL,BH
	JZ	ERROR		;Error if so
	POP	CX		;Restore type flags
	CMP	AL,DH		;If second operand is immediate, then done
	JZ	RET
	MOV	AL,UNDEFID	;Check for memory reference
	CMP	AL,BH
	JZ	STORE		;Is destination memory?
	CMP	AL,DH
	JZ	LOAD		;Is source memory?
	RCR	SI
	TEST	CL,1		;Check if register-to-register operation OK
	RCL	SI
	MOV	CL,27
	JZ	ERROR
	MOV	AL,DH
	CMP	AL,BH		;Registers must be of same length
RR:
	MOV	CL,22
	JNZ	ERROR
RR1:
	AND	AL,1		;Get register length (1=16 bits)
	OR	AL,CH		;Or in to OP code
	CALL	PUT		;And write it
	POP	CX		;Dump return address
	MOV	AL,BL
	ADD	AL,AL		;Rotate register number into middle position
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,0C0H		;Set register-to-register mode
	OR	AL,DL		;Combine with other register number
	JMP	PUT

SEGCHK:
;Come here if at least one operand is a segment register
	POP	CX		;Restore flags
	RCR	SI
	TEST	CL,8		;Check if segment register OK
	RCL	SI
	MOV	CL,22
	JZ	ERR1
	MOV	CX,8E03H	;Segment register move OP code
	MOV	AL,UNDEFID
	CMP	AL,DH		;Check if source is memory
	JZ	LOAD
	CMP	AL,BH		;Check if destination is memory
	JZ	STORE
	MOV	AL,XREG
	SUB	AL,DH		;Check if source is 16-bit register
	JZ	RR		;If so, AL must be zero
	AND	CH,0FDH		;Change direction
	XCHG	DX,BX		;Flip which operand is first and second
	MOV	AL,XREG
	SUB	AL,DH		;Let RR perform finish the test
	JP	RR

STORE:
	TEST	CL,004H		;Check if storing is OK
	JNZ	STERR
	XCHG	DX,BX		;If so, flip operands
	AND	CH,0FDH		;   and zero direction bit
LOAD:
	MOV	DH,25
	CMP	AL,BH		;Check if memory-to-memory
	JZ	MRERR
	MOV	AL,BH
	CMP	AL,REG		;Check if 8-bit operation
	JNZ	XRG
	MOV	DH,22
	TEST	CL,1		;See if 8-bit operation is OK
	JZ	MRERR
XRG:
	MOV	AL,DL
	SUB	AL,6		;Check for R/M mode 6 and register 0
	OR	AL,BL		;   meaning direct load/store of accumulator
	JNZ	NOTAC
	TEST	CL,8		;See if direct load/store of accumulator
	JZ	NOTAC		;   means anything in this case
; Process direct load/store of accumulator
	MOV	AL,CH
	AND	AL,2		;Preserve direction bit only
	XOR	AL,2		;   but flip it
	OR	AL,0A0H		;Combine with OP code
	MOV	CH,AL
	MOV	AL,BH		;Check byte/word operation
	AND	AL,1
	OR	AL,CH
	POP	CX		;Dump return address
	JMP	PUTADD		;Write the address

NOTAC:
	MOV	AL,BH
	AND	AL,1		;Get byte/word bit
	AND	AL,CL		;But don't use it in word-only operations
	OR	AL,CH		;Combine with OP code
	CALL	PUT
	MOV	AL,BL
	ADD	AL,AL		;Rotate to middle position
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,DL		;Combine register field
	POP	CX		;Dump return address
	JMP	PUTADD		;Write the address

STERR:
	MOV	DH,29
MRERR:
	MOV	CL,DH

ERR1:	JMP	ERROR

GETOP2:
;Get the second operand: look for a comma and drop into GETOP
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	CL,21
	JNZ	ERR1


GETOP:

; Get one operand. Operand may be a memory reference in brackets, a register,
; or a constant. If a flag (such as "B" for byte operation) is encountered,
; it is noted and processing continues to find the operand.
;
; On exit, AL (=DH) has the type of operand. Other information depends
; on the actual operand:
;
; AL=DH=0  Memory Reference.  DL has the address mode properly prepared in
; the 8086 R/M format (middle bits zero). The constant part of the address
; is in ADDR. If an undefined label needs to be added to this, a pointer to
; its information fields is in ALABEL, otherwise ALABEL is zero.
;
; AL=DH=1  Value. The constant part is in DATA. If an undefined label needs
; to be added to this, a pointer to its information fields is in DLABEL,
; otherwise DLABEL is zero. "$" and "RET" are in this class.
;
; AL=DH=2  8-bit Register. DL has the register number.
;
; AL=DH=3  16-bit Register. DL has the register number.
;
; AL=DH=4  Segment Register. DL has the register number.

	CALL	GETSYM
GETOP1:
;Enter here if we don't need a GETSYM first
	CMP	AL,'['		;Memory reference?
	JZ	MEM
	CMP	AL,5		;Flag ("B", "W", etc.)?
	JZ	FLG
	CMP	AL,REG		;8-Bit register?
	JZ	NREG
	CMP	AL,XREG		;16-Bit register?
	JZ	NREG
	CMP	AL,SREG		;Segment register?
	JZ	NREG
VAL:				;Must be immediate
	XOR	AL,AL		;No addressing modes allowed
VAL1:
	CALL	GETVAL
	MOV	BX,[CON]	;Defined part
	MOV	[DATA],BX
	MOV	BX,[UNDEF]	;Undefined part
	MOV	[DLABEL],BX
	MOV	DL,CH
	MOV	DH,CONST
	MOV	AL,DH
	RET
NREG:
	PUSH	DX
	CALL	GETSYM
	POP	DX
	MOV	AL,DH
	RET
MEM:
	CALL	GETSYM
	MOV	AL,1
	CALL	GETVAL
	MOV	AL,[SYM]
	CMP	AL,']'
	MOV	CL,24
	JNZ	ERR1
	CALL	GETSYM
	MOV	BX,[CON]
	MOV	[ADDR],BX
	MOV	BX,[UNDEF]
	MOV	[ALABEL],BX
	MOV	DL,CH
	MOV	DH,UNDEFID
	MOV	AL,DH
	RET
FLG:
	CALL	GETSYM
	CMP	AL,','
	JZ	GETOP
	JP	GETOP1


GETVAL:

; Expression analyzer. On entry, if AL=0 then do not allow base or index
; registers. If AL=1, we are analyzing a memory reference, so allow base
; and index registers, and compute addressing mode when done. The constant
; part of the expression will be found in CON. If an undefined label is to
; be added to this, a pointer to its information fields will be found in
; UNDEF.

	LAHF
	XCHG	AX,BP
	SAHF
	PUSH	BX
	MOV	BX,0
	MOV	[CON],BX
	MOV	[UNDEF],BX
	POP	BX
	MOV	AL,[SYM]
	CMP	AL,'+'
	JZ	PLSMNS
	CMP	AL,'-'
	JZ	PLSMNS
	MOV	CH,'+'
	PUSH	CX
	JP	L045C
PLSMNS:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	LAHF
	XCHG	AX,BP
	SAHF
	LAHF
	OR	AL,4		;Flag that a sign was found
	SAHF
	LAHF
	XCHG	AX,BP
	SAHF
	CALL	GETSYM
L045C:
	CMP	AL,1
	JNZ	L0463
	JMP	L0578
L0463:
	CMP	AL,0
	JNZ	L046A
	JMP	L0597
L046A:
	CMP	AL,'"'
	JNZ	L0471
L046E:
	JMP	L0648
L0471:
	CMP	AL,"'"
	JZ	L046E
	CMP	AL,3
	MOV	CL,14H
	JNZ	ERR2
	LAHF
	XCHG	AX,BP
	SAHF
	RCR	SI
	TEST	AL,1
	RCL	SI
	MOV	CL,1
	JZ	ERR2
	LAHF
	XCHG	AX,BP
	SAHF
	MOV	AL,DL
	MOV	CL,3
	CMP	AL,3
	JZ	L04C6
	SUB	AL,5
	JZ	L04D7
	DEC	AL
	MOV	CL,4
	JZ	L04B5
	DEC	AL
	JZ	L04A6
	MOV	CL,2
ERR2:	JMP	ERROR
L04A6:
	LAHF
	XCHG	AX,BP
	SAHF
	RCR	SI
	TEST	AL,10H
	RCL	SI
	JNZ	ERR2
	OR	AL,30H
	JP	L04E4
L04B5:
	LAHF
	XCHG	AX,BP
	SAHF
	RCR	SI
	TEST	AL,10H
	RCL	SI
	JNZ	ERR2
	LAHF
	OR	AL,10H
	SAHF
	JP	L04E4
L04C6:
	LAHF
	XCHG	AX,BP
	SAHF
	RCR	SI
	TEST	AL,80H
	RCL	SI
	JNZ	ERR2
	LAHF
	OR	AL,80H
	SAHF
	JP	L04E4
L04D7:
	LAHF
	XCHG	AX,BP
	SAHF
	RCR	SI
	TEST	AL,80H
	RCL	SI
	JNZ	ERR2
	OR	AL,0C0H
L04E4:
	LAHF
	XCHG	AX,BP
	SAHF
	POP	AX
	XCHG	AH,AL
	SAHF
	CMP	AL,'-'
	MOV	CL,5
	JZ	ERR2
L04F1:
	LAHF
	XCHG	AX,BP
	SAHF
	LAHF
	OR	AL,4
	SAHF
	LAHF
	XCHG	AX,BP
	SAHF
	CALL	GETSYM
	CMP	AL,'+'
	JNZ	L0505
L0502:
	JMP	PLSMNS
L0505:
	CMP	AL,'-'
	JZ	L0502
	LAHF
	XCHG	AX,BP
	SAHF
	MOV	CH,0
	RCR	SI
	TEST	AL,10H
	RCL	SI
	RCL	AL
	JZ	NOIND
	CMC
	RCL	CH
	RCL	AL
	RCL	CH
	RCL	AL
	RCL	CH
L0523:
	MOV	BX,[UNDEF]
	MOV	AL,BH
	OR	AL,BL
	LAHF
	OR	CH,80H
	SAHF
	JNZ	RET3
	MOV	BX,[CON]
	CALL	L055B
	JNZ	RET3
	LAHF
	AND	CH,7FH
	SAHF
	LAHF
	OR	CH,40H
	SAHF
	MOV	AL,BH
	OR	AL,BL
	JNZ	RET3
	MOV	AL,CH
	AND	AL,7
	MOV	CH,AL
	CMP	AL,6
	JNZ	RET3
	LAHF
	OR	CH,40H
	SAHF
RET3:	RET

L055B:
	MOV	AL,BH
	OR	AL,AL
	JZ	L0565
	INC	AL
	JNZ	RET
L0565:
	MOV	AL,BL
	XOR	AL,BH
	AND	AL,80H
	RET

NOIND:
	MOV	CH,6
	JNC	RET
	RCL	AL
	JC	L0523
	INC	CH
	JP	L0523

L0578:
	MOV	BX,[CON]
	POP	AX
	XCHG	AH,AL
	SAHF
	CMP	AL,'-'
	JNZ	L058D
	SBB	BX,DX
L0586:
	MOV	[CON],BX
	JMP	L04F1
L058D:
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	JP	L0586

L0597:
	LAHF
	XCHG	AX,BP
	SAHF
	MOV	CL,6
	RCR	SI
	TEST	AL,8
	RCL	SI
	JNZ	L05B5
	LAHF
	OR	AL,8
	XCHG	AX,BP
	SAHF
	MOV	[UNDEF],BX
	POP	AX
	XCHG	AH,AL
	SAHF
	CMP	AL,'+'
	MOV	CL,5
L05B5:
	JNZ	ERR3
	JMP	L04F1


GETSYM:

; The lexical scanner. Used only in the operand field. Returns with the token
; in SYM and AL, sometimes with additional info in BX or DX.
;
; AL=SYM=0  Undefined label. BX has pointer to information fields.
;
; AL=SYM=1  Constant (or defined label). DX has value.
;
; AL=SYM=2,3,4  8-bit register, 16-bit register, or segment register,
; respectively. DL has register number.
;
; AL=SYM=5  A mode flag (such as "B" for byte operation). Type of flag in DL
; and also stored in FLAG: -1=no flags, 0=B, 1=W, 2=S, 3=L, 4=T.
;
; AL=SYM=6  8087 floating point register, ST(n) or ST. DL has register number.
;
; All other values are the ASCII code of the character. Note that this may
; never be a letter or number.

	CALL	GETSY
	MOV	AL,[SYM]
	RET

SCANB:
	MOV	AL,[CHR]
SCANT:
	CMP	AL,' '
	JZ	NEXB
	CMP	AL,9
	JNZ	RET
NEXB:
	CALL	NEXTCHR
	JP	SCANT

DOLLAR:
	MOV	DX,[OLDPC]
	MOV	AL,CONST
	MOV	[SYM],AL
NEXTCHJ:
	JMP	NEXTCHR

GETSY:
	CALL	SCANB
	CMP	AL,'$'
	JZ	DOLLAR
	MOV	[SYM],AL
	OR	AL,20H
	CMP	AL,'z'+1
	JNC	NEXTCHJ
	CMP	AL,'a'
	JC	$+5
	JMP	LETTER
	CMP	AL,'9'+1
	JNC	NEXTCHJ
	CMP	AL,'0'
	JC	NEXTCHJ
	MOV	BX,SYM
	MOV	B,[BX],CONST
	CALL	READID
	LAHF
	DEC	BX
	SAHF
	MOV	AL,[BX]
	MOV	CL,7
	MOV	BX,0
	CMP	AL,'h'
	JNZ	$+5
	JMP	HEX
	INC	CL
	MOV	[IX],ID
DEC:
	MOV	SI,[IX]
	MOV	AL,[SI]
	INC	[IX]
	CMP	AL,'9'+1
	JC	$+5
ERR3:	JMP	ERROR
	SUB	AL,'0'
	MOV	DX,BX
	SHL	BX
	SHL	BX
	ADD	BX,DX
	SHL	BX
	MOV	DL,AL
	MOV	DH,0
	ADD	BX,DX
	DEC	CH
	JNZ	DEC
	XCHG	DX,BX
	RET

L0648:
	MOV	CH,AL
	MOV	AL,[CHR]
	CMP	AL,CH
	MOV	CL,'#'
	MOV	DL,AL
	MOV	DH,0
	JNZ	L065A
	CALL	L0690
L065A:
	CALL	L0698
	LAHF
	XCHG	AX,BP
	SAHF
	MOV	CL,'%'
	TEST	AL,2
	JZ	ERR3
	TEST	AL,4
	MOV	CL,'&'
	JNZ	ERR3
	LAHF
	XCHG	AX,BP
	SAHF
L066F:
	MOV	AL,DL
	CMP	AL,13
	MOV	CL,"'"
	JZ	ERR3
	CALL	PUT
	MOV	AL,[DATSIZ]
	OR	AL,AL
	JNZ	L0686
	MOV	AL,DH
	CALL	PUT
L0686:
	MOV	AL,[CHR]
	MOV	DL,AL
	CALL	L0698
	JP	L066F

L0690:
	CALL	NEXTCHR
	CMP	AL,CH
	JNZ	ERR3
	RET

L0698:
	CALL	NEXTCHR
	CMP	AL,CH
	JNZ	RET
	CALL	NEXTCHR
	CMP	AL,CH
	JZ	RET
	POP	BX
	JMP	L0578

HEX:
	MOV	DX,ID
	DEC	CH
HEX1:
	MOV	SI,DX
	LODB
	INC	DX
	SUB	AL,'0'
	CMP	AL,10
	JC	GOTIT
	CMP	AL,'g'-'0'
	JNC	ERR4
	SUB	AL,'a'-10-'0'
GOTIT:
	SHL	BX
	SHL	BX
	SHL	BX
	SHL	BX
	ADD	BL,AL
	DEC	CH
	JNZ	HEX1
	XCHG	DX,BX
	RET

ERR4:	JMP	ERROR

GETLET:
	CALL	SCANB
	CMP	AL,EOL
	STC
	JZ	RET
	CMP	AL,';'
	STC
	JZ	RET
	MOV	CL,10
	OR	AL,20H
	CMP	AL,'a'
	JC	ERR4
	CMP	AL,'z'+1
	JNC	ERR4
READID:
	MOV	BX,ID
	MOV	CH,0
MOREID:
	MOV	[BX],AL
	INC	CH
	LAHF
	INC	BX
	SAHF
	CALL	NEXTCHR
	CMP	AL,'0'
	JC	NOMORE
	OR	AL,20H
	CMP	AL,'z'+1
	JNC	NOMORE
	CMP	AL,'9'+1
	JC	MOREID
	CMP	AL,'a'
	JNC	MOREID
NOMORE:
	MOV	CL,AL
	MOV	AL,CH
	MOV	[LENID],AL
	OR	AL,AL
	MOV	AL,CL
	RET

LETTER:
	CALL	READID
	MOV	AL,CH
	DEC	AL
	JNZ	NOFLG
	MOV	AL,[ID]
	CMP	AL,'l'
	MOV	CL,0
	MOV	DX,L1A98
	JZ	SAVFLG
	CMP	AL,'b'
	MOV	DX,FLAG
	JZ	SAVFLG
	CMP	AL,'w'
	MOV	CL,1
	JZ	SAVFLG
	XOR	AL,AL
NOFLG:
	DEC	AL
	PUSH	BX
	JNZ	L0004
	CALL	REGCHK
L0004:	
	POP	BX
	MOV	AL,DH
	JZ	SYMSAV
	CALL	LOOKRET
SYMSAV:
	MOV	[SYM],AL
	RET

SAVFLG:
	XCHG	DX,BX
	MOV	AL,[BX]
	INC	AL
	MOV	[BX],CL
	MOV	CL,32
	JZ	L0760
	JMP	ERROR
L0760:
	MOV	AL,5
	JP	SYMSAV

REGCHK:
	MOV	BX,ID
	MOV	CL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	AL,[BX]
	MOV	BX,REGTAB
	MOV	DH,XREG
	MOV	DL,0
	CMP	AL,'x'
	JZ	SCANREG
	MOV	DH,REG
	CMP	AL,'l'
	JZ	SCANREG
	MOV	DL,4
	CMP	AL,'h'
	JZ	SCANREG
	MOV	DH,SREG
	MOV	DL,0
	MOV	BX,SEGTAB
	CMP	AL,'s'
	JZ	SCANREG
	MOV	DH,XREG
	CMP	AL,'p'
	JZ	PREG
	CMP	AL,'i'
	JNZ	RET
	MOV	DL,6
	MOV	AL,CL
	CMP	AL,'s'
	JZ	RET
	INC	DL
	CMP	AL,'d'
	RET
PREG:
	MOV	DL,4
	MOV	AL,CL
	CMP	AL,'s'
	JZ	RET
	INC	DL
	CMP	AL,'b'
	RET
SCANREG:
	MOV	AL,CL
	MOV	CX,4
	UP
	MOV	DI,BX
	REPNZ
	SCAB
	MOV	BX,DI
	JNZ	RET
	MOV	AL,CL
	ADD	AL,DL
	MOV	DL,AL
	XOR	AL,AL
	RET

REGTAB:	DB	'bdca'

SEGTAB:	DB	'dsce'

LOOK:
	MOV	CH,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DX,ID
	CALL	CPSLP
	JZ	RET
	XOR	AL,80H
	MOV	CL,AL
	LAHF
	DEC	BX
	SAHF
	MOV	AL,[BX]
	XOR	AL,80H
	CMP	AL,CL
	JNC	SMALL
	INC	CH
	INC	CH
SMALL:
	MOV	DL,CH
	MOV	DH,0
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	MOV	AL,DH
	OR	AL,DL
	STC
	JZ	RET
	XCHG	DX,BX
	JP	LOOK

LOOKRET:
	MOV	AL,CH
	CMP	AL,3	;RET has 3 letters
	JNZ	LOOKUP
	LAHF
	DEC	BX
	SAHF
	LAHF
	OR	B,[BX],080H
	SAHF
	MOV	DX,RETSTR+2
CHKRET:
	MOV	SI,DX
	LODB
	CMP	AL,[BX]
	JNZ	LOOKIT
	LAHF
	DEC	BX
	SAHF
	LAHF
	DEC	DX
	SAHF
	DEC	CH
	JNZ	CHKRET
	MOV	DX,[LSTRET]
	MOV	AL,DL
	AND	AL,DH
	INC	AL
	JZ	ALLRET
	MOV	BX,[PC]
	SBB	BX,DX
	CALL	L055B
	MOV	AL,1
	JZ	RET
ALLRET:
	MOV	BX,[RETPT]
	MOV	AL,BH
	OR	AL,BL
	MOV	AL,0
	JNZ	RET
	MOV	BX,[HEAP]
	LAHF
	DEC	BX
	SAHF
	LAHF
	DEC	BX
	SAHF
	LAHF
	DEC	BX
	SAHF
	MOV	[HEAP],BX
	XOR	AL,AL
	MOV	[BX],AL
	MOV	[RETPT],BX
	RET

LOOKUP:
	LAHF
	DEC	BX
	SAHF
	LAHF
	OR	B,[BX],080H
	SAHF
LOOKIT:
	MOV	BX,[BASE]
	MOV	AL,BH
	OR	AL,BL
	JZ	EMPTY
	CALL	LOOK
	JC	ENTER
	MOV	DX,4
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	AL,[BX]
	OR	AL,AL
	JZ	RET
	LAHF
	INC	BX
	SAHF
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	RET

ENTER:
	PUSH	BX		;Save pointer to link field
	CALL	CREATE		;Add the node
	POP	SI
	XCHG	SI,BX
	PUSH	SI
	MOV	[BX],DH		;Link new node
	LAHF
	DEC	BX
	SAHF
	MOV	[BX],DL
	POP	BX
	RET			;Zero was set by CREATE

EMPTY:
	CALL	CREATE
	MOV	[BASE],DX
	RET


CREATE:

; Add a new node to the identifier tree. The identifier is at ID with
; bit 7 of the last character set to one. The length of the identifier is
; in LENID, which is ID-1.
;
; Node format:
;	1. Length of identifier (1 byte)
;	2. Identifier (1-80 bytes)
;	3. Left link (2-byte pointer to alphabetically smaller identifiers)
;	4. Right link (0 if none larger)
;	5. Data field:
;	   a. Defined flag (0=undefined, 1=defined)
;	   b. Value (2 bytes)
;
; This routine returns with AL=zero and zero flag set (which indicates
; on return from LOOKUP that it has not yet been defined), DX points
; to start of new node, and BX points to data field of new node.

	MOV	AL,[LENID]
	ADD	AL,8		;Storage needed for the node
	MOV	BX,[HEAP]
	MOV	DL,AL
	MOV	DH,0
	SBB	BX,DX		;Heap grows downward
	MOV	[HEAP],BX
	XCHG	DX,BX
	MOV	BX,[CODE]	;Check to make sure there's enough
	SBB	BX,DX
	JB	$+5
	JMP	ABORT
	PUSH	DX
	MOV	BX,LENID
	MOV	CL,[BX]
	INC	CL
	MOV	CH,0
	UP
	MOV	SI,BX
	MOV	DI,DX
	REP
	MOVB			;Move identifier and length into node
	MOV	DX,DI
	MOV	BX,SI
	MOV	CH,4
	XCHG	DX,BX
NILIFY:
	MOV	[BX],CL		;Zero left and right links
	INC	BX
	DEC	CH
	JNZ	NILIFY
	XOR	AL,AL		;Set zero flag
	MOV	[BX],AL		;Zero defined flag
	POP	DX		;Restore pointer to node
	RET

CPSLP:
	MOV	SI,DX
	LODB
	CMP	AL,[BX]
	LAHF
	INC	DX
	INC	BX
	SAHF
	JNZ	RET
	DEC	CH
	JNZ	CPSLP
	RET

GETLAB:
	MOV	BX,0
	MOV	[LABPT],BX
	MOV	AL,-1
	MOV	[FLAG],AL
	MOV	[L1A98],AL
	MOV	DH,0
	MOV	AL,[CHR]
	CMP	AL,' '+1
	JC	NOT1
	LAHF
	OR	DH,001H
	SAHF
NOT1:
	CALL	GETLET
	JC	RET
	CMP	AL,':'
	JNZ	LABCHK
	CALL	NEXTCHR
	JP	LABEL
LABCHK:
	OR	AL,AL
	RCR	SI
	TEST	DH,001H
	RCL	SI
	JZ	RET
LABEL:
	MOV	AL,[CHKLAB]
	OR	AL,AL
	JZ	$+5
	JMP	GETLET
	CALL	LOOKUP
	MOV	CL,11
	JNZ	ERR5
	MOV	DX,[PC]
	MOV	B,[BX],1
	LAHF
	INC	BX
	SAHF
	MOV	[BX],DL
	MOV	[LABPT],BX
	LAHF
	INC	BX
	SAHF
	MOV	[BX],DH
	JMP	GETLET

ERR5:	JMP	ERROR

ASMLIN:
	MOV	BX,[PC]
	MOV	[OLDPC],BX
	CALL	GETLAB
	JNC	$+5
	JMP	ENDLN
	MOV	BX,LENID
	MOV	AL,[BX]
	MOV	CL,12
	SUB	AL,2
	MOV	CH,AL
	JC	ERR5
	CMP	AL,5
	JNC	ERR5
	LAHF
	INC	BX
	SAHF
	MOV	AL,[BX]
	SUB	AL,'a'
	MOV	CL,AL
	ADD	AL,AL
	ADD	AL,AL
	ADD	AL,CL
	ADD	AL,CH
	ADD	AL,AL
	MOV	BX,OPTAB
	MOV	DL,AL
	MOV	DH,0
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	XCHG	DX,BX
	INC	CH
	MOV	CL,CH
	MOV	AL,[BX]
	LAHF
	INC	BX
	SAHF
	OR	AL,AL
	JZ	OPERR
FINDOP:
	MOV	CH,CL
	LAHF
	XCHG	AX,BP		;Save count of opcodes in BP
	SAHF
	MOV	DX,ID+1
	CALL	CPSLP
	JZ	HAVOP
	MOV	DH,0
	MOV	DL,CH
	INC	DL
	INC	DL
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	LAHF
	XCHG	AX,BP
	SAHF
	DEC	AL
	JNZ	FINDOP
OPERR:
	MOV	CL,12
	JMP	ERROR

HAVOP:
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	AL,[BX]		;Get opcode
	XCHG	DX,BX
	JMP	BX

GRP1:
	MOV	CX,8A09H
	CALL	MROPS
	MOV	CX,0C6H
	MOV	AL,BH
	CMP	AL,UNDEFID
	JNZ	L0006
	CALL	STIMM
L0006:	
	AND	AL,1
	JZ	BYTIMM
	MOV	AL,0B8H
	OR	AL,BL
	CALL	PUT
	JMP	PUTWOR

BYTIMM:
	MOV	AL,0B0H
	OR	AL,BL
	CALL	PUT
PUTBJ:	JMP	PUTBYT

IMMED:
	MOV	AL,BH
	CMP	AL,UNDEFID
	JZ	STIMM
	MOV	AL,BL
	OR	AL,AL
	JZ	RET
	MOV	AL,BH
	CALL	IMM
	OR	AL,0C0H
	CALL	PUT
FINIMM:
	MOV	AL,CL
	POP	CX
	RCR	SI
	TEST	AL,1
	RCL	SI
	JZ	PUTBJ
	CMP	AL,83H
	JZ	PUTBJ
	JMP	PUTWOR

STIMM:
	MOV	AL,[FLAG]
	CALL	IMM
	CALL	PUTADD
	JP	FINIMM

IMM:
	AND	AL,1
	OR	AL,CL
	MOV	CL,AL
	CALL	PUT
	MOV	AL,CH
	AND	AL,38H
	OR	AL,BL
	RET

PUT:
;Save byte in AL as pure code, with intermediate code bits 00. AL and
;DI destroyed, no other registers affected.
	PUSH	BX
	PUSH	CX
	MOV	CH,0		;Flag as pure code
	CALL	GEN
	POP	CX
	POP	BX
	RET

GEN:
;Save byte of code in AL, given intermediate code bits in bits 7&8 of CH.
	CALL	PUTINC		;Save it and bump code pointer
GEN1:
	MOV	AL,[RELOC]
	RCL	CH
	RCL	AL
	RCL	CH
	RCL	AL
	MOV	[RELOC],AL
	MOV	BX,BCOUNT
	DEC	B,[BX]
	JNZ	RET
	MOV	B,[BX],4
	MOV	BX,RELOC
	MOV	AL,[BX]
	MOV	B,[BX],0
	MOV	DI,[IY]
	MOV	[DI],AL
	MOV	BX,[CODE]
	PUSH	BX
	POP	[IY]
	LAHF
	INC	BX
	SAHF
	MOV	[CODE],BX
	RET

PUTINC:
	PUSH	BX
	MOV	BX,[PC]
	LAHF
	INC	BX
	SAHF
	MOV	[PC],BX
	JP	PUTCD1
PUTCD:
	PUSH	BX
PUTCD1:	MOV	BX,[CODE]
	MOV	[BX],AL
	LAHF
	INC	BX
	SAHF
	MOV	[CODE],BX
	POP	BX
	RET

PUTWOR:
;Save the word value described by [DLABEL] and [DATA] as code. If defined,
;two bytes of pure code will be produced. Otherwise, appropriate intermediate
;code will be generated.
	PUSH	CX
	MOV	CH,80H
	PUSH	DX
	PUSH	BX
	JP	PUTBW

PUTBYT:
;Same as PUTWOR, above, but for byte value.
	PUSH	CX
	MOV	CH,40H
	PUSH	DX
	PUSH	BX
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	PUTBW
	MOV	BX,[DATA]
	OR	AL,BH
	JZ	PUTBW
	INC	BH
	JZ	PUTBW
	MOV	CL,31
	JMP	ERROR
PUTBW:
	MOV	DX,[DLABEL]
	MOV	BX,[DATA]
PUTCHK:
	MOV	AL,DH
	OR	AL,DL
	JZ	NOUNDEF
	MOV	AL,DL
	CALL	PUTCD
	MOV	AL,DH
	CALL	PUTCD
	MOV	AL,BL
	CALL	PUTINC
	MOV	AL,BH
	RCR	SI
	TEST	CH,080H
	RCL	SI
	JZ	SMPUT
	CALL	GEN
	JP	PRET
SMPUT:
	CALL	PUTCD
	CALL	GEN1
PRET:
	POP	BX
	POP	DX
	POP	CX
	RET

NOUNDEF:
	MOV	AL,BL
	MOV	CL,BH
	PUSH	CX
	MOV	CH,0
	CALL	GEN
	POP	CX
	MOV	AL,CL
	RCR	SI
	TEST	CH,080H
	RCL	SI
	MOV	CH,0
	JZ	PRETJ
	CALL	GEN
PRETJ:	JP	PRET

PUTADD:
;Save complete addressing mode. Addressing mode is in AL; if this is a register
;operation (>=C0), then the one byte will be saved as pure code. Otherwise,
;the details of the addressing mode will be investigated and the optional one-
;or two-byte displacement will be added, as described by [ADDR] and [ALABEL].
	PUSH	CX
	PUSH	DX
	PUSH	BX
	MOV	CH,0
	MOV	CL,AL
	CALL	GEN		;Save the addressing mode as pure code
	MOV	AL,CL
	MOV	CH,80H
	AND	AL,0C7H
	CMP	AL,6
	JZ	TWOBT		;Direct address?
	AND	AL,0C0H
	JZ	PRET		;Indirect through reg, no displacement?
	CMP	AL,0C0H
	JZ	PRET		;Register to register operation?
	MOV	CH,AL		;Save whether one- or two-byte displacement
TWOBT:
	MOV	BX,[ADDR]
	MOV	DX,[ALABEL]
	JP	PUTCHK

GRP2:
	CALL	GETOP
	MOV	CX,0FF30H
	CMP	AL,UNDEFID
	JZ	PMEM
	MOV	CH,50H
	CMP	AL,XREG
	JZ	PXREG
	MOV	CH,6
	CMP	AL,SREG
	JNZ	$+5
	JMP	PACKREG
	MOV	CL,20
	JMP	ERROR

PMEM:
	MOV	AL,CH
	CALL	PUT
	MOV	AL,CL
	OR	AL,DL
	JMP	PUTADD

PXREG:
	MOV	AL,CH
	OR	AL,DL
	JMP	PUT

GRP3:
	CALL	GETOP
	PUSH	DX
	CALL	GETOP2
	POP	BX
	MOV	CX,8614H
	MOV	AL,SREG
	CMP	AL,BH
	JZ	ERR6
	CMP	AL,DH
	JZ	ERR6
	MOV	AL,CONST
	CMP	AL,BH
	JZ	ERR6
	CMP	AL,DH
	JZ	ERR6
	MOV	AL,UNDEFID
	CMP	AL,BH
	JZ	EXMEM
	CMP	AL,DH
	JZ	EXMEM1
	MOV	AL,BH
	CMP	AL,DH
	MOV	CL,22
	JNZ	ERR6
	CMP	AL,XREG
	JZ	L0008
	CALL	RR1
L0008:			;RR1 never returns
	MOV	AL,BL
	OR	AL,AL
	JZ	EXACC
	XCHG	DX,BX
	MOV	AL,BL
	OR	AL,AL
	MOV	AL,BH
	JZ	EXACC
	CALL	RR1
EXACC:
	MOV	AL,90H
	OR	AL,DL
	JMP	PUT

EXMEM:
	XCHG	DX,BX
EXMEM1:
	CMP	AL,BH
	JZ	ERR6
	MOV	CL,1	;Flag word as OK
	CALL	NOTAC	;NOTAC never returns
ERR6:	JMP	ERROR

GRP4:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETOP
	POP	CX
	CMP	AL,CONST
	JZ	FIXED
	SUB	AL,XREG
	DEC	DL
	DEC	DL
	OR	AL,DL
	MOV	CL,20
	JNZ	ERR6
	MOV	AL,CH
	OR	AL,8
	JMP	PUT
FIXED:
	MOV	AL,CH
	CALL	PUT
	JMP	PUTBYT

GRP5:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETOP
	CMP	AL,CONST
	JNZ	ERR6
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	MOV	CL,30
	JNZ	ERR6
	MOV	BX,[DATA]
	POP	AX
	XCHG	AH,AL
	SAHF
	OR	AL,AL
	JZ	ORG
	DEC	AL
	JZ	DSJ
	DEC	AL
	JZ	EQU
	DEC	AL
	JZ	$+5
	JMP	IF
PUTOP:
	MOV	AL,-3
	JP	NEWLOC
ALIGN:
	MOV	AL,[PC]
	AND	AL,1
	JZ	RET
	MOV	BX,1
DSJ:
	XCHG	DX,BX
	MOV	BX,[PC]
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	[PC],BX
	XCHG	DX,BX
	MOV	AL,-4
	JP	NEWLOC
EQU:
	XCHG	DX,BX
	MOV	BX,[LABPT]
	MOV	AL,BH
	OR	AL,BL
	MOV	CL,34
	JZ	ERR7
	MOV	[BX],DL
	LAHF
	INC	BX
	SAHF
	MOV	[BX],DH
	RET
ORG:
	MOV	[PC],BX
	MOV	AL,-2
NEWLOC:
	CALL	PUTCD
	MOV	AL,BL
	CALL	PUTCD
	MOV	AL,BH
	CALL	PUTCD
	MOV	CH,0C0H
	JMP	GEN1
GRP6:
	MOV	CH,AL
	MOV	CL,4
	CALL	MROPS
	MOV	CL,23
ERR7:	JMP	ERROR
GRP7:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
	MOV	DX,[DLABEL]
	MOV	AL,DH
	OR	AL,DL
	JNZ	ACCJ
	XCHG	DX,BX
	MOV	BX,[DATA]
	CALL	L055B
	XCHG	DX,BX
	JNZ	ACCJ
	LAHF
	OR	CL,002H
	SAHF
ACCJ:	JMP	ACCIMM
GRP8:
	MOV	CL,AL
	MOV	CH,0FEH
	JP	ONEOP
GRP9:
	MOV	CL,AL
	MOV	CH,0F6H
ONEOP:
	PUSH	CX
	CALL	GETOP
ONE:
	MOV	CL,26
	CMP	AL,CONST
	JZ	ERR7
	CMP	AL,SREG
	MOV	CL,22
	JZ	ERR7
	POP	CX
	CMP	AL,UNDEFID
	JZ	MOP
	AND	AL,1
	JZ	ROP
	RCR	SI
	TEST	CL,001H
	RCL	SI
	JZ	ROP
	MOV	AL,CL
	AND	AL,0F8H
	OR	AL,DL
	JMP	PUT
MOP:
	MOV	AL,[FLAG]
	AND	AL,1
	OR	AL,CH
	CALL	PUT
	MOV	AL,CL
	AND	AL,38H
	OR	AL,DL
	JMP	PUTADD
ROP:
	OR	AL,CH
	CALL	PUT
	MOV	AL,CL
	AND	AL,38H
	OR	AL,0C0H
	OR	AL,DL
	JMP	PUT
GRP10:
	MOV	CL,AL
	MOV	CH,0F6H
	PUSH	CX
	CALL	GETOP
	MOV	CL,20
	MOV	AL,DL
	OR	AL,AL
	JNZ	ERRJ1
	MOV	AL,DH
	CMP	AL,XREG
	JZ	G10
	CMP	AL,REG
ERRJ1:	JNZ	ERR8
G10:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETOP
	POP	AX
	XCHG	AH,AL
	SAHF
	AND	AL,1
	MOV	[FLAG],AL
	MOV	AL,DH
ONEJ:	JP	ONE
GRP11:
	CALL	PUT
	MOV	AL,0AH
	JMP	PUT
GRP12:
	MOV	CL,AL
	MOV	CH,0D0H
	PUSH	CX
	CALL	GETOP
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	AL,DH
	JNZ	ONEJ
	PUSH	DX
	CALL	GETOP
	SUB	AL,REG
	MOV	CL,20
	DEC	DL
	OR	AL,DL
	JNZ	ERR8
	POP	DX
	MOV	AL,DH
	POP	CX
	LAHF
	OR	CH,002H
	SAHF
	PUSH	CX
	JMP	ONE
GRP13:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
ACCIMM:
	CALL	IMMED
	OR	CH,004H
	AND	CH,0FDH
AIMM:
	MOV	AL,BH
	AND	AL,1
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	OR	AL,CH
	CALL	PUT
	POP	AX
	XCHG	AH,AL
	SAHF
	JNZ	$+5
	JMP	PUTBYT
	JMP	PUTWOR

ERR8:	JMP	ERROR

GRP14:
;JMP and CALL mnemonics
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETOP
	CMP	AL,CONST
	JZ	DIRECT
	MOV	CL,20
	CMP	AL,REG
	JZ	ERR8
	CMP	AL,SREG
	JZ	ERR8
	CMP	AL,XREG
	JNZ	NOTRG
	OR	DL,40H
	OR	DL,80H
NOTRG:
;Indirect jump. DL has addressing mode.
	MOV	AL,0FFH
	CALL	PUT
	POP	AX
	XCHG	AH,AL
	SAHF
	AND	AL,38H
	OR	AL,DL
	MOV	CH,AL
	MOV	AL,[L1A98]
	OR	AL,AL
	MOV	AL,CH
	JZ	PUTADDJ		;If so, do inter-segment
	AND	AL,0F7H		;Convert to intra-segment
PUTADDJ:
	JMP	PUTADD
DIRECT:
	MOV	AL,[SYM]
	CMP	AL,','
	JZ	LONGJ
	POP	AX
	XCHG	AH,AL
	SAHF
	DEC	AL
	CMP	AL,0E9H
	JZ	GOTOP
	MOV	AL,0E8H
GOTOP:
	CALL	PUT
	MOV	BX,[DATA]
	MOV	DX,[PC]
	INC	DX
	INC	DX
	SUB	BX,DX
	MOV	[DATA],BX
	JMP	PUTWOR
LONGJ:
	POP	AX
	XCHG	AH,AL
	SAHF
	CALL	PUT
	CALL	PUTWOR
	CALL	GETOP
	MOV	CL,20
	CMP	AL,CONST
	JNZ	ERR8
	JMP	PUTWOR

GRP16:
;RET mnemonic
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETSYM
	CMP	AL,5
	JZ	LONGR
	CMP	AL,EOL
	JZ	NODEC
	CMP	AL,';'
	JZ	NODEC
GETSP:
	CALL	GETOP1
	POP	CX
	CMP	AL,CONST
	MOV	CL,20
	JNZ	ERR9
	MOV	AL,CH
	AND	AL,0FEH
	CALL	PUT
	JMP	PUTWOR
LONGR:
	MOV	AL,[L1A98]
	OR	AL,AL		;Is flag "L"?
	JNZ	NOTLON
	POP	AX
	XCHG	AH,AL
	SAHF
	OR	AL,8
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
NOTLON:
	CALL	GETSYM
	CMP	AL,EOL
	JZ	DORET
	CMP	AL,';'
	JZ	DORET
	CMP	AL,','
	JNZ	L0011
	CALL	GETSYM
L0011:	
	JP	GETSP
NODEC:
;Return is intra-segment (short) without add to SP. 
;Record position for RET symbol.
	MOV	BX,[PC]
	MOV	[LSTRET],BX
	XCHG	DX,BX
	MOV	BX,[RETPT]
	MOV	AL,BH
	OR	AL,BL
	JZ	DORET
	MOV	B,[BX],1
	LAHF
	INC	BX
	SAHF
	MOV	[BX],DL
	LAHF
	INC	BX
	SAHF
	MOV	[BX],DH
	MOV	BX,0
	MOV	[RETPT],BX
DORET:
	POP	AX
	XCHG	AH,AL
	SAHF
	JMP	PUT

GRP17:
	CALL	PUT
	CALL	GETOP
	CMP	AL,CONST
	MOV	CL,20
ERR9:	JNZ	ERR10
	MOV	BX,[DATA]
	MOV	DX,[PC]
	LAHF
	INC	DX
	SAHF
	SBB	BX,DX
	MOV	[DATA],BX
	CALL	PUTBYT
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	RET
	MOV	BX,[DATA]
	CALL	L055B
	JZ	RET
	MOV	CL,31
ERR10:	JMP	ERROR
	RET
GRP18:
	CALL	GETOP
	CMP	AL,CONST
	MOV	CL,20
	JNZ	ERR10
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	GENINT
	MOV	BX,[DATA]
	MOV	DX,3
	SBB	BX,DX
	JNZ	GENINT
	MOV	AL,0CCH
	JMP	PUT
GENINT:
	MOV	AL,0CDH
	CALL	PUT
	JMP	PUTBYT

GRP19:	;ESC opcode
	MOV	CX,0D800H
	JMP	ONEOP

GRP20:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,0F6H
	CALL	IMMED
	MOV	CH,0A8H
	JMP	AIMM
GRP21:
	CALL	GETOP
	CMP	AL,SREG
	MOV	CL,28
	JNZ	ERR10
	MOV	CH,26H
PACKREG:
	MOV	AL,DL
	ADD	AL,AL
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,CH
	JMP	PUT
GRP22:
	CALL	GETOP
	MOV	CX,8F00H
	CMP	AL,UNDEFID
	JNZ	$+5
	JMP	PMEM
	MOV	CH,58H
	CMP	AL,XREG
	JNZ	$+5
	JMP	PXREG
	MOV	CH,7
	CMP	AL,SREG
	JZ	PACKREG
	MOV	CL,20
ERR11:	JMP	ERROR
GRP23:
	MOV	[DATSIZ],AL
GETDAT:
	CALL	GETSYM
	MOV	AL,2
	CALL	VAL1
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	AL,[DATSIZ]
	JNZ	ENDDAT
	CALL	SAVDAT
	JP	GETDAT
ENDDAT:
	CMP	AL,2
	JNZ	SAVDAT
	MOV	BX,[DATA]
	LAHF
	OR	BL,080H
	SAHF
	MOV	[DATA],BX
SAVDAT:
	OR	AL,AL
	JZ	$+5
	JMP	PUTBYT
	JMP	PUTWOR
IF:
	MOV	AL,BH
	OR	AL,BL
	MOV	AL,1
	JZ	SKIPCD
	MOV	[IFFLG],AL
	RET

SKIPCD:
	MOV	[CHKLAB],AL
SKIPLP:
	XOR	AL,AL
	CALL	NEXLIN
	CALL	NEXTCHR
	CMP	AL,1AH
	JZ	END
	CALL	GETLAB
	JC	SKIPLP
	MOV	BX,LENID
	MOV	DX,IFEND
	MOV	CH,[BX]
	INC	CH
	CALL	CPSLP
	JNZ	SKIPLP
	XOR	AL,AL
	MOV	[CHKLAB],AL
	RET

ENDIF:
	MOV	BX,IFFLG
	MOV	AL,[BX]
	MOV	B,[BX],0
	MOV	CL,36
	OR	AL,AL
	JZ	ERR11
	RET

;*********************************************************************
;
;	PASS 2
;
;*********************************************************************

END:
	MOV	CL,4
WREND:
	MOV	CH,0FFH
	MOV	AL,CH
	CALL	GEN
	DEC	CL
	JNZ	WREND
	MOV	AL,[LSTFCB]
	CMP	AL,'Z'
	JZ	L1033
	CALL	ADDEXT
	MOV	DX,FCB
	MOV	CL,OPEN
	CALL	SYSTEM
	MOV	BX,0FFH
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]
L1033:
	MOV	AL,-5
	MOV	[HEXCNT],AL	;FLAG HEX BUFFER AS EMPTY
	MOV	[L1B0E],AL
	MOV	BX,HEXBUF
	MOV	[HEXPNT],BX
	MOV	BX,LSTBUF
	MOV	[LSTPNT],BX
	MOV	BX,0
	MOV	[ERRCNT],BX
	MOV	[PC],BX
	MOV	BX,OBJECT
	MOV	[HEXADD],BX
	XOR	AL,AL
	MOV	[FCB+20H],AL	;Set NEXT RECORD field to zero
	MOV	[COUNT],AL
	CALL	STRTLIN
	MOV	BX,START
L1069:
	MOV	CH,4
	MOV	CL,[BX]
	LAHF
	INC	BX
	SAHF
L1070:
	RCL	CL
	JC	L1087
	RCL	CL
	JNC	L107B
	JMP	L1108
L107B:
	MOV	AL,[BX]
L107D:
	CALL	L13BB
L1080:
	INC	BX
	DEC	CH
	JNZ	L1070
	JP	L1069
L1087:
	RCL	CL
	JC	L108E
	JMP	L1144
L108E:
	MOV	AL,[BX]
	CMP	AL,-10
	JB	L1097
	JMP	L1214
L1097:
	PUSH	CX
	PUSH	BX
	MOV	BX,COUNT
	MOV	AL,6
	SUB	AL,[BX]
	MOV	B,[BX],0
	MOV	CH,AL
	MOV	AL,' '
	JZ	NOFIL
BLNK:
	CALL	LIST
	CALL	LIST
	CALL	LIST
	DEC	CH
	JNZ	BLNK
NOFIL:
	CALL	OUTLIN
	POP	BX
	MOV	AL,[BX]
	PUSH	BX
	CALL	REPERR
	MOV	AL,[ERR]
	CALL	REPERR
	CALL	STRTLIN
	POP	BX
	POP	CX
	JP	L1080

OUTLIN:
	CALL	LIST
	MOV	AL,[LSTFCB]
	CMP	AL,'Z'
	JZ	RET2
	MOV	BX,L1B0F
	MOV	AL,[BX]
	MOV	B,[BX],0FFH
	OR	AL,AL
	JNZ	CRLF
OUTLN:
	CALL	NEXTCHR
	CALL	LIST
	CMP	AL,10
	JNZ	OUTLN
RET2:	RET

PRTCNT:
	MOV	BX,ERCNTM
	CALL	PRINT
	MOV	BX,[ERRCNT]
	CALL	L1362
	CALL	L1384
CRLF:
	MOV	AL,13
	CALL	LIST
	MOV	AL,10
	JMP	LIST

L1108:
	CALL	L1151
	XCHG	DX,BX
	CALL	L055B
	XCHG	DX,BX
	JZ	L1123
	MOV	AL,DH
	OR	AL,AL
	JZ	L1128
	INC	AL
	JZ	L1128
L111E:
	MOV	AL,101
	MOV	[ERR],AL
L1123:
	MOV	AL,DL
	JMP	L107D
L1128:
	MOV	AL,[COUNT]
	DEC	AL
	JNZ	L1123
	MOV	AL,[L1B10]
	CMP	AL,0EBH
	JZ	L111E
	AND	AL,0FCH
	CMP	AL,0E0H
	JZ	L111E
	AND	AL,0F0H
	CMP	AL,70H
	JZ	L111E
	JP	L1123

L1144:
	CALL	L1151
	MOV	AL,DL
	CALL	L13BB
	MOV	AL,DH
	JMP	L107D

L1151:
	PUSH	CX
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	LAHF
	INC	BX
	SAHF
	XCHG	DX,BX
	MOV	AL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	CL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	CH,[BX]
	XCHG	DX,BX
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	XCHG	DX,BX
	LAHF
	ADD	BX,CX
	RCR	SI
	SAHF
	RCL	SI
	POP	CX
	XCHG	DX,BX
	OR	AL,AL
	JNZ	RET1
	MOV	AL,64H
	MOV	[ERR],AL
	MOV	DX,0
RET1:	RET

STRTLIN:
	XOR	AL,AL
	MOV	[ERR],AL
	MOV	[L1B0F],AL
	MOV	BX,[PC]
	MOV	AL,BH
	CALL	PHEX
	MOV	AL,BL
PHEXB:
	CALL	PHEX
	MOV	AL,' '
LIST:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	MOV	AL,[LSTFCB]
	CMP	AL,'Z'
	JZ	L11ED
	CMP	AL,'X'
	JZ	L11F2
	POP	AX
	XCHG	AH,AL
	SAHF
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	AND	AL,7FH
	PUSH	BX
	MOV	BX,[LSTPNT]
	MOV	[BX],AL
	CALL	L1546
	MOV	[LSTPNT],BX
	JNZ	L11EC
	MOV	BX,LSTBUF
	MOV	[LSTPNT],BX
	PUSH	DX
	XCHG	DX,BX
	PUSH	CX
	MOV	CL,SETDMA
	CALL	5
	MOV	DX,LSTFCB
	MOV	CL,SEQWRT
	CALL	5
	POP	CX
	POP	DX
L11EC:
	POP	BX
L11ED:
	POP	AX
	XCHG	AH,AL
	SAHF
	RET
L11F2:
	POP	AX
	XCHG	AH,AL
	SAHF
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	OUT
	POP	AX
	XCHG	AH,AL
	SAHF
	RET

PHEX:
	MOV	CH,AL
	CALL	UHALF
	CALL	LIST
	MOV	AL,CH
	CALL	LHALF
	JMP	LIST

L1214:
	INC	AL
	JZ	L125B
	LAHF
	INC	BX
	SAHF
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	PUSH	BX
	INC	AL
	JZ	L1253
	INC	AL
	JZ	L124D
	MOV	BX,[PC]
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	[PC],BX
	MOV	BX,[HEXADD]
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	[HEXADD],BX
	JP	L1257
L124D:
	MOV	[HEXADD],DX
	JP	L1257
L1253:
	MOV	[PC],DX
L1257:
	POP	BX
	JMP	L1080
L125B:
	CALL	PRTCNT
	MOV	AL,[HEXFCB]
	CMP	AL,'Z'
	JZ	SYMDMP
	MOV	AL,[HEXCNT]
	CMP	AL,-5
	JZ	L126F
	CALL	ENHEXL
L126F:
	MOV	AL,':'
	CALL	PUTCHR
	MOV	CH,10
L1276:
	PUSH	CX
	MOV	AL,'0'
	CALL	PUTCHR
	POP	CX
	DEC	CH
	JNZ	L1276
	CALL	L14F4
	JZ	L1289
	CALL	L13B3
L1289:
	CALL	L13B3
	MOV	CL,CLOSE
	MOV	DX,HEXFCB
	CALL	SYSTEM
SYMDMP:
	MOV	AL,[SYMFLG]
	CMP	AL,'S'
	JNZ	L12B4
	MOV	BX,SYMMES
	CALL	PRINT
	MOV	DX,[BASE]
	MOV	AL,DH
	OR	AL,DL
	JZ	EXIT
	MOV	BX,[HEAP]
	MOV	SP,BX
	CALL	L12E5
L12B4:
	MOV	AL,[LSTFCB]
	CMP	AL,'X'
	JZ	EXIT
	CMP	AL,'Z'
	JZ	L12CA
	CALL	L12D6
	MOV	DX,LSTFCB
	MOV	CL,CLOSE
	CALL	5
L12CA:
	MOV	AL,'X'
	MOV	[LSTFCB],AL
	CALL	PRTCNT
EXIT:	JMP	0
	RET

L12D6:
	MOV	AX,[LSTPNT]
	CMP	AX,LSTBUF
	JZ	RET
	MOV	AL,1AH
	CALL	LIST
	JP	L12D6

L12E5:
	XCHG	DX,BX
	PUSH	BX
	MOV	DL,[BX]
	MOV	DH,0
	LAHF
	INC	BX
	SAHF
	LAHF
	ADD	BX,DX
	RCR	SI
	SAHF
	RCL	SI
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	MOV	AL,DL
	OR	AL,DH
	JZ	L1307
	CALL	L12E5
L1307:
	POP	BX
	MOV	CH,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	AL,0AH
	SUB	AL,CH
	JNB	L1315
	MOV	AL,1
L1315:
	MOV	DH,AL
L1317:
	MOV	AL,[BX]
	LAHF
	INC	BX
	SAHF
	CALL	LIST
	DEC	CH
	JNZ	L1317
	MOV	CH,DH
	INC	CH
	MOV	AL,20H
L1329:
	CALL	LIST
	DEC	CH
	JNZ	L1329
	LAHF
	INC	BX
	SAHF
	LAHF
	INC	BX
	SAHF
	PUSH	BX
	LAHF
	INC	BX
	SAHF
	LAHF
	INC	BX
	SAHF
	LAHF
	INC	BX
	SAHF
	LAHF
	INC	BX
	SAHF
	MOV	AL,[BX]
	CALL	PHEX
	LAHF
	DEC	BX
	SAHF
	MOV	AL,[BX]
	CALL	PHEX
	CALL	CRLF
	POP	BX
	MOV	DL,[BX]
	LAHF
	INC	BX
	SAHF
	MOV	DH,[BX]
	MOV	AL,DH
	OR	AL,DL
	JNZ	L12E5
	RET

L1362:
	MOV	CH,10H
	MOV	DX,0
L1367:
	LAHF
	ADD	BX,BX
	RCR	SI
	SAHF
	RCL	SI
	MOV	AL,DL
	ADC	AL,AL
	DAA
	MOV	DL,AL
	MOV	AL,DH
	ADC	AL,AL
	DAA
	MOV	DH,AL
	RCL	CL
	DEC	CH
	JNZ	L1367
	RET

L1384:
	XCHG	DX,BX
	MOV	CH,10H
	MOV	AL,CL
	CALL	L13A0
	MOV	AL,BH
	CALL	L13AE
	MOV	AL,BH
	CALL	L13A0
	MOV	AL,BL
	CALL	L13AE
	MOV	AL,BL
	MOV	CH,0
L13A0:
	CALL	LHALF
L13A3:
	CMP	AL,30H
	JZ	L13A9
	MOV	CH,0
L13A9:
	SUB	AL,CH
	JMP	LIST

L13AE:
	CALL	UHALF
	JP	L13A3

L13B3:
	MOV	AL,1AH
	CALL	PUTCHR
	JNZ	L13B3
	RET

L13BB:
	MOV	[L1B10],AL
	PUSH	BX
	PUSH	CX
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	PUSH	DX
	CALL	L144E
	POP	DX
	MOV	BX,COUNT
	INC	B,[BX]
	MOV	AL,[BX]
	CMP	AL,7
	JNZ	L13E9
	MOV	B,[BX],1
	MOV	AL,20H
	CALL	OUTLIN
	MOV	AL,20H
	MOV	CH,5
L13E2:
	CALL	LIST
	DEC	CH
	JNZ	L13E2
L13E9:
	POP	AX
	XCHG	AH,AL
	SAHF
	CALL	PHEXB
	POP	CX
	MOV	BX,[PC]
	LAHF
	INC	BX
	SAHF
	MOV	[PC],BX
	MOV	BX,[HEXADD]
	LAHF
	INC	BX
	SAHF
	MOV	[HEXADD],BX
	POP	BX
	RET

REPERR:
	OR	AL,AL		;Did an error occur?
	JZ	RET
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	MOV	BX,ERRMES	;Print "ERROR"
	CALL	PRINT
	POP	AX
	XCHG	AH,AL
	SAHF
	CALL	PHEX
	MOV	BX,HEXSUF
	CALL	PRINT
	MOV	BX,[ERRCNT]
	LAHF
	INC	BX
	SAHF
	MOV	[ERRCNT],BX
	RET

PRINT:
	MOV	AL,[BX]
	CALL	LIST
	OR	AL,AL
	JS	RET
	LAHF
	INC	BX
	SAHF
	JP	PRINT

OUT:
	MOV	DL,AL
	MOV	CL,2
SYSTEM:
	PUSH	CX
	PUSH	DX
	PUSH	BX
	CALL	5
	POP	BX
	POP	DX
	POP	CX
	RET

L144E:
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	MOV	AL,[HEXFCB]
	CMP	AL,'Z'
	JNZ	L145E
	JMP	L11ED
L145E:
	MOV	DX,[LASTAD]
	MOV	BX,[HEXADD]
	MOV	[LASTAD],BX
	LAHF
	INC	DX
	SAHF
	MOV	AL,[HEXCNT]
	CMP	AL,-5
	JZ	NEWLIN
	OR	AL,AL
	SBB	BX,DX
	JZ	AFHEX
	CALL	ENHEXL
NEWLIN:
	MOV	AL,':'
	CALL	PUTCHR
	MOV	AL,-4
	MOV	[HEXCNT],AL
	XOR	AL,AL
	MOV	[CHKSUM],AL
	MOV	BX,[HEXPNT]
	MOV	[HEXLEN],BX
	CALL	HEXBYT
	MOV	AL,[HEXADD+1]
	CALL	HEXBYT
	MOV	AL,[HEXADD]
	CALL	HEXBYT
	XOR	AL,AL
	CALL	HEXBYT
AFHEX:
	POP	AX
	XCHG	AH,AL
	SAHF
HEXBYT:
	MOV	CH,AL
	MOV	BX,CHKSUM
	ADD	AL,[BX]
	MOV	[BX],AL
	MOV	AL,CH
	CALL	UHALF
	CALL	PUTCHR
	MOV	AL,CH
	CALL	LHALF
	CALL	PUTCHR
	MOV	BX,HEXCNT
	INC	B,[BX]
	MOV	AL,[BX]
	CMP	AL,26
	JNZ	RET
ENHEXL:
	MOV	BX,[HEXLEN]
	MOV	CH,AL
	CALL	UHALF
	MOV	[BX],AL
	CALL	L1546
	MOV	AL,CH
	CALL	LHALF
	MOV	[BX],AL
	MOV	AL,-6
	MOV	[HEXCNT],AL
	MOV	AL,[CHKSUM]
	ADD	AL,CH
	NEG	AL
	CALL	HEXBYT

L14F4:
	MOV	AL,13
	CALL	PUTCHR
	MOV	AL,10

PUTCHR:
	MOV	BX,[HEXPNT]
	MOV	[BX],AL
	CALL	L1546
	MOV	[HEXPNT],BX
	JNZ	RET
	PUSH	BX
	MOV	BX,L1B0E
	MOV	AL,[BX]
	MOV	B,[BX],0
	POP	BX
	OR	AL,AL
	JNZ	RET
	MOV	CL,SETDMA
	XCHG	DX,BX
	CALL	SYSTEM
	MOV	DX,HEXFCB
	MOV	CL,SEQWRT
	CALL	SYSTEM
	XCHG	DX,BX
	OR	AL,AL
	JZ	RET
	MOV	BX,WRTERR
	JMP	PRERR

UHALF:
	RCR	AL
	RCR	AL
	RCR	AL
	RCR	AL
LHALF:
	AND	AL,0FH
	OR	AL,30H
	CMP	AL,'9'+1
	JC	RET
	ADD	AL,7
RET:	RET

L1546:
	INC	BX
	CMP	BX,HEXBUF+128
	JZ	RET
	CMP	BX,LSTBUF+128
	JZ	RET
	CMP	BX,L1B9B+128
	JNZ	RET
	MOV	BX,HEXBUF
	RET

NONE:	DB	0

; 8086 MNEMONIC TABLE

; This table is actually a sequence of subtables, each starting with a label.
; The label signifies which mnemonics the subtable applies to--A3, for example,
; means all 3-letter mnemonics beginning with A.

A3:
	DB	7
	DB	'dd'
	DW	GRP7
	DB	2
	DB	'nd'
	DW	GRP13
	DB	22H
	DB	'dc'
	DW	GRP7
	DB	12H
	DB	'aa'
	DW	PUT
	DB	37H
	DB	'as'
	DW	PUT
	DB	3FH
	DB	'am'
	DW	GRP11
	DB	0D4H
	DB	'ad'
	DW	GRP11
	DB	0D5H
A5:
	DB	1
	DB	'lign'
	DW	ALIGN
	DB	0
C3:
	DB	7
	DB	'mp'
	DW	GRP7
	DB	3AH
	DB	'lc'
	DW	PUT
	DB	0F8H
	DB	'ld'
	DW	PUT
	DB	0FCH
	DB	'li'
	DW	PUT
	DB	0FAH
	DB	'mc'
	DW	PUT
	DB	0F5H
	DB	'bw'
	DW	PUT
	DB	98H
	DB	'wd'
	DW	PUT
	DB	99H
C4:
	DB	3
	DB	'all'
	DW	GRP14
	DB	9AH
	DB	'mpb'
	DW	PUT
	DB	0A6H
	DB	'mpw'
	DW	PUT
	DB	0A7H
D2:
	DB	5
	DB	'b'
	DW	GRP23
	DB	1
	DB	'w'
	DW	GRP23
	DB	0
	DB	'm'
	DW	GRP23
	DB	2
	DB	's'
	DW	GRP5
	DB	1
	DB	'i'
	DW	PUT
	DB	0FAH
D3:
	DB	4
	DB	'ec'
	DW	GRP8
	DB	49H
	DB	'iv'
	DW	GRP10
	DB	30H
	DB	'aa'
	DW	PUT
	DB	27H
	DB	'as'
	DW	PUT
	DB	2FH
D4:
	DB	1
	DB	'own'
	DW	PUT
	DB	0FDH
E2:
	DB	1
	DB	'i'
	DW	PUT
	DB	0FBH
E3:
	DB	3
	DB	'qu'
	DW	GRP5
	DB	2
	DB	'sc'
	DW	GRP19
	DB	0D8H
	DB	'nd'
	DW	END
	DB	0
E5:
	DB	1
	DB	'ndif'
	DW	ENDIF
	DB	0
H3:
	DB	1
	DB	'lt'
	DW	PUT
	DB	0F4H
H4:
	DB	1
	DB	'alt'
	DW	PUT
	DB	0F4H
I2:
	DB	2
	DB	'n'
	DW	GRP4
	DB	0E4H
	DB	'f'
	DW	GRP5
	DB	4
I3:
	DB	4
	DB	'nc'
	DW	GRP8
	DB	41H
	DB	'nb'
	DW	GRP4
	DB	0E4H
	DB	'nw'
	DW	GRP4
	DB	0E5H
	DB	'nt'
	DW	GRP18
	DB	0CCH
I4:
	DB	4
	DB	'mul'
	DW	GRP10
	DB	28H
	DB	'div'
	DW	GRP10
	DB	38H
	DB	'ret'
	DW	PUT
	DB	0CFH
	DB	'nto'
	DW	PUT
	DB	0CEH
J2:
	DB	10
	DB	'p'
	DW	GRP17
	DB	0EBH
	DB	'z'
	DW	GRP17
	DB	74H
	DB	'e'
	DW	GRP17
	DB	74H
	DB	'l'
	DW	GRP17
	DB	7CH
	DB	'b'
	DW	GRP17
	DB	72H
	DB	'a'
	DW	GRP17
	DB	77H
	DB	'g'
	DW	GRP17
	DB	7FH
	DB	'o'
	DW	GRP17
	DB	70H
	DB	's'
	DW	GRP17
	DB	78H
	DB	'c'
	DW	GRP17
	DB	72H
J3:
	DB	17
	DB	'mp'
	DW	GRP14
	DB	0EAH
	DB	'nz'
	DW	GRP17
	DB	75H
	DB	'ne'
	DW	GRP17
	DB	75H
	DB	'nl'
	DW	GRP17
	DB	7DH
	DB	'ge'
	DW	GRP17
	DB	7DH
	DB	'nb'
	DW	GRP17
	DB	73H
	DB	'ae'
	DW	GRP17
	DB	73H
	DB	'nc'
	DW	GRP17
	DB	73H
	DB	'ng'
	DW	GRP17
	DB	7EH
	DB	'le'
	DW	GRP17
	DB	7EH
	DB	'na'
	DW	GRP17
	DB	76H
	DB	'be'
	DW	GRP17
	DB	76H
	DB	'pe'
	DW	GRP17
	DB	7AH
	DB	'np'
	DW	GRP17
	DB	7BH
	DB	'po'
	DW	GRP17
	DB	7BH
	DB	'no'
	DW	GRP17
	DB	71H
	DB	'ns'
	DW	GRP17
	DB	79H
J4:
	DB	5
	DB	'cxz'
	DW	GRP17
	DB	0E3H
	DB	'nge'
	DW	GRP17
	DB	7CH
	DB	'nae'
	DW	GRP17
	DB	72H
	DB	'nbe'
	DW	GRP17
	DB	77H
	DB	'nle'
	DW	GRP17
	DB	7FH
L3:
	DB	3
	DB	'ea'
	DW	GRP6
	DB	8DH
	DB	'ds'
	DW	GRP6
	DB	0C5H
	DB	'es'
	DW	GRP6
	DB	0C4H
L4:
	DB	5
	DB	'oop'
	DW	GRP17
	DB	0E2H
	DB	'odb'
	DW	PUT
	DB	0ACH
	DB	'odw'
	DW	PUT
	DB	0ADH
	DB	'ahf'
	DW	PUT
	DB	9FH
	DB	'ock'
	DW	PUT
	DB	0F0H
L5:
	DB	2
	DB	'oope'
	DW	GRP17
	DB	0E1H
	DB	'oopz'
	DW	GRP17
	DB	0E1H
L6:
	DB	2
	DB	'oopne'
	DW	GRP17
	DB	0E0H
	DB	'oopnz'
	DW	GRP17
	DB	0E0H
M3:
	DB	2
	DB	'ov'
	DW	GRP1
	DB	88H
	DB	'ul'
	DW	GRP10
	DB	20H
M4:
	DB	2
	DB	'ovb'
	DW	PUT
	DB	0A4H
	DB	'ovw'
	DW	PUT
	DB	0A5H
N3:
	DB	3
	DB	'ot'
	DW	GRP9
	DB	10H
	DB	'eg'
	DW	GRP9
	DB	18H
	DB	'op'
	DW	PUT
	DB	90H
O2:
	DB	1
	DB	'r'
	DW	GRP13
	DB	0AH
O3:
	DB	2
	DB	'ut'
	DW	GRP4
	DB	0E6H
	DB	'rg'
	DW	GRP5
	DB	0
O4:
	DB	2
	DB	'utb'
	DW	GRP4
	DB	0E6H
	DB	'utw'
	DW	GRP4
	DB	0E7H
P3:
	DB	2
	DB	'op'
	DW	GRP22
	DB	8FH
	DB	'ut'
	DW	GRP5
	DB	3
P4:
	DB	2
	DB	'ush'
	DW	GRP2
	DB	0FFH
	DB	'opf'
	DW	PUT
	DB	9DH
P5:
	DB	1
	DB	'ushf'
	DW	PUT
	DB	9CH
R3:
	DB	6
	DB	'et'
	DW	GRP16
	DB	0C3H
	DB	'ep'
	DW	PUT
	DB	0F3H
	DB	'ol'
	DW	GRP12
	DB	0
	DB	'or'
	DW	GRP12
	DB	8
	DB	'cl'
	DW	GRP12
	DB	10H
	DB	'cr'
	DW	GRP12
	DB	18H
R4:
	DB	2
	DB	'epz'
	DW	PUT
	DB	0F3H
	DB	'epe'
	DW	PUT
	DB	0F3H
R5:
	DB	2
	DB	'epnz'
	DW	PUT
	DB	0F2H
	DB	'epne'
	DW	PUT
	DB	0F2H
S3:
	DB	11
	DB	'ub'
	DW	GRP7
	DB	2AH
	DB	'bb'
	DW	GRP7
	DB	1AH
	DB	'bc'
	DW	GRP7
	DB	1AH
	DB	'tc'
	DW	PUT
	DB	0F9H
	DB	'td'
	DW	PUT
	DB	0FDH
	DB	'ti'
	DW	PUT
	DB	0FBH
	DB	'hl'
	DW	GRP12
	DB	20H
	DB	'hr'
	DW	GRP12
	DB	28H
	DB	'al'
	DW	GRP12
	DB	20H
	DB	'ar'
	DW	GRP12
	DB	38H
	DB	'eg'
	DW	GRP21
	DB	26H
S4:
	DB	5
	DB	'cab'
	DW	PUT
	DB	0AEH
	DB	'caw'
	DW	PUT
	DB	0AFH
	DB	'tob'
	DW	PUT
	DB	0AAH
	DB	'tow'
	DW	PUT
	DB	0ABH
	DB	'ahf'
	DW	PUT
	DB	9EH
T4:
	DB	1
	DB	'est'
	DW	GRP20
	DB	84H
U2:
	DB	1
	DB	'p'
	DW	PUT
	DB	0FCH
W4:
	DB	1
	DB	'ait'
	DW	PUT
	DB	9BH
X3:
	DB	1
	DB	'or'
	DW	GRP13
	DB	32H
X4:
	DB	2
	DB	'chg'
	DW	GRP3
	DB	86H
	DB	'lat'
	DW	PUT
	DB	0D7H


OPTAB:
; Table of pointers  to mnemonics. For each letter of the alphabet (the
; starting letter of the mnemonic), there are 5 entries. Each entry
; corresponds to a mnemonic whose length is 2, 3, 4, 5, and 6 characters
; long, respectively. If there are no mnemonics for a given combination
; of first letter and length (such as A-2), then the corresponding entry
; points to NONE. Otherwise, it points to a place in the mnemonic table
; for that type.

; This table only needs to be modified if a mnemonic is added to a group
; previously marked NONE. Change the NONE to a label made up of the first
; letter of the mnemonic and its length, then add a new subsection to
; the mnemonic table in alphabetical order.

	DW	NONE
	DW	A3
	DW	NONE
	DW	A5
	DW	NONE
	DW	NONE	;B
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;C
	DW	C3
	DW	C4
	DW	NONE
	DW	NONE
	DW	D2	;D
	DW	D3
	DW	D4
	DW	NONE
	DW	NONE
	DW	E2	;E
	DW	E3
	DW	NONE
	DW	E5
	DW	NONE
	DW	NONE	;F
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;G
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;H
	DW	H3
	DW	H4
	DW	NONE
	DW	NONE
	DW	I2	;I
	DW	I3
	DW	I4
	DW	NONE
	DW	NONE
	DW	J2	;J
	DW	J3
	DW	J4
	DW	NONE
	DW	NONE
	DW	NONE	;K
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;L
	DW	L3
	DW	L4
	DW	L5
	DW	L6
	DW	NONE	;M
	DW	M3
	DW	M4
	DW	NONE
	DW	NONE
	DW	NONE	;N
	DW	N3
	DW	NONE
	DW	NONE
	DW	NONE
	DW	O2	;O
	DW	O3
	DW	O4
	DW	NONE
	DW	NONE
	DW	NONE	;P
	DW	P3
	DW	P4
	DW	P5
	DW	NONE
	DW	NONE	;Q
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;R
	DW	R3
	DW	R4
	DW	R5
	DW	NONE
	DW	NONE	;S
	DW	S3
	DW	S4
	DW	NONE
	DW	NONE
	DW	NONE	;T
	DW	NONE
	DW	T4
	DW	NONE
	DW	NONE
	DW	U2	;U
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;V
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;W
	DW	NONE
	DW	W4
	DW	NONE
	DW	NONE
	DW	NONE	;X
	DW	X3
	DW	X4
	DW	NONE
	DW	NONE
	DW	NONE	;Y
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;Z
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE

HEADER:	DB	13,10,'Seattle Computer Products 8086 Assembler Version 2.00',13,10,'$'
ERRMES:	DM	'***** ERROR no. '
NOSPAC:	DB	13,10,'No directory space',13,10,'$'
HEXSUF:	DM	'H',13,10
NOMEM:	DB	13,10,'Insufficient memory',13,10,'$'
NOFILE:	DB	13,10,'File not found',13,10,'$'
WRTERR:	DB	13,10,'Disk write error',13,10,'$'
BADDSK:	DB	13,10,'Bad disk specifier',13,10,'$'
ERCNTM:	DM	13,10,13,10,'Error Count ='
SYMMES:	DM	13,10,'Symbol Table',13,10,13,10
EXTEND:	DB	'ASM',0,0,0,0
IFEND:	DB	5,'endif'
RETSTR:	DM	'ret'
HEXFCB:	DB	0,'        HEX',0,0,0,0
	DS	16
	DB	0
LSTFCB:	DB	0,'        PRN',0,0,0,0
	DS	16
	DB	0
PC:	DS	2
OLDPC:	DS	2
LABPT:	DS	2
FLAG:	DS	1
L1A98:	DS	1
ADDR:	DS	2
ALABEL:	DS	2
DATA:	DS	2
DLABEL:	DS	2
CON:	DS	2
UNDEF:	DS	2
LENID:	DS	1
ID:	DS	80
CHR:	DS	1
SYM:	DS	1
BASE:	DS	2
HEAP:	DS	2
SYMFLG:	DS	1
CODE:	DS	2
DATSIZ:	DS	1
RELOC:	DS	1
BCOUNT:	DS	1
COUNT:	DS	1
ERR:	DS	1
HEXPNT:	DS	2
HEXLEN:	DS	2
HEXADD:	DS	2
LASTAD:	DS	2
HEXCNT:	DS	1
CHKSUM:	DS	1
L1B0E:	DS	1
L1B0F:	DS	1
L1B10:	DS	1
IFFLG:	DS	1
CHKLAB:	DS	1
LSTPNT:	DS	2
ERRCNT:	DS	2
LSTRET:	DS	2
RETPT:	DS	2
HEXBUF:	DS	128
L1B9B:	DS	128
LSTBUF:	DS	128
BC:	DS	2
DE:	DS	2
HL:	DS	2
IX:	DS	2
IY:	DS	2
	DS	50
STACK:	EQU	$
START:	EQU	$
