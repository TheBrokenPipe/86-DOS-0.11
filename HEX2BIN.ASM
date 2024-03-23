; HEX2BIN
; Converts Intel hex format files to straight binary

FCB:	EQU	5CH
READ:	EQU	20
SETDMA:	EQU	26
OPEN:	EQU	15
CLOSE:	EQU	16
CREATE:	EQU	22
DELETE:	EQU	19
BLKWRT:	EQU	40
BUFFER:	EQU	80H
BUFSIZ:	EQU	128

	ORG	100H
	PUT	100H

HEX2BIN:
	MOV	DI,FCB+9
	CMP	B,[DI]," "
	JNZ	HAVEXT
	MOV	SI,HEX
	MOVB
	MOVW
HAVEXT:
;Get load offset (default is -100H)
	MOV	AH,OPEN
	MOV	DX,FCB
	INT	33
	OR	AL,AL
	JNZ	NOFIL
	MOV	B,[FCB+32],0
	MOV	AH,READ
	MOV	BP,START
	MOV	SI,BUFFER+BUFSIZ ;Flag input buffer as empty
READHEX:
	CALL	GETCH
	CMP	AL,":"		;Search for : to start line
	JNZ	READHEX
	CALL	GETBYT		;Get byte count
	MOV	CL,AL
	MOV	CH,0
	JCXZ	DONE
	CALL	GETBYT		;Get high byte of load address
	MOV	BH,AL
	CALL	GETBYT		;Get low byte of load address
	MOV	BL,AL
	ADD	BX,START-100H	;Add in offset
	MOV	DI,BX
	CALL	GETBYT		;Throw away type byte
READLN:
	CMP	DI,[6]
	JAE	ADERR
	CMP	DI,START
	JB	ADERR
	CALL	GETBYT		;Get data byte
	STOB
	LOOP	READLN
	CMP	DI,BP		;Check if this is the largest address so far
	JBE	READHEX
	MOV	BP,DI		;Save new largest
	JP	READHEX

NOFIL:
	MOV	DX,NOFILE
QUIT:
	MOV	AH,9
	INT	33
	INT	32

ADERR:
	MOV	DX,ADDR
	JMP	ERROR

GETCH:
	CMP	SI,BUFFER+BUFSIZ
	JNZ	NOREAD
	INT	33
	OR	AL,AL
	JNZ	ERROR
	MOV	SI,BUFFER
NOREAD:
	LODB
	CMP	AL,1AH
	JZ	DONE
	RET

GETBYT:
	CALL	HEXDIG
	MOV	BL,AL
	CALL	HEXDIG
	SHL	BL
	SHL	BL
	SHL	BL
	SHL	BL
	OR	AL,BL
	RET

HEXDIG:
	CALL	GETCH
	SUB	AL,"0"
	JC	ERROR
	CMP	AL,9
	JBE	RET
	SUB	AL,"A"-"0"-10
	JC	ERROR
	CMP	AL,15
	JBE	RET
ERROR:
	MOV	DX,ERRMES
	MOV	AH,9
	INT	33
DONE:
	MOV	DI,FCB+9
	MOV	SI,COM
	MOVB
	MOVW
	MOV	DX,FCB
	MOV	AH,DELETE
	INT	33
	MOV	AH,CREATE
	INT	33
	OR	AL,AL
	JNZ	NOROOM
	MOV	W,[FCB+33],0
	MOV	DX,START
	MOV	AH,SETDMA
	INT	33
	MOV	CX,BP
	SUB	CX,START-7FH
	AND	CL,80H
	JCXZ	EXIT
	ROL	CX
	XCHG	CL,CH
	MOV	AH,BLKWRT
	MOV	DX,FCB
	INT	33
	MOV	AH,CLOSE
	INT	33
EXIT:
	INT	32

NOROOM:
	MOV	DX,DIRFUL
	JMP	QUIT

HEX:	DB	"HEX"
COM:	DB	"COM"
ERRMES:	DB	"Error in HEX file--conversion aborted$"
NOFILE:	DB	"File not found$"
ADDR:	DB	"Address out of range--conversion aborted$"
DIRFUL:	DB	"Disk directory full$"

START:
