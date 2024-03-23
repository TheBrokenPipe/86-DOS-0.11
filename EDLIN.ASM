FCB	EQU	5CH
RENAM	EQU	23
OPEN	EQU	15
CLOSE	EQU	16
MAKE	EQU	22
DELFIL	EQU	19
RDBLK	EQU	39
WRBLK	EQU	40
SETDMA	EQU	26
PRINTBUF EQU	9
OUTCH	EQU	2
INBUF	EQU	10
RR	EQU	33

PROMPT	EQU	"*"

	ORG	100H
	PUT	100H

	MOV	SP,STACK
	MOV	DX,BREAK
	MOV	AX,2523H
	INT	33
	MOV	SI,BAK
	MOV	DI,FCB+9
	MOV	CX,3
	;File must not have .BAK extension
	REPE
	CMPB
	JZ	NOTBAK
	;Open input file
	MOV	AH,OPEN
	MOV	DX,FCB
	INT	33
	MOV	[HAVEOF],AL
	OR	AL,AL
	JZ	HAVFIL
	MOV	DX,NEWFIL
	MOV	AH,PRINTBUF
	INT	33
HAVFIL:
	MOV	SI,FCB
	MOV	DI,FCB2
	MOV	CX,9
	REP
	MOVB
	MOV	SI,BAK
	MOVW
	MOVB
	MOV	AH,DELFIL
	MOV	DX,FCB2
	INT	33
	MOV	AL,"$"
	MOV	DI,FCB2+9
	STOB
	STOB
	STOB
	MOV	AH,DELFIL
	INT	33
	;Create .$$$ file to make sure directory has room
	MOV	AH,MAKE
	INT	33
	OR	AL,AL
	JZ	SETUP
	MOV	DX,NODIR
	JMP	ERROR
NOTBAK:
	MOV	DX,NOBAK
	JMP	ERROR
TOOBIG:
	MOV	DX,TOBIG
	JMP	ERROR
NOTEOF:
	MOV	DX,NOEOF
	JMP	ERROR
SETUP:
	MOV	DX,START
	MOV	AH,SETDMA
	INT	33
	MOV	CX,[6]
	SUB	CX,80H
	MOV	[LAST],CX
	MOV	DI,START-1
	TEST	B,[HAVEOF],-1
	JNZ	SAVEND
	CALL	NUMRECS
	MOV	[FCB+RR],0
	MOV	DX,FCB
	MOV	AH,RDBLK
	INT	33
	CMP	AL,2
	JZ	TOOBIG
	JCXZ	SAVEND
	ROR	CX
	XCHG	CL,CH
	ADD	DI,CX		;Point to last byte
	DOWN
	MOV	AL,1AH
	REPNE
	SCAB
	JNZ	NOTEOF
	REPE
	SCAB
	INC	DI
SAVEND:
	CLD
	INC	DI
	MOV	B,[DI],1AH
	MOV	[ENDTXT],DI
	MOV	B,[COMBUF],128
	MOV	B,[EDITBUF],255
	MOV	[POINTER],START
	MOV	[CURRENT],1

COMMAND:
	MOV	SP,STACK
	MOV	AL,PROMPT
	CALL	OUT
	MOV	DX,COMBUF
	MOV	AH,INBUF
	INT	33
	MOV	AL,10
	CALL	OUT
	MOV	[PARAM2],0
	MOV	B,[QFLG],0
	MOV	SI,2+COMBUF
	CALL	GETNUM
	MOV	[PARAM1],DX
	CALL	SKIP1
	CMP	AL,","
	JNZ	CHKNXT
	INC	SI
CHKNXT:
	DEC	SI
	CALL	GETNUM
	MOV	[PARAM2],DX
	CALL	SKIP1
	CMP	AL,"?"
	JNZ	DISPATCH
	MOV	[QFLG],AL
	CALL	SKIP
DISPATCH:
	AND	AL,5FH
	MOV	DI,COMTAB
	MOV	CX,NUMCOM
	REPNE
	SCAB
	JNZ	COMERR
	MOV	BX,CX
	SHL	BX
	CALL	[BX+TABLE]
	JMP	COMMAND

SKIP:
	LODB
SKIP1:
	CMP	AL," "
	JZ	SKIP
	RET

