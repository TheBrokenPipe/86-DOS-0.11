FCB	EQU	5CH
FCB2	EQU	6CH
OPEN	EQU	15
CLOSE	EQU	16
MAKE	EQU	22
DELETE	EQU	19
SEQWRT	EQU	21
SETDMA	EQU	26
GETDRV	EQU	25
PRINTBUF EQU	9
SYSTEM	EQU	5

	ORG	100H
	PUT	100H

	JMP	RDCPM

CPMTAB:
	DW	IBM,IBM,IBM,IBM
	DW	0,0,0,0
	DW	0,0,0,0
	DW	0,0,0,0

INVSRC:
	MOV	DX,BADSRC
	JMP	EXIT

NONAME:
	MOV	DX,BADFN
	JMP	EXIT

RDCPM:
	MOV	SP,100H
	CMP	B,[FCB+1]," "
	JZ	NONAME
	XOR	AL,AL
	XCHG	AL,[FCB]
	OR	AL,AL
	JNZ	HASDRV
	MOV	CL,GETDRV
	CALL	SYSTEM
	INC	AX

HASDRV:
	DEC	AX
	MOV	[DRIVE],AL
	CMP	AL,15
	JA	INVSRC		;Invalid drive number
	CBW
	MOV	BX,AX
	SHL	BX
	MOV	BP,[BX+CPMTAB]
	OR	BP,BP
	JZ	INVSRC
	MOV	SI,FCB2
	MOV	DI,DSTFCB
	MOVB
	CMP	B,[FCB2+1]," "
	JNZ	HASDST
	MOV	SI,FCB+1

HASDST:
	MOV	CX,11
	REP
	MOVB			;Copy file name
	MOV	AL,[DSTFCB]
	OR	AL,AL
	JNZ	DSTDRV
	MOV	CL,GETDRV
	CALL	SYSTEM		;Use default drive
	INC	AX

DSTDRV:
	DEC	AX
	CMP	AL,[DRIVE]
	JZ	BADPARM
	MOV	CL,DELETE
	MOV	DX,DSTFCB
	CALL	SYSTEM
	MOV	CL,MAKE
	MOV	DX,DSTFCB
	CALL	SYSTEM
	MOV	CL,SETDMA
	MOV	DX,SECBUF
	CALL	SYSTEM

BEGDIR:
	XOR	AX,AX
	MOV	BX,[BP+NUMENT]

READDIR:
	MOV	DI,DIRBUF
	PUSH	AX
	PUSH	BX
	CALL	READSEC
	POP	BX
	POP	AX
	MOV	SI,DIRBUF

ENUMDIR:
	MOV	DI,FCB
	MOV	CX,13
	REPE
	CMPB
	JZ	RDENTRY
	ADD	SI,CX
	ADD	SI,19		;Point to next entry
	DEC	BX
	JS	DONE
	CMP	SI,DIRBUF+128
	JB	ENUMDIR
	INC	AX
	JP	READDIR

BADPARM:
	MOV	DX,SAMDSK
	JMP	EXIT

RDENTRY:
	ADD	SI,3		;Point to AL array
	MOV	CX,16		;16 AL bytes per entry

RDNXTAL:
	LODB
	MOV	AH,0
	TEST	B,[BP+DSISIZ+1],0FFH
	JZ	SMALDSK
	MOV	AH,[SI]		;Big disk, use words instead
	INC	SI
	DEC	CX

SMALDSK:
	OR	AX,AX
	JZ	DONE
	PUSH	CX
	MOV	CH,0
	PUSH	SI
	MOV	CL,[BP+BLKSFT]
	SHL	AX,CL

RDALOC:
	PUSH	AX
	OR	AL,CH
	PUSH	CX
	MOV	DI,SECBUF
	CALL	READSEC
	MOV	CL,SEQWRT
	MOV	DX,DSTFCB
	CALL	SYSTEM
	POP	CX
	POP	AX
	INC	CH
	CMP	CH,[BP+BLKMSK]
	JBE	RDALOC
	POP	SI
	POP	CX
	LOOP	RDNXTAL
	INC	B,[FCB+12]	;Increment extent counter
	JMP	BEGDIR		;Scan from beginning of directory

DONE:
	MOV	CL,CLOSE
	MOV	DX,DSTFCB
	CALL	SYSTEM
	JMP	0

;Read allocation block
READSEC:
	XOR	DX,DX
	MOV	BX,[BP+SPT]
	DIV	AX,BX
	ADD	AX,[BP+RESTRK]
	MOV	CX,DX
	MUL	AX,BX		;Tracks in sectors
	MOV	DX,AX
	OR	BH,BH		;Check for >255 sectors per track
	JNZ	BIGTRK		;Use words instead of bytes for xlat table
	MOV	AX,CX
	MOV	BX,[BP+XLTTBL]
	XLAT
	ADD	DX,AX		;Logical sector number

READABS:
	MOV	CX,1
	MOV	BX,DI
	MOV	AL,[DRIVE]
	PUSH	BP
	INT	37
	POP	AX
	POP	BP
	JNC	RDDONE
	MOV	DX,DSKERR

EXIT:
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	JMP	0

;Translation table made up of WORDs
BIGTRK:
	MOV	BX,CX
	SHL	BX
	ADD	BX,[BP+XLTTBL]
	ADD	DX,[BX]
	JP	READABS

RDDONE:
	RET

DSKERR:	DB	13,10,"HARD DISK ERROR",13,10,"$"
SAMDSK:	DB	13,10,"Source and destination drives must not be the same",13,10,"$"
BADSRC:	DB	13,10,"Bad source drive",13,10,"$"
BADFN:	DB	13,10,"Bad file name",13,10,"$"
DRIVE:	DS	1
DSTFCB:	DS	32
	DB	0
DIRBUF:	DS	128
SECBUF:	DS	128

SPT	EQU	0
BLKSFT	EQU	2
BLKMSK	EQU	3
EXTMSK	EQU	4
DSISIZ	EQU	5
NUMENT	EQU	7
ALBMP0	EQU	9
ALBMP1	EQU	10
DIRCKS	EQU	11
RESTRK	EQU	13
XLTTBL	EQU	15

;Below is the definition for standard single-density 8" drives

IBM:
	DW	26	;Sectors per track
	DB	3	;Block shift
	DB	7	;Block mask
	DB	0	;Extent mask
	DW	242	;Disk size - 1
	DW	63	;Directory entries - 1
	DB	0C0H	;Directory allocation bitmap 0
	DB	0	;Directory allocation bitmap 1
	DW	16	;Directory check vector size
	DW	2	;Tracks to skip
	DW	MOD6	;Modulo-6 sector translate table

MOD6:
	DB	0,6,12,18,24
	DB	4,10,16,22
	DB	2,8,14,20
	DB	1,7,13,19,25
	DB	5,11,17,23
	DB	3,9,15,21

CPMTAB2:
	DW	0,0,0,0
	DW	0,0,0,0
	DW	0,0,0,0
	DW	0,0,0,0