COMERR:
	MOV	DX,BADCOM
	MOV	AH,PRINTBUF
	INT	33
	JP	COMMAND


GETNUM:
	CALL	SKIP
	CMP	AL,"."
	JZ	CURLIN
	CMP	AL,"#"
	JZ	MAXLIN
	MOV	DX,0
NUMLP:
	CMP	AL,"0"
	JB	RET
	CMP	AL,"9"
	JA	RET
	SUB	AL,"0"
	MOV	BX,DX
	SHL	DX
	SHL	DX
	ADD	DX,BX
	SHL	DX
	CBW
	ADD	DX,AX
	LODB
	JP	NUMLP

CURLIN:
	MOV	DX,[CURRENT]
	LODB
	RET
MAXLIN:
	MOV	DX,-1
	LODB
	RET


COMTAB	DB	"SFDLIE",13

NUMCOM	EQU	$-COMTAB

;-----------------------------------------------------------------------;
;	Carefull changing the order of the next two tables. They are
;      linked and chnges should be be to both.

TABLE	DW	NOCOM	;No command--edit line
	DW	ENDED
	DW	INSERT
	DW	LIST
	DW	DELETE
	DW	COMERR
	DW	COMERR

FINDLIN:

; Inputs
;	BX = Line number to be located in buffer (0 means last line)
; Outputs:
;	DX = Actual line found
;	DI = Pointer to start of line DX
;	Zero set if BX = DX
; AL,CX destroyed. No other registers affected.

	MOV	DX,[CURRENT]
	MOV	DI,[POINTER]
	CMP	BX,DX
	JZ	RET
	JA	FINDIT
	MOV	DX,1
	MOV	DI,START
	CMP	BX,DX
	JZ	RET
FINDIT:
	MOV	CX,[ENDTXT]
	SUB	CX,DI
	MOV	AL,10
	OR	AL,AL		;Clear zero flag
FINLIN:
	JCXZ	RET
	REPNE
	SCAB
	INC	DX
	CMP	BX,DX
	JNZ	FINLIN
	RET


SHOWNUM:

; Inputs:
;	BX = Line number to be displayed
; Function:
;	Displays line number on terminal in 8-character
;	format, suppressing leading zeros.
; AX, CX, DX destroyed. No other registers affected.

	PUSH	BX
	MOV	AL," "
	CALL	OUT
	CALL	CONV10
	MOV	AL,":"
	CALL	OUT
	MOV	AL," "
	CALL	OUT
	POP	BX
	RET


CONV10:

;Inputs:
;	BX = Binary number to be displayed
; Function:
;	Ouputs binary number. Five digits with leading
;	zero suppression. Zero prints 5 blanks.

	XOR	AX,AX
	MOV	DL,AL
	MOV	CX,16
CONV:
	SHL	BX
	ADC	AL,AL
	DAA
	XCHG	AL,AH
	ADC	AL,AL
	DAA
	XCHG	AL,AH
	ADC	DL,DL
	LOOP	CONV
	MOV	BL,"0"-" "
	XCHG	AX,DX
	CALL	LDIG
	MOV	AL,DH
	CALL	DIGITS
	MOV	AL,DL
DIGITS:
	MOV	DH,AL
	SHR	AL
	SHR	AL
	SHR	AL
	SHR	AL
	CALL	LDIG
	MOV	AL,DH
LDIG:
	AND	AL,0FH
	JZ	ZERDIG
	MOV	BL,0
ZERDIG:
	ADD	AL,"0"
	SUB	AL,BL
	JMP	OUT


LIST:
	MOV	BX,[PARAM1]
	OR	BX,BX
	JNZ	CHKP2
	MOV	BX,[CURRENT]
	SUB	BX,10
	JA	CHKP2
	MOV	BX,1
CHKP2:
	CALL	FINDLIN
	JNZ	RET
	MOV	SI,DI
	MOV	DI,[PARAM2]
	INC	DI
	SUB	DI,BX
	JA	DISPLAY
	MOV	DI,21
	JP	DISPLAY


DISPONE:
	MOV	DI,1

DISPLAY:

; Inputs:
;	BX = Line number
;	SI = Pointer to text buffer
;	DI = No. of lines
; Function:
;	Ouputs specified no. of line to terminal, each
;	with leading line number.
; Outputs:
;	BX = Last line output.
; All registers destroyed.

	MOV	CX,[ENDTXT]
	SUB	CX,SI
	JZ	RET
	MOV	BP,[CURRENT]
DISPLN:
	PUSH	CX
	CALL	SHOWNUM
	POP	CX
OUTLN:
	LODB
	CALL	OUT
	CMP	AL,10
	LOOPNZ	OUTLN
	JCXZ	RET
	DEC	DI
	JZ	RET
	CMP	BX,BP
	LAHF
	INC	BX
	SAHF
	JZ	OUTLF
	CMP	BX,BP
	JNZ	DISPLN
OUTLF:
	MOV	AL,10
	CALL	OUT
	JP	DISPLN
RET:	RET


NOCOM:
	MOV	BX,[PARAM1]
	OR	BX,BX
	JNZ	HAVLIN
	MOV	BX,[CURRENT]
	INC	BX	;Default is current line plus one
HAVLIN:
	CALL	FINDLIN
	MOV	SI,DI
	MOV	[CURRENT],DX
	MOV	[POINTER],SI
	JNZ	RET
	CMP	SI,[ENDTXT]
	JZ	RET
	MOV	DI,2+EDITBUF
	MOV	CX,254
	MOV	DL,-1
LOADLP:
	LODB
	STOB
	INC	DL
	CMP	AL,13
	LOOPNZ	LOADLP
	MOV	[EDITBUF+1],DL
	MOV	[OLDLEN],DL
	MOV	SI,[POINTER]
	CALL	DISPONE
	CALL	SHOWNUM
	MOV	AH,INBUF	;Get input buffer
	MOV	DX,EDITBUF
	INT	33
	MOV	AL,10
	CALL	OUT
	MOV	CL,[EDITBUF+1]
	MOV	CH,0
	JCXZ	RET
	MOV	DL,[OLDLEN]
	MOV	DH,0
	MOV	SI,2+EDITBUF
	MOV	DI,[POINTER]

REPLACE:

; Inputs:
;	CX = Length of new text
;	DX = Length of original text
;	SI = Pointer to new text
;	DI = Pointer to old text in buffer
; Function:
;	New text replaces old text in buffer and buffer
;	size is adjusted. CX or DX may be zero.
; CX, SI, DI all destroyed. No other registers affected.

	CMP	CX,DX
	JZ	COPYIN
	PUSH	SI
	PUSH	DI
	PUSH	CX
	MOV	SI,DI
	ADD	SI,DX
	ADD	DI,CX
	MOV	AX,[ENDTXT]
	SUB	AX,DX
	ADD	AX,CX
	CMP	AX,[LAST]
	JAE	MEMERR
	XCHG	AX,[ENDTXT]
	MOV	CX,AX
	SUB	CX,SI
	CMP	SI,DI
	JA	DOMOV
	ADD	SI,CX
	ADD	DI,CX
	STD
DOMOV:
	INC	CX

	REP
	MOVB
	CLD
	POP	CX
	POP	DI
	POP	SI
COPYIN:
	REP
	MOVB
	RET

DELETE:
	MOV	BX,[PARAM1]
	OR	BX,BX
	JNZ	DELFIN1
	MOV	BX,[CURRENT]
DELFIN1:
	CALL	FINDLIN
	JNZ	RET
	MOV	[CURRENT],BX
	MOV	[POINTER],DI
	PUSH	DI
	MOV	BX,[PARAM2]
	OR	BX,BX
	JNZ	DELFIN2
	MOV	BX,DX
DELFIN2:
	INC	BX
	CALL	FINDLIN
	MOV	DX,DI
	POP	DI
	SUB	DX,DI
	XOR	CX,CX
	JP	REPLACE


GETTEXT:

; Inputs:
;	SI points into command line buffer
;	DI points to result buffer
; Function:
;	Moves [SI] to [DI] until ctrl-Z (1AH) or
;	RETURN (0DH) is found. Termination char not moved.
; Outputs:
;	AL = Termination character
;	CX = No of characters moved.
;	SI points one past termination character
;	DI points to next free location

	XOR	CX,CX

GETIT:
	LODB
	CMP	AL,1AH
	JZ	RET
	CMP	AL,0DH
	JZ	RET
	STOB
	INC	CX
	JP	GETIT

MEMERR:
	MOV	DX,MEMFUL
	MOV	AH,PRINTBUF
	INT	33
	JMP	COMMAND


INSERT:
	MOV	BX,[PARAM1]
	OR	BX,BX
	JNZ	INS
	MOV	BX,[CURRENT]
	INC	BX
INS:
	CALL	FINDLIN
	MOV	CX,[ENDTXT]		;Get End-of-text marker
	MOV	SI,CX
	SUB	CX,DI			;Calculate number of bytes to copy
	INC	CX
	MOV	DI,[LAST]
	DOWN
	REP
	MOVB
	XCHG	SI,DI
	UP
	INC	DI
	MOV	BP,SI
	MOV	BX,DX
INLP:
	CALL	SHOWNUM
	MOV	DX,EDITBUF
	MOV	AH,INBUF
	INT	33
	MOV	AL,10
	CALL	OUT
	MOV	SI,EDITBUF+2
	CMP	B,[SI],1AH
	JZ	ENDINS
	MOV	CL,[SI-1]
	MOV	CH,0
	MOV	DX,SI
	ADD	DX,CX
	INC	DX
	CMP	DX,BP	;Will it fit?
	JNC	MEMERR
	REP
	MOVB
	MOVB
	MOV	AL,10
	STOB
	INC	BX
	JP	INLP
ENDINS:
	MOV	[POINTER],DI
	MOV	[CURRENT],BX
	MOV	SI,BP
	INC	SI
	MOV	CX,[LAST]
	SUB	CX,BP
	REP
	MOVB
	DEC	DI
	MOV	[ENDTXT],DI
	RET

ENDED:
;Write text out to .$$$ file
	MOV	DI,[ENDTXT]
	MOV	CX,128
	MOV	AL,1AH
	REP
	STOB
	MOV	CX,[ENDTXT]
	CALL	NUMRECS
	INC	CX
	MOV	[FCB2+RR],0
	MOV	DX,FCB2
	MOV	AH,WRBLK
	INT	33
	OR	AL,AL
	JNZ	WRTERR
;Close .$$$ file
	MOV	AH,CLOSE
	INT	33
	MOV	SI,FCB
	LEA	DI,[SI+16]
	MOV	DX,SI
	MOV	CX,9
	REP
	MOVB
	MOV	SI,BAK
	MOVW
	MOVB
;Rename original file .BAK
	MOV	AH,RENAM
	INT	33
	MOV	SI,FCB
	MOV	DI,FCB2+16
	MOV	CX,6
	REP
	MOVW
;Rename .$$$ file to original name
	MOV	DX,FCB2
	INT	33
	JMP	0


WRTERR:
	MOV	DX,DSKFUL
ERROR:
	MOV	AH,PRINTBUF
	INT	33
	JMP	0

NUMRECS:
	SUB	CX,START
	AND	CL,80H
	ROL	CX
	XCHG	CL,CH
	RET

OUT:
	PUSH	DX
	XCHG	AX,DX
	MOV	AH,OUTCH
	INT	33
	XCHG	AX,DX
	POP	DX
	RET

BREAK:
	IRET


BAK:	DB	"BAK"
NOBAK:	DB	"Cannot edit .BAK file--rename file$"
NODIR:	DB	"No room in directory for file$"
TOBIG:	DB	"File too big to fit into memory$"
NOEOF:	DB	"No end-of-file mark found in file$"
DSKFUL:	DB	"Disk full--file write not completed$"
MEMFUL:	DB	13,10,"Memory full",13,10,"$"
BADCOM:	DB	"Entry error",13,10,"$"
NEWFIL:	DB	"New file",13,10,"$"
FCB2:	DS	36
PARAM1:	DS	2
PARAM2:	DS	2
QFLG:	DS	1
HAVEOF:	DS	1
OLDLEN:	DS	1
CURRENT: DS	2
POINTER: DS	2
LAST:	DS	2
ENDTXT:	DS	2
COMBUF:	DS	2+128
EDITBUF: DS	2+255
	DS	40
	ALIGN
STACK:
START:
