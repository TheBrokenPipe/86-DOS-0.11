; QDOS  High-performance operating system for the 8086  version 0.11
;	by Tim Paterson


; Interrupt Entry Points:

; INTBASE:	ABORT
; INTBASE+4:	COMMAND
; INTBASE+8:	BASE EXIT ADDRESS
; INTBASE+C:	CONTROL-C ABORT
; INTBASE+10H:	FATAL ERROR ABORT
; INTBASE+14H:	BIOS DISK READ
; INTBASE+18H:	BIOS DISK WRITE
; INTBASE+40H:	Long jump to CALL entry point

ESCCH	EQU	1BH
CANCEL	EQU	"X"-"@"		;Cancel with Ctrl-X

MAXCALL	EQU	36
MAXCOM	EQU	40
INTBASE	EQU	80H
INTTAB	EQU	20H
ENTRYPOINTSEG	EQU	0CH
ENTRYPOINT	EQU	INTBASE+40H
CONTC	EQU	INTTAB+3
EXIT	EQU	INTBASE+8
LONGJUMP EQU	0EAH
LONGCALL EQU	9AH
SAVEXIT	EQU	10

; Field definition for FCBs

FNAME	EQU	0	;Drive code and name
EXTENT	EQU	12
ENTPOS	EQU	16	;Position of entry in directory
DRVBP	EQU	18	;BP for SEARCH FIRST and SEARCH NEXT
FIRCLUS	EQU	20	;First cluster of file
LSTCLUS	EQU	22	;Last cluster accessed
FILSIZ	EQU	24	;Size of file in records
CLUSPOS	EQU	26	;Position of last cluster accessed
FLSFLG	EQU	28	;Flush flag
SIZCHG	EQU	29	;Size change flag
NR	EQU	32	;Next record
RR	EQU	33	;Random record

; Description of 16-byte directory entry (same as returned by SEARCH FIRST
; and SEARCH NEXT, functions 17 and 18).
;
; Location	bytes	Description
;
;    0		11	File name and extension ( 0E5H if empty)
;   11		 2	First allocation unit ( < 4080 )
;   13		 3	File size, in bytes (LSB first, 24 bits max.)
;
; The File Allocation Table uses a 12-bit entry for each allocation unit on
; the disk. These entries are packed, two for every three bytes. The contents
; of entry number N is found by 1) multiplying N by 1.5; 2) adding the result
; to the base address of the Allocation Table; 3) fetching the 16-bit word at
; this address; 4) If N was odd (so that N*1.5 was not an integer), shift the
; word right four bits; 5) mask to 12 bits (AND with 0FFF hex). Entry number
; zero is used as an end-of-file trap in the OS. Entry 1 is reserved for
; future use. The first available allocation unit is assigned entry number
; two, and even though it is the first, is called cluster 2. Entries of 0FFFH
; are end of file marks; entries of zero are unallocated. Otherwise, the
; contents of a FAT entry is the number of the next cluster in the file.


; Field definition for Drive Parameter Block

DEVNUM	EQU	0	;I/O driver number
SECSIZ	EQU	1	;Size of physical sector in records
CLUSMSK	EQU	2	;Records/cluster - 1
CLUSSHFT EQU	3	;Log2 of records/cluster
FIRFAT	EQU	4	;Starting record of FATs
FATSIZ	EQU	6	;Number of records occupied by FAT
FATCNT	EQU	7	;Number of FATs for this drive
FIRDIR	EQU	8	;Starting record of directory
DIRSIZ	EQU	10	;Number of records occupied by directory
FIRREC	EQU	11	;First record of first cluster
MAXCLUS	EQU	13	;Number of clusters on drive + 1
DIRTY	EQU	15	;Whether FAT is dirty
FAT	EQU	16	;Pointer to start of FAT

DPBSIZ	EQU	18	;Size of the structure in bytes


; BOIS entry point definitions

BIOSSEG	EQU	40H

BIOSINIT	EQU	0	;Reserve room for jump to init code
BIOSSTAT	EQU	3	;Console input status check
BIOSIN		EQU	6	;Get console character
BIOSOUT		EQU	9	;Output console character
BIOSPRINT	EQU	12	;Output to printer
BIOSAUXIN	EQU	15	;Get byte from auxilliary
BIOSAUXOUT	EQU	18	;Output byte to auxilliary
BIOSREAD	EQU	21	;Disk read
BIOSWRITE	EQU	24	;Disk write
BIOSFLUSH	EQU	27	;Disk buffer flush

; Start of code

	ORG	0
	PUT	100H

	JMP	DOSINIT

ESCTAB: 
	DB	"SC"	;Copy one character from template
	DB	"VN"	;Skip over one character in template
	DB	"TA"	;Copy up to specified character
	DB	"WB"	;Skip up to specified character
	DB	"UH"	;Copy rest of template
	DB	"HH"	;Kill line with no change in template (Ctrl-X)
	DB	"RM"	;Cancel line and update template
	DB	"DD"	;Backspace (same as Ctrl-H)
	DB	"P@"	;Enter Insert mode
	DB	"QL"	;Exit Insert mode
	DB	1BH,1BH	;Escape sequence to represent escape character
	DB	ESCCH,ESCCH

ESCTABLEN EQU	$-ESCTAB
HEADER	DB	13,10,"86-DOS version 0.11"
	DB	13,10
	DB	"Copyright 1980 Seattle Computer Products, Inc.",13,10,"$"

DOSINIT:
	CLI
	CLD
	MOV	AX,CS
	MOV	ES,AX
	LODB			;Get no. of drives & no. of I/O drivers
	CBW
	MOV	CX,AX
	SEG	CS
	MOV	[NUMIO],AL
	MOV	DI,AX
	SHL	DI
	MOV	AH,DPBSIZ	;Size of DPB
	MUL	AX,AH
	MOV	BX,DRVTAB
	ADD	DI,BX		;Point to first DPB
	ADD	AX,DI
	MOV	BP,AX		;Point to first FAT
	SEG	CS
	MOV	[FATBASE],AX
PERDEV:
	SEG	CS
	MOV	[BX],DI		;Store DPB pointer to table entry
	INC	BX
	INC	BX
	MOV	AL,CH
	STOB			;DEVNUM
	LODW			;Get pointer to DPT
	PUSH	SI		;Save INITTAB pointer
	MOV	SI,AX		;Load DPT
	MOVB			;SECSIZ
	LODB
	DEC	AL
	STOB			;CLUSMSK
	CBW
FIGSHFT:
	INC	AH
	SAR	AL
	JNZ	FIGSHFT
	MOV	AL,AH
	STOB			;CLUSSHFT
	LODW
	STOW			;FIRFAT
	MOV	DX,AX
	LODB
	STOB			;FATSIZ
	MOV	AH,AL
	PUSH	AX
	LODB
	STOB			;FATCNT
	MUL	AX,AH
	ADD	AX,DX
	STOW			;FIRDIR
	MOV	DX,AX
	LODB
	STOB			;DIRSIZ
	CBW
	ADD	AX,DX
	STOW			;FIRREC
	POP	DX
	LODW
	INC	AX
	STOW			;MAXCLUS
	XOR	AL,AL
	STOB
	POP	SI
	LODW			;Allocation table displacement
	SEG	CS
	ADD	AX,[FATBASE]
	STOW			;FAT
	MOV	DL,0
	SHR	DX		;FAT size in bytes
	ADD	AX,DX
	CMP	AX,BP
	JBE	SMFAT
	MOV	BP,AX
SMFAT:
	INC	CH		;Next I/O device number
	DEC	CL
	JNZ	PERDEV
	ADD	BP,15		;True start of free space
	MOV	CL,4
	SHR	BP,CL		;First free segment
	XOR	AX,AX
	MOV	DS,AX
	MOV	ES,AX
	MOV	DI,INTBASE
	MOV	AX,QUIT
	STOW			;Set abort address--displacement
	MOV	AX,CS
	MOV	B,[ENTRYPOINT],LONGJUMP
	MOV	[ENTRYPOINT+1],ENTRY
	MOV	[ENTRYPOINT+3],CS
	STOW
	STOW
	STOW
	MOV	[INTBASE+4],COMMAND
	MOV	DI,INTBASE+14H
	MOV	AX,BIOSREAD
	STOW
	MOV	AX,BIOSSEG
	STOW
	STOW			;Add 2 to DI
	STOW
	MOV	[INTBASE+18H],BIOSWRITE
	MOV	DX,CS
	MOV	DS,DX
	ADD	DX,BP		;Next free segment
	MOV	[DMAADD],128
	MOV	[DMAADD+2],DX
	MOV	AX,[DRVTAB]
	MOV	[CURDRV],AX
	MOV	CX,DX		;Start scanning just after DOS
	MOV	BX,0FH
MEMSCAN:
	INC	CX
	JZ	SETEND
	MOV	DS,CX
	MOV	AL,[BX]
	NOT	AL
	MOV	[BX],AL
	CMP	AL,[BX]
	NOT	AL
	MOV	[BX],AL
	JZ	MEMSCAN

SETEND:
	SEG	CS
	MOV	[ENDMEM],CX
	XOR	CX,CX
	MOV	DS,CX
	MOV	[EXIT],100H
	MOV	[EXIT+2],DX
	MOV	[INTBASE+0CH],100H
	MOV	[INTBASE+0EH],DX
	CALL	SETMEM
	MOV	SI,HEADER
	CALL	OUTMES
	RET	L

QUIT:
	MOV	AH,0
	JP	SAVREGS

COMMAND: ;Interrupt call entry point
	CMP	AH,MAXCOM
	JBE	SAVREGS
BADCALL:
	MOV	AL,0
IRET:	IRET

ENTRY:	;System call entry point and dispatcher
	POP	AX		;IP from the long call at 5
	POP	AX		;Segment from the long call at 5
	SEG	CS
	POP	[TEMP]		;IP from the CALL 5
	PUSHF			;Start re-ordering the stack
	CLI
	PUSH	AX		;Save segment
	SEG	CS
	PUSH	[TEMP]		;Stack now ordered as if INT had been used
	CMP	CL,MAXCALL	;This entry point doesn't get as many calls
	JA	BADCALL
	MOV	AH,CL
SAVREGS:
	SEG	CS
	MOV	[SPSAVE],SP
	SEG	CS
	MOV	[SSSAVE],SS
	INC	SP
	INC	SP
	SEG	CS
	POP	[TEMP]
	MOV	SP,CS
	MOV	SS,SP
	MOV	SP,SSSAVE
	PUSH	ES
	PUSH	DS
	PUSH	BP
	PUSH	DI
	PUSH	SI
	PUSH	DX
	PUSH	CX
	PUSH	BX
	PUSH	AX
	MOV	BL,AH
	MOV	BH,0
	SHL	BX
	CLD
	SEG	CS
	CALL	[BX+DISPATCH]
	SEG	CS
	MOV	[AXSAVE],AL
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	POP	SI
	POP	DI
	POP	BP
	POP	DS
	POP	ES
	POP	SS
	SEG	CS
	MOV	SP,[SPSAVE]
	IRET
; Standard Functions
DISPATCH DW	ABORT		;0
	DW	CONIN
	DW	CONOUT
	DW	READER
	DW	PUNCH
	DW	LIST		;5
	DW	RAWIO
	DW	GETIO
	DW	SETIO
	DW	PRTBUF
	DW	BUFIN		;10
	DW	CONSTAT
	DW	GETVER
	DW	DSKRESET
	DW	SELDSK
	DW	OPEN		;15
	DW	CLOSE
	DW	SRCHFRST
	DW	SRCHNXT
	DW	DELETE
	DW	SEQRD		;20
	DW	SEQWRT
	DW	CREATE
	DW	RENAME
	DW	INUSE
	DW	GETDRV		;25
	DW	SETDMA
	DW	GETFATPT
	DW	GETFATPTDL
	DW	GETRDONLY
	DW	SETATTRIB	;30
	DW	GETDSKPT
	DW	USERCODE
	DW	RNDRD
	DW	RNDWRT
	DW	FILESIZE	;35
	DW	SETRNDREC
; Extended Functions
	DW	SETVECT
	DW	NEWBASE
	DW	BLKRD
	DW	BLKWRT		;40

GETIO:
SETIO:
GETVER:
GETFATPTDL:
GETRDONLY:
SETATTRIB:
USERCODE:
	MOV	AL,0
	RET

READER:
	CALL	BIOSAUXIN,BIOSSEG
	RET

PUNCH:
	MOV	AL,DL
	CALL	BIOSAUXOUT,BIOSSEG
	RET


UNPACK:

; Inputs:
;	DS = CS
;	BX = Cluster number
;	BP = Base of drive parameters
;	SI = Pointer to drive FAT
; Outputs:
;	DI = Contents of FAT for given cluster
;	Zero set means DI=0 (free cluster)
; No other registers affected. Fatal error if cluster too big.

	CMP	BX,[BP+MAXCLUS]
	JA	HURTFAT
	LEA	DI,[SI+BX]
	SHR	BX
	MOV	DI,[DI+BX]
	JNC	HAVCLUS
	SHR	DI
	SHR	DI
	SHR	DI
	SHR	DI
	STC
HAVCLUS:
	RCL	BX
	AND	DI,0FFFH
	RET
HURTFAT:
	MOV	SI,BADFAT
	CALL	OUTMES
	JMP	ERROR


PACK:

; Inputs:
;	DS = CS
;	BX = Cluster number
;	DX = Data
;	SI = Pointer to drive FAT
; Outputs:
;	The data is stored in the FAT at the given cluster.
;	BX,DX,DI all destroyed
;	No other registers affected

	MOV	DI,BX
	SHR	BX
	ADD	BX,SI
	ADD	BX,DI
	SHR	DI
	MOV	DI,[BX]
	JNC	ALIGNED
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	AND	DI,0FH
	JP	PACKIN
ALIGNED:
	AND	DI,0F000H
PACKIN:
	OR	DI,DX
	MOV	[BX],DI
	RET


GETNAME:

; Inputs:
;	DS,DX point to FCB
; Function:
;	Find file name in disk directory. First byte is
;	drive number (0=current disk). "?" matches any
;	character.
; Outputs:
;	Carry set if file not found
;	ELSE
;	BP = Base of drive parameters
;	DS = CS
;	ES = CS
;	AX = Directory record number
;	BX = Pointer into directory buffer
;	[DIRBUF] has directory record with match
;	[NAME1] has file name
; All other registers destroyed.


	CALL	MOVNAME
	JC	RET
FINDNAME:
	MOV	AX,CS
	MOV	DS,AX
	MOV	AL,0
RDIRREC:
	PUSH	AX
	CALL	DIRREAD
	POP	AX
	MOV	BX,DIRBUF-16
CONTSRCH:
	CALL	NEXTENT
	JZ	RET
NDIRREC:
	INC	AL		;Next directory record
	CMP	AL,[BP+DIRSIZ]
	JB	RDIRREC
	STC
	RET

NEXTENT:
	Add	BX,16
	CMP	BX,DIRBUF+127
	JA	RET
	CMP	B,[BX],0E5H
	JZ	NEXTENT
	MOV	SI,BX
	MOV	DI,NAME1
	MOV	CX,11
WILDCRD:
	REPE
	CMPB
	JZ	RET
	CMP	B,[DI-1],"?"
	JZ	WILDCRD
	JP	NEXTENT


DELETE:	; System call 19
	CALL	GETNAME
	JC	ERRET
	PUSH	AX
	PUSH	BX
	CALL	LOADFAT
	POP	BX
DELFILE:
	MOV	B,[BX],0E5H
	PUSH	BX
	MOV	BX,[BX+11]
	MOV	SI,[BP+FAT]
	OR	BX,BX
	JZ	DELNXT
	CMP	BX,[BP+MAXCLUS]
	JA	DELNXT
	CALL	RELEASE
DELNXT:
	POP	BX
	CALL	NEXTENT
	JZ	DELFILE
	POP	AX
	PUSH	AX
	CALL	DIRWRITE
	POP	AX
	CALL	NDIRREC
	PUSH	AX
	JNC	DELFILE
	POP	AX
	CALL	FATWRT
	XOR	AL,AL
	RET


RENAME:	;System call 23
	CALL	MOVNAME
	JC	ERRET
	ADD	SI,5
	MOV	DI,NAME2
	CALL	LODNAME
	CALL	FINDNAME
	JC	ERRET
SAVDREC:
	MOV	AH,AL
RENFIL:
	MOV	DI,BX
	MOV	SI,NAME2
	MOV	CX,11
NEWNAM:
	LODB
	CMP	AL,"?"
	JZ	SKIPLET
	MOV	[DI],AL
SKIPLET:
	INC	DI
	LOOP	NEWNAM
	CALL	NEXTENT
	JZ	RENFIL
	MOV	AL,AH
	PUSH	AX
	CALL	DIRWRITE
	POP	AX
	CALL	NDIRREC
	JNC	SAVDREC		;New record read, save current number
	XOR	AL,AL
	RET

ERRET:
	MOV	AL,-1
	RET


MOVNAME:

; Inputs:
;	DS, DX point to FCB
; Outputs:
;	ES = CS
;	If file name OK:
;	BP has base of driver parameters
;	[NAME1] has name in upper case
; All registers except DX destroyed
; Carry set if bad file name or drive

	MOV	AX,CS
	MOV	ES,AX
	MOV	DI,NAME1
	MOV	SI,DX
	LODB
	SEG	ES
	CMP	[NUMIO],AL
	JC	RET
	CBW
	XCHG	AX,BP
	SHL	BP
	MOV	BP,[BP+CURDRV]
LODNAME:
; This entry point copies a file name from DS,SI
; to ES,DI converting to upper case.
	MOV	CX,11
MOVCHK:
	LODB
	AND	AL,7FH
	CMP	AL,"a"-1
	JLE	STOLET
	AND	AL,5FH		;Convert to upper case
STOLET:
	CMP	AL," "
	JB	RET
	STOB
	LOOP	MOVCHK
	RET

OPEN:	;System call 15
	PUSH	DX
	PUSH	DS
	CALL	GETNAME
OPENNAM:
	POP	ES
	POP	DI
	JC	ERRET
	MOV	AH,[BP+DEVNUM]
	INC	AH
	SEG	ES
	MOV	[DI],AH
	SEG	ES
	MOV	[DI+EXTENT],0
	ADD	DI,16
	MOV	CX,BX
	SUB	CX,DIRBUF
	MOV	AH,CL
	STOW			;ENTPOS
	MOV	AX,BP
	STOW			;DRVBP
	LEA	SI,[BX+11]
	LODW
	STOW			;FIRCLUS
	STOW			;LSTCLUS
	LODB
	SHL	AL
	LODW
	RCL	AX
	STOW			;FILSIZ
	XOR	AX,AX
	STOW			;CLUSPOS
	STOW			;FLSFLG, SIZCHG

LOADFAT:
	TEST	B,[BP+DIRTY],-1
	JNZ	RET
	CALL	FIGFAT
READFAT:
	PUSH	DX
	PUSH	CX
	PUSH	BX
	PUSH	AX
	CALL	DREAD
	OR	AL,AL
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	JNZ	FATERR
	SUB	AL,[BP+FATCNT]
	JZ	RET
	NEG	AL
	JP	FATWRT
FATERR:
	ADD	DX,CX
	DEC	AL
	JNZ	READFAT
	POP	BP
	MOV	SI,ALLBAD
	CALL	HARDERR
	JP	LOADFAT

CLOSE:	;System call 16
	MOV	DI,DX
	TEST	B,[DI+FLSFLG],-1
	JZ	NOFLSH
	PUSH	DI
	MOV	BP,[DI+DRVBP]
	MOV	AL,[BP+DEVNUM]
	CALL	BIOSFLUSH,BIOSSEG
	POP	DI
NOFLSH:
	TEST	B,[DI+SIZCHG],-1
	JZ	OKRET
	MOV	DX,DI
	PUSH	DX
	PUSH	DS
	CALL	GETNAME
	POP	ES
	POP	DI
	JC	BADCLOSE
	MOV	CX,BX
	SUB	CX,DIRBUF
	MOV	AH,CL
	SEG	ES
	CMP	AX,[DI+ENTPOS]
	JNZ	BADCLOSE
	SEG	ES
	MOV	CX,[DI+FIRCLUS]
	MOV	[BX+11],CX
	SEG	ES
	MOV	DX,[DI+FILSIZ]
	SHR	DX
	MOV	[BX+14],DX
	MOV	DL,0
	RCR	DL
	MOV	[BX+13],DL
	CALL	DIRWRITE

CHKFATWRT:
; Do FATWRT only if FAT is dirty
	TEST	B,[BP+DIRTY],-1
	JZ	OKRET

FATWRT:

; Inputs:
;	DS = CS
;	BP = Base of drive parameter table
; Function:
;	Write the FAT back to disk and reset FAT
;	dirty flag.
; Outputs:
;	AL = 0
;	BP unchanged
; All other registers destroyed

	MOV	B,[BP+DIRTY],0
	CALL	FIGFAT
EACHFAT:
	PUSH	DX
	PUSH	CX
	PUSH	BX
	PUSH	AX
	CALL	DWRITE
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	ADD	DX,CX
	DEC	AL
	JNZ	EACHFAT
OKRET:
	MOV	AL,0
	RET

BADCLOSE:
	MOV	B,[BP+DIRTY],0
	MOV	AL,-1
	RET


FIGFAT:
; Loads registers with values needed to read or
; write a FAT.
	MOV	AL,[BP+FATCNT]
	MOV	BX,[BP+FAT]
	MOV	CL,[BP+FATSIZ]	;No. of records occupied by FAT
	MOV	CH,0
	MOV	DX,[BP+FIRFAT]	;Record number of start of FATs
	RET


DIRCOMP:
; Prepare registers for directory read or write
	CBW
	ADD	AX,[BP+FIRDIR]
	MOV	DX,AX
	MOV	BX,DIRBUF
	MOV	CX,1
	RET


CREATE:	;System call 22
	CALL	MOVNAME
	JC	ERRET3
	MOV	DI,NAME1
	MOV	CX,11
	MOV	AL,"?"
	REPNE
	SCAB
	JZ	ERRET3
	PUSH	DX
	PUSH	DS
	MOV	AX,CS
	MOV	DS,AX
	XOR	AX,AX
RDIRREC2:
	PUSH	AX
	CALL	DIRREAD
	POP	AX
	MOV	DI,DIRBUF-16
	MOV	CX,8
FNDFRE:
	ADD	DI,16
	CMP	B,[DI],0E5H
	LOOPNE	FNDFRE
	JZ	FREESPOT
	INC	AL
	CMP	AL,[BP+DIRSIZ]
	JC	RDIRREC2
	POP	DS
	POP	DX
ERRET3:
	MOV	AL,-1
	RET
FREESPOT:
	MOV	BX,DI
	MOV	SI,NAME1
	MOV	CX,5
	MOVB
	REP
	MOVW
	XCHG	AL,AH
	MOV	CL,5
	REP
	STOB
	XCHG	AL,AH
	PUSH	AX
	PUSH	BX
	CALL	DIRWRITE
	POP	BX
	POP	AX
	JMP	OPENNAM


DIRREAD:

; Inputs:
;	DS = CS
;	AL = Directory block number
;	BP = Base of drive parameters
; Function:
;	Read the directory block into DIRBUF.
; Outputs:
;	AX,BP unchanged
; All other registers destroyed.

	CALL	DIRCOMP

DREAD:

; Inputs:
;	BX,DS = Transfer address
;	CX = Number of records
;	DX = Absolute record number
;	BP = Base of drive parameters
; Function:
;	Calls BIOS to perform disk read. If BIOS reports
;	errors, will call HARDERR for further action.
; BP preserved. All other registers destroyed.

	MOV	AL,[BP+DEVNUM]
	PUSH	BP
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	BIOSREAD,BIOSSEG
	POP	DX
	POP	DI
	POP	BX
	POP	BP
	JC	DSKRDERR
	XOR	AL,AL
	RET

DSKRDERR:
	MOV	SI,RDERR
	CALL	HARDERR
	JP	DREAD

DIRWRITE:

; Inputs:
;	DS = CS
;	AL = Directory block number
;	BP = Base of drive parameters
; Function:
;	Write the directory block into DIRBUF.
; Outputs:
;	BP unchanged
; All other registers destroyed.

	CALL	DIRCOMP


DWRITE:

; Inputs:
;	BX,DS = Transfer address
;	CX = Number of records
;	DX = Absolute record number
;	BP = Base of drive parameters
; Function:
;	Calls BIOS to perform disk write. If BIOS reports
;	errors, will call HARDERR for further action.
; BP preserved. All other registers destroyed.

	MOV	AL,[BP+DEVNUM]
	MOV	AH,0
	CMP	DX,[BP+FIRREC]
	RCR	AH
	PUSH	BP
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	BIOSWRITE,BIOSSEG
	POP	DX
	POP	DI
	POP	BX
	POP	BP
	JC	DSKWRERR
	XOR	AL,AL
	RET

DSKWRERR:
	MOV	SI,WRERR
	CALL	HARDERR
	JP	DWRITE

HARDERR:
	SUB	DI,CX
	ADD	DX,DI		;Next record to transfer
	CALL	RECTOBYT
	ADD	BX,DI		;Next location for transfer
	CALL	OUTMES
GETRESP:
	CALL	IN
	OR	AL,20H		;To lower-case
	CMP	AL,"a"
	JZ	ERROR
	CMP	AL,"r"
	JZ	RET
	CMP	AL,"i"
	JZ	IGNORE
	CMP	AL,"c"
	JNZ	GETRESP
	POP	AX
	MOV	AL,1
	RET
IGNORE:
	POP	AX
	MOV	AL,0
	RET

ABORT:
	SEG	CS
	MOV	DS,[TEMP]
	XOR	AX,AX
	MOV	ES,AX
	MOV	SI,SAVEXIT
	MOV	DI,EXIT
	MOVW
	MOVW
	MOVW
	MOVW
ERROR:
	MOV	SP,BPSAVE
	MOV	AX,CS
	MOV	DS,AX
	MOV	ES,AX
	CALL	NOBUF
	XOR	AX,AX
	MOV	DS,AX
	MOV	SI,EXIT
	MOV	DI,EXITHOLD
	MOVW
	MOVW
	POP	BP
	POP	ES
	POP	ES
	POP	DS
	POP	SS
	MOV	SP,[SPSAVE]
	MOV	DS,[DSSAVE]
	SEG	CS
	JMP	L,[EXITHOLD]


SEQRD:	;System call 20
	CALL	GETREC
	MOV	CX,1
	CALL	LOAD
	JCXZ	SETNREX
	INC	AX
	JP	SETNREX

SEQWRT:	;System call 21
	CALL	GETREC
	MOV	CX,1
	CALL	STORE
	JCXZ	SETNREX
	INC	AX
	JP	SETNREX

RNDRD:	;System call 33
	MOV	CX,1
	MOV	DI,DX
	MOV	AX,[DI+RR]
	CALL	LOAD
	JP	FINRND

RNDWRT:	;System call 34
	MOV	CX,1
	MOV	DI,DX
	MOV	AX,[DI+RR]
	CALL	STORE
	JP	FINRND

BLKRD:	;System call 39
	MOV	DI,DX
	MOV	AX,[DI+RR]
	CALL	LOAD
	JP	FINBLK

BLKWRT:	;System call 40
	MOV	DI,DX
	MOV	AX,[DI+RR]
	CALL	STORE
FINBLK:
	MOV	[CXSAVE],CX
	JCXZ	FINRND
	INC	AX
FINRND:
	SEG	ES
	MOV	[DI+RR],AX
SETNREX:
	MOV	CX,AX
	AND	AL,7FH
	SEG	ES
	MOV	[DI+NR],AL
	AND	CL,80H
	ROL	CX
	XCHG	CL,CH
	SEG	ES
	MOV	[DI+EXTENT],CX
	MOV	AL,[DSKERR]
	RET

SETUP:

; Inputs:
;	DS:DI point to FCB
;	AX = Record position in file of disk transfer
;	CX = Record count
; Outputs:
;	DS = CS
;	ES:DI point to FCB
;	CX = No. of records to transfer
;	BP = Base of drive parameters
;	[RECCNT] = Record count
;	[RECPOS] = Record position in file
;	[FCB] = DX
;	[NEXTADD] = Displacement of disk transfer within segment
;	[DSKERR] = 0 (no errors yet)
;	[NUMTRNS] = 0 (No transfers yet)
; If SETUP detects no records will be transfered, it returns 1 level up 
; with CX = 0.

	MOV	BP,[DI+DRVBP]
	MOV	BX,DS
	MOV	ES,BX
	MOV	BX,CS
	MOV	DS,BX
	MOV	[RECPOS],AX
	MOV	[FCB],DX
	MOV	BX,[DMAADD]
	MOV	[NEXTADD],BX
	MOV	B,[DSKERR],0
	MOV	[NUMTRNS],0
	MOV	SI,[BP+FAT]
	ADD	BX,7FH		;See if there is any space left
	JC	SEGEND
	AND	BL,80H
	NEG	BX	;These instructions divide by 128
	ROL	BX
	XCHG	BL,BH
	JNZ	CHKMAX
	MOV	BH,2	;All 512 records OK
CHKMAX:
	CMP	CX,BX
	JBE	SAVCNT
	MOV	CX,BX
	MOV	B,[DSKERR],2	;Flag that trimming took place
SAVCNT:
	MOV	[RECCNT],CX
	RET
SEGEND:
	MOV	B,[DSKERR],2
	MOV	CX,0
	POP	BX
	RET


FNDCLUS:

; Inputs:
;	DS = CS
;	CX = No. of clusters
;	BP = Base of drive parameters
;	SI = FAT pointer
;	ES:DI point to FCB
; Outputs:
;	BX = Last cluster skipped to
;	CX = No. of clusters remaining (0 unless EOF)
;	DX = Position of last cluster
; DI destroyed. No other registers affected.

	SEG	ES
	MOV	BX,[DI+LSTCLUS]
	SEG	ES
	MOV	DX,[DI+CLUSPOS]
	OR	BX,BX
	JZ	NOCLUS
	SUB	CX,DX
	JNB	FINDIT
	ADD	CX,DX
	XOR	DX,DX
	SEG	ES
	MOV	BX,[DI+FIRCLUS]
FINDIT:
	JCXZ	RET
SKPCLP:
	CALL	UNPACK
	CMP	DI,0FFFH
	JZ	RET
	XCHG	BX,DI
	INC	DX
	LOOP	SKPCLP
	RET
NOCLUS:
	INC	CX
	DEC	DX
	RET


LOAD:

; Inputs:
;	DS:DI point to FCB
;	AX = Position in file to read
;	CX = No. of records to read
; Outputs:
;	AX = Position of last record read
;	CX = No. of records read
;	ES:DI point to FCB
;	LSTCLUS, CLUSPOS fields in FCB set

	CALL	SETUP
	SEG	ES
	MOV	BX,[DI+FILSIZ]
	SUB	BX,AX
	JBE	WRTERRJ
	CMP	BX,CX
	JNB	ENUF
	MOV	B,[DSKERR],1
	MOV	[RECCNT],BX
ENUF:
	MOV	CL,[BP+CLUSSHFT]
	SHR	AX,CL
	MOV	CX,AX
	CALL	FNDCLUS
	OR	CX,CX
	JNZ	WRTERR
	MOV	DL,[RECPOS]
	AND	DL,[BP+CLUSMSK]
	MOV	CX,[RECCNT]
RDLP:
	CALL	OPTIMIZE
	PUSH	DI
	PUSH	AX
	PUSH	DS
	MOV	DS,[DMAADD+2]
	CALL	DREAD
	POP	DS
	POP	CX
	POP	BX
	JCXZ	SETFCB
	MOV	DL,0
	CMP	BX,0FFFH
	JNZ	RDLP
	MOV	B,[DSKERR],1

SETFCB:
	MOV	AX,[CLUSNUM]
	MOV	DI,[FCB]
	SEG	ES
	MOV	[DI+LSTCLUS],AX
	MOV	AX,[RECPOS]
	MOV	BX,[NUMTRNS]
	ADD	AX,BX
	SEG	ES
	CMP	AX,[DI+FILSIZ]
	JBE	NOSZINC
	SEG	ES
	MOV	[DI+FILSIZ],AX
	SEG	ES
	MOV	B,[DI+SIZCHG],-1
NOSZINC:
	DEC	AX
	MOV	DX,AX
	MOV	CL,[BP+CLUSSHFT]
	SHR	DX,CL
	SEG	ES
	MOV	[DI+CLUSPOS],DX
	MOV	CX,BX
	RET
WRTERRJ:
	JP	WRTERR

HAVSTART:
	MOV	CX,AX
	PUSH	BX
	CALL	FNDCLUS
	JCXZ	WRCLUS
	CALL	ALLOCATE
	POP	BX
	JNC	NOSKIP
WRTERR:
	MOV	B,[DSKERR],1
ADDREC:
	MOV	AX,[RECPOS]
	XOR	CX,CX
	MOV	DI,[FCB]
	RET
WRTEOF:
	MOV	CL,[BP+CLUSSHFT]
	SHR	AX,CL
	MOV	CX,AX
	CALL	FNDCLUS
	OR	CX,CX
	JNZ	ADDREC
	MOV	DX,0FFFH
	MOV	B,[BP+DIRTY],-1
	MOV	DI,[FCB]
	MOV	AX,[RECPOS]
	SEG	ES
	MOV	[DI+FILSIZ],AX
	SEG	ES
	MOV	B,[DI+SIZCHG],-1
	XOR	CX,CX
	RET

STORE:

; Inputs:
;	DS:DI point to FCB
;	AX = Position in file of disk transfer
;	CX = Record count
; Outputs:
;	AX = Position of last record written
;	CX = No. of records written
;	ES:DI point to FCB
;	LSTCLUS, CLUSPOS fields in FCB set

	CALL	SETUP
	JCXZ	WRTEOF
	MOV	BX,CX
	ADD	BX,AX
	DEC	BX
	MOV	CL,[BP+CLUSSHFT]
	SHR	AX,CL
	SHR	BX,CL
	MOV	CX,AX
	MOV	AX,BX
	CALL	FNDCLUS
	SUB	AX,DX		;Last cluster minus current cluster
	JCXZ	HAVSTART	;See if no more data
	PUSH	CX		;No. of clusters of first
	MOV	CX,AX
	CALL	ALLOCATE
	POP	CX
	JC	WRTERR
	DEC	CX
	JZ	NOSKIP
	CALL	SKPCLP
	PUSH	BX
WRCLUS:
	POP	BX
NOSKIP:
	MOV	DL,[RECPOS]
	AND	DL,[BP+CLUSMSK]
	MOV	CX,[RECCNT]
WRTLP:
	CALL	OPTIMIZE
	PUSH	DI
	PUSH	AX
	PUSH	DS
	MOV	DS,[DMAADD+2]
	CALL	DWRITE
	POP	DS
	POP	CX
	POP	BX
	MOV	DL,0
	OR	CX,CX
	JNZ	WRTLP
	CALL	SETFCB
	SEG	ES
	MOV	B,[DI+FLSFLG],-1
	RET


OPTIMIZE:

; Inputs:
;	DS = CS
;	BX = Physical cluster
;	CX = No. of records
;	DL = record within cluster
;	BP = Base of drives parameters
;	[NEXTADD] = transfer address
; Outputs:
;	AX = No. of records remaining
;	BX = Transfer address
;	CX = No. or records to be transferred
;	DX = Physical record address
;	DI = Next cluster
;	[CLUSNUM] = Last cluster accessed
;	[NEXTADD] updated
; BP unchanged. Note that segment of transfer not set.

	PUSH	DX
	PUSH	BX
	MOV	AL,[BP+CLUSMSK]
	INC	AL		;Number of records per cluster
	MOV	AH,AL
	SUB	AL,DL		;AL = Number of records left in first cluster
	MOV	DX,CX
	MOV	SI,[BP+FAT]
	MOV	CX,0
OPTCLUS:
;AL has number of records available in current cluster
;AH has number of records available in next cluster
;BX has current physical cluster
;CX has number of sequential records found so far
;DX has number of records left to transfer
;SI has FAT pointer
	CALL	UNPACK
	ADD	CL,AL
	ADC	CH,0
	CMP	CX,DX
	JAE	BLKDON
	MOV	AL,AH
	INC	BX
	CMP	DI,BX
	JZ	OPTCLUS
	DEC	BX
FINCLUS:
	MOV	[CLUSNUM],BX	;Last cluster accessed
	SUB	DX,CX		;Number of records still needed
	MOV	AX,DX
	MOV	BX,CX
	XCHG	BL,BH
	ROR	BX
	MOV	SI,[NEXTADD]
	ADD	BX,SI		;Adjust by size of transfer
	MOV	[NEXTADD],BX
	ADD	[NUMTRNS],CX
	POP	DX
	POP	BX
	PUSH	CX
	MOV	CL,[BP+CLUSSHFT]
	DEC	DX
	DEC	DX
	SHL	DX,CL
	OR	DL,BL
	ADD	DX,[BP+FIRREC]
	POP	CX
	MOV	BX,SI
	RET
BLKDON:
	MOV	CX,DX		;Make the total equal to the request
	JP	FINCLUS


GETREC:

; Inputs:
;	DS:DX point to FCB
; Outputs:
;	AX = Record number determined by EXTENT and NR fields
;	DS:DI point to FCB
; No other registers affected.

	MOV	DI,DX
	MOV	AL,[DI+NR]
	MOV	BX,[DI+EXTENT]
	SHL	AL
	SHR	BX
	RCR	AL
	MOV	AH,BL
	RET


ALLOCATE:

; Inputs:
;	DS = CS
;	ES = Segment of FCB
;	BX = Last cluster of file (0 if null file)
;	CX = No. of clusters to allocate
;	DX = Position of cluster BX
;	BP = Base of drive parameters
;	SI = FAT pointer
;	[FCB] = Displacement of FCB within segment
; Outputs:
;	IF insufficient space
;	  THEN
;	Carry set
;	CX = max. no. of records that could be added to file
;	  ELSE
;	Carry clear
;	BX = First cluster allocated
;	FAT is fully updated including dirty flag
;	FIRCLUS field of FCB set if file was null
; SI,BP unchanged. All other registers destroyed.

	PUSH	BX
	MOV	AX,BX
ALLOC:
	MOV	DX,BX
FINDFRE:
	INC	BX
	CMP	BX,[BP+MAXCLUS]
	JL	TRYOUT
	CMP	AX,1
	JG	TRYIN
	POP	BX
	MOV	DX,0FFFH
	CALL	RELBLKS
	OR	[SI],0FFFH
	STC
	RET

TRYOUT:
	CALL	UNPACK
	JZ	HAVFRE
TRYIN:
	DEC	AX
	JLE	FINDFRE
	XCHG	AX,BX
	CALL	UNPACK
	JZ	HAVFRE
	XCHG	AX,BX
	JP	FINDFRE
HAVFRE:
	XCHG	BX,DX
	MOV	AX,DX
	CALL	PACK
	MOV	BX,AX
	LOOP	ALLOC
	MOV	DX,0FFFH
	CALL	PACK
	MOV	B,[BP+DIRTY],-1
	POP	BX
	CALL	UNPACK
	XCHG	BX,DI
	OR	DI,DI
	JNZ	RET
	MOV	DI,[FCB]
	SEG	ES
	MOV	[DI+FIRCLUS],BX
	OR	[SI],0FFFH
	RET


RELEASE:

; Inputs:
;	DS = CS
;	BX = Cluster in file
;	SI = FAT pointer
;	BP = Base of drive parameters
; Function:
;	Frees cluster chain starting with [BX]
; AX,BX,DX,DI all destroyed. Other registers unchanged.

	XOR	DX,DX
RELBLKS:
; Enter here with DX=0FFFH to put an end-of-file mark
; in the first cluster and free the rest in the chain.
	CALL	UNPACK
	JZ	RET
	MOV	AX,DI
	CALL	PACK
	CMP	AX,0FFFH
	MOV	BX,AX
	JNZ	RELEASE
	RET


GETEOF:

; Inputs:
;	BX = Cluster in a file
;	SI = Base of drive FAT
;	DS = CS
; Outputs:
;	BX = Last cluster in the file
; DI destroyed. No other registers affected.

	CALL	UNPACK
	CMP	DI,0FFFH
	JZ	RET
	MOV	BX,DI
	JP	GETEOF


SRCHFRST: ;System call 17
	CALL	GETNAME
SAVPLCE:
; Search-for-next enters here to save place and report
; findings.
	JC	KILLSRCH
	MOV	[SRCHDON],AL
	MOV	[PDIR],BX
	MOV	[SRCHBP],BP
;Information in directory entry must be copied into the first
; 16 bytes starting at the disk transfer address.
	MOV	SI,BX
	LES	DI,[DMAADD]
	MOV	CX,8
	REP
	MOVW
	MOV	AL,0
	RET

KILLSRCH:
	MOV	AL,-1
	MOV	[SRCHDON],AL
	RET


SRCHNXT: ;System call 18
	MOV	AX,CS
	MOV	ES,AX
	MOV	DS,AX
	MOV	AL,[SRCHDON]
	CMP	AL,-1
	JZ	RET
	MOV	BX,[PDIR]
	MOV	BP,[SRCHBP]
	CALL	CONTSRCH
	JP	SAVPLCE


FILESIZE: ;System call 35
	PUSH	DI
	PUSH	DX
	CALL	GETNAME
	POP	DI
	POP	ES
	MOV	AL,-1
	JC	RET
	ADD	DI,33		;Write size in RR field
	LEA	SI,[BX+13]
	LODB
	SHL	AL
	LODW
	RCL	AX		;Round to nearest record
	STOW
	MOV	AL,0
	RCL	AL
	STOB
	RET


SETDMA:	;System call 26
	SEG	CS
	MOV	[DMAADD],DX
	SEG	CS
	MOV	[DMAADD+2],DS
	RET

GETFATPT: ;System call 27
	MOV	AX,CS
	MOV	DS,AX
	MOV	[DSSAVE],CS
	MOV	BP,[CURDRV]
	CALL	LOADFAT
	MOV	BX,[BP+FAT]
	MOV	AL,[BP+CLUSMSK]
	INC	AL
	MOV	DX,[BP+MAXCLUS]
	DEC	DX
	MOV	B,[BP+DIRTY],-1
	MOV	[BXSAVE],BX
	MOV	[DXSAVE],DX
	RET


GETDSKPT: ;System call 31
	SEG	CS
	MOV	[DSSAVE],CS
	SEG	CS
	MOV	BX,[CURDRV]
	SEG	CS
	MOV	[BXSAVE],BX
	RET


DSKRESET: ;System call 13
	SEG	CS
	MOV	[DMAADD+2],DS
	MOV	AX,CS
	MOV	DS,AX
	MOV	[DMAADD],80H
	MOV	AX,[DRVTAB]
	MOV	[CURDRV],AX
NOBUF:
	MOV	CL,[NUMIO]
	MOV	CH,0
	MOV	SI,DRVTAB
WRTFAT:
	LODW
	PUSH	CX
	PUSH	SI
	MOV	BP,AX
	CALL	CHKFATWRT
	POP	SI
	POP	CX
	LOOP	WRTFAT
	MOV	AL,-1
	CALL	BIOSFLUSH,BIOSSEG
	RET


GETDRV:	;System call 25
	SEG	CS
	MOV	BP,[CURDRV]
	MOV	AL,[BP+0]
	RET


INUSE:	;System call 24
	MOV	AX,CS
	MOV	DS,AX
	MOV	CL,[NUMIO]
	MOV	CH,0
	MOV	SI,CX
	SHL	SI
	ADD	SI,CURDRV
	MOV	BX,0
	STD
CHKUSE:
	LODW
	MOV	BP,AX
	TEST	B,[BP+DIRTY],-1
	JZ	SETBIT
	STC
SETBIT:
	RCL	BX
	LOOP	CHKUSE
	MOV	AL,BL
	RET


SETRNDREC: ;System call 36
	CALL	GETREC
	MOV	[DI+RR],AX
	MOV	AL,0
	JZ	BIGRR
	INC	AL
BIGRR:
	MOV	[DI+RR+2],AL
	RET


SELDSK:	;System call 14
	MOV	DH,0
	MOV	BX,DX
	PUSH	CS
	POP	DS
	CMP	BL,[NUMIO]
	JGE	RET
	SHL	BX
	MOV	AX,[BX+DRVTAB]
	MOV	[CURDRV],AX
	RET

BUFIN:	;System call 10
	MOV	AX,CS
	MOV	ES,AX
	MOV	SI,DX
	MOV	CH,0
	LODW
	OR	AL,AL
	JZ	RET
	MOV	BL,AH
	MOV	BH,CH
	CMP	AL,BL
	JBE	NOEDIT
	CMP	B,[BX+SI],0DH
	JZ	EDITON
NOEDIT:
	MOV	BL,CH
EDITON:
	MOV	DL,AL
	DEC	DX
NEWLIN:
	SEG	CS
	MOV	AL,[CARPOS]
	SEG	CS
	MOV	[STARTPOS],AL
	PUSH	SI
	MOV	DI,INBUF
	MOV	AH,CH
	MOV	BH,CH
	MOV	DH,CH
GETCH:
	CALL	IN
	CMP	AL,7FH
	JZ	BACKSP
	CMP	AL,8
	JZ	BACKSP
	CMP	AL,13
	JZ	ENDLIN
	CMP	AL,10
	JZ	PHYCRLF
	CMP	AL,CANCEL
	JZ	KILNEW
	CMP	AL,27
	JZ	ESC
SAVCH:
	CMP	DH,DL
	JNB	GETCH
	STOB
	INC	DH
	CALL	OUT
	OR	AH,AH
	JNZ	GETCH
	CMP	BH,BL
	JAE	GETCH
	INC	SI
	INC	BH
	JP	GETCH

ESC:
	CALL	IN
	MOV	CL,ESCTABLEN
	PUSH	DI
	MOV	DI,ESCTAB
	REPNE
	SCAB
	POP	DI
	AND	CL,0FEH
	MOV	BP,CX
	JMP	[BP+ESCFUNC]

ENDLIN:
	STOB
	CALL	OUT
	POP	DI
	MOV	[DI-1],DH
	INC	DH
COPYNEW:
	MOV	BP,ES
	MOV	BX,DS
	MOV	ES,BX
	MOV	DS,BP
	MOV	SI,INBUF
	MOV	CL,DH
	REP
	MOVB
	RET
CRLF:
	MOV	AL,13
	CALL	OUT
	MOV	AL,10
	JMP	OUT

PHYCRLF:
	CALL	CRLF
	JP	GETCH

KILNEW:
	MOV	AL,"\"
	CALL	OUT
	POP	SI
PUTNEW:
	CALL	CRLF
	JMP	NEWLIN

BACKSP:
	OR	DH,DH
	JZ	OLDBAK
	CALL	BACKUP
	SEG	ES
	MOV	AL,[DI]
	CMP	AL," "
	JAE	OLDBAK
	CMP	AL,9
	JZ	BAKTAB
	CALL	BACKMES
OLDBAK:
	OR	AH,AH
	JNZ	GETCH1
	OR	BH,BH
	JZ	GETCH1
	DEC	BH
	DEC	SI
GETCH1:
	JMP	GETCH
BAKTAB:
	PUSH	DI
	DEC	DI
	STD
	MOV	CL,DH
	MOV	AL," "
	PUSH	BX
	MOV	BL,7
	JCXZ	FIGTAB
FNDPOS:
	SCAB
	JNA	CHKCNT
	SEG	ES
	CMP	B,[DI+1],9
	JZ	HAVTAB
	DEC	BL
CHKCNT:
	LOOP	FNDPOS
FIGTAB:
	SEG	CS
	SUB	BL,[STARTPOS]
HAVTAB:
	SUB	BL,DH
	ADD	CL,BL
	AND	CL,7
	CLD	
	POP	BX
	POP	DI
	JZ	OLDBAK
TABBAK:
	CALL	BACKMES
	LOOP	TABBAK
	JP	OLDBAK
BACKUP:
	DEC	DH
	DEC	DI
BACKMES:
	MOV	AL,8
	CALL	OUT
	MOV	AL," "
	CALL	OUTCH
	MOV	AL,8
	JMP	OUTCH

TWOESC:
	MOV	AL,ESCCH
	JMP	SAVCH

COPYLIN:
	MOV	CL,BL
	SUB	CL,BH
	JP	COPYEACH

COPYSTR:
	CALL	FINDOLD
	JP	COPYEACH

COPYONE:
	MOV	CL,1
COPYEACH:
	CMP	DH,DL
	JZ	GETCH2
	CMP	BH,BL
	JZ	GETCH2
	LODB
	STOB
	CALL	OUT
	INC	BH
	INC	DH
	LOOP	COPYEACH
GETCH2:
	JMP	GETCH

SKIPONE:
	CMP	BH,BL
	JZ	GETCH2
	INC	BH
	INC	SI
	JMP	GETCH

SKIPSTR:
	CALL	FINDOLD
	ADD	SI,CX
	ADD	BH,CL
	JMP	GETCH

FINDOLD:
	CALL	IN
	MOV	CL,BL
	SUB	CL,BH
	JZ	NOTFND
	DEC	CX
	JZ	NOTFND
	PUSH	ES
	PUSH	DS
	POP	ES
	PUSH	DI
	MOV	DI,SI
	INC	DI
	REPNE
	SCAB
	POP	DI
	POP	ES
	JNZ	NOTFND
	NOT	CL
	ADD	CL,BL
	SUB	CL,BH
	RET
NOTFND:
	POP	BP
	JMP	GETCH

REEDIT:
	MOV	AL,"@"
	CALL	OUT
	POP	DI
	PUSH	DI
	PUSH	ES
	PUSH	DS
	CALL	COPYNEW
	POP	DS
	POP	ES
	POP	SI
	MOV	BL,DH
	JMP	PUTNEW

ENTERINS:
	MOV	AH,-1
	JMP	GETCH

EXITINS:
	MOV	AH,0
	JMP	GETCH

ESCFUNC	DW	GETCH
	DW	TWOESC
	DW	EXITINS
	DW	ENTERINS
	DW	BACKSP
	DW	REEDIT
	DW	KILNEW
	DW	COPYLIN
	DW	SKIPSTR
	DW	COPYSTR
	DW	SKIPONE
	DW	COPYONE

CONOUT:	;System call 2
	MOV	AL,DL
OUT:
	CMP	AL,20H
	JB	CTRLOUT
	CMP	AL,7FH
	JZ	OUTCH
	SEG	CS
	INC	B,[CARPOS]
OUTCH:
	CALL	BIOSOUT,BIOSSEG
	SEG	CS
	TEST	B,[PFLAG],-1
	JZ	STATCHK
	CALL	BIOSPRINT,BIOSSEG

STATCHK:
	CALL	BIOSSTAT,BIOSSEG
	JZ	RET
INCHK:
	CALL	BIOSIN,BIOSSEG
	CMP	AL,'S'-'@'
	JNZ	NOSTOP
	CALL	BIOSIN,BIOSSEG	;Eat Cntrl-S
NOSTOP:
	CMP	AL,'P'-'@'
	JZ	PRINTON
	CMP	AL,'N'-'@'
	JZ	PRINTOFF
	CMP	AL,'C'-'@'
	JNZ	RET
	INT	CONTC		;Execute user Ctrl-C handler
	RET

PRINTON:
	SEG	CS
	MOV	B,[PFLAG],1
	RET

PRINTOFF:
	SEG	CS
	MOV	B,[PFLAG],0
	RET

CTRLOUT:
	CMP	AL,10
	JZ	OUTCH
	CMP	AL,13
	JZ	ZERPOS
	CMP	AL,8
	JZ	BACKPOS
	CMP	AL,9
	JZ	TAB
	PUSH	AX
	MOV	AL,"^"
	CALL	OUT
	POP	AX
	OR	AL,40H
	JP	OUT

ZERPOS:
	SEG	CS
	MOV	B,[CARPOS],0
	JP	OUTCH

BACKPOS:
	SEG	CS
	DEC	B,[CARPOS]
	JP	OUTCH

TAB:
	MOV	AL,0
	SEG	CS
	XCHG	AL,[CARPOS]
	OR	AL,0F8H
	NEG	AL
	PUSH	CX
	MOV	CL,AL
	MOV	CH,0
TABLP:
	MOV	AL," "
	CALL	OUTCH
	LOOP	TABLP
	POP	CX
	RET


CONSTAT: ;System call 11
	CALL	BIOSSTAT,BIOSSEG
	JZ	RET
	OR	AL,-1
	RET


CONIN:	;System call 1
	CALL	INCHK
	PUSH	AX
	CALL	OUT
	POP	AX
	RET


IN:
	CALL	INCHK
	JZ	IN
	RET

RAWIO:	;System call 6
	MOV	AL,DL
	CMP	AL,-1
	JNZ	RAWOUT
	CALL	BIOSSTAT,BIOSSEG
	JZ	RET
	CALL	BIOSIN,BIOSSEG
	RET
RAWOUT:
	CALL	BIOSOUT,BIOSSEG
	RET

LIST:	;System call 5
	MOV	AL,DL
	CALL	BIOSPRINT,BIOSSEG
	RET

PRTBUF:	;System call 9
	MOV	SI,DX
OUTSTR:
	LODB
	CMP	AL,"$"
	JZ	RET
	CALL	OUT
	JP	OUTSTR

OUTMES:	;String output for internal messages
	SEG	CS
	LODB
	CMP	AL,"$"
	JZ	RET
	CALL	OUT
	JP	OUTMES


SETVECT: ; Interrupt call 37
	XOR	BX,BX
	MOV	ES,BX
	MOV	BL,AL
	SHL	BX
	SHL	BX
	SEG	ES
	MOV	[BX],DX
	SEG	ES
	MOV	[BX+2],DS
	RET


NEWBASE: ; Interrupt call 38
	MOV	ES,DX
	SEG	CS
	MOV	DS,[TEMP]
	XOR	SI,SI
	MOV	DI,SI
	MOV	CX,80H
	REP
	MOVW

SETMEM:

; Inputs:
;	AX = Size of memory in paragraphs
;	DX = Segment
; Function:
;	Completely prepares a program base at the 
;	specified segment.
; Outputs:
;	DS = DX
;	ES = DX
;	[0] has INT 20H
;	[2] = First unavailable segment ([ENDMEM])
;	[5] to [9] form a long call to the entry point
;	[10] to [13] have exit address (from INT 22H)
;	[14] to [17] have ctrl-C exit address (from INT 23H)
; DX,BP unchanged. All other registers destroyed.

	XOR	CX,CX
	MOV	DS,CX
	MOV	ES,DX
	MOV	SI,EXIT
	MOV	DI,SAVEXIT
	MOVW
	MOVW
	MOVW
	MOVW
	SEG	CS
	MOV	CX,[ENDMEM]
	SEG	ES
	MOV	[2],CX
	SUB	CX,DX
	CMP	CX,0FFFH
	JBE	HAVDIF
	MOV	CX,0FFFH
HAVDIF:
	MOV	BX,ENTRYPOINTSEG
	SUB	BX,CX
	SHL	CX
	SHL	CX
	SHL	CX
	SHL	CX
	MOV	DS,DX
	MOV	[6],CX
	MOV	[8],BX
	MOV	[0],20CDH	;"INT INTTAB"
	MOV	B,[5],LONGCALL
	RET

RECTOBYT:
	SHL	DI
	SHL	DI
	SHL	DI
	SHL	DI
	SHL	DI
	SHL	DI
	SHL	DI
	RET


;***** DATA AREA *****
BADFAT	DB	13,10,"Bad FAT",13,10,"$"
ALLBAD	DB	13,10,"All FATs on disk are bad",13,10,"$"
RDERR	DB	13,10,"Disk read error",13,10,"$"
WRERR	DB	13,10,"Disk write error",13,10,"$"
CARPOS	DB	0
STARTPOS DB	0
PFLAG	DB	0
SRCHDON	DB	-1
PDIR	DS	2
SRCHBP	DS	2
EXITHOLD DS	4
ENDMEM	DS	2
FATBASE	DS	2
INBUF	DS	255
DIRBUF	DS	128
NUMIO	DS	1		;Number of disk tables
NAME1	DS	11		;File name buffer
NAME2	DS	11		;File name buffer
DMAADD	DS	4		;User's disk transfer address (disp/seg)
TEMP	DS	2
DSKERR	DS	1
FCB	DS	2		;Address of user FCB
RECPOS	DS	2
NEXTADD	DS	2
RECCNT	DS	2
CLUSNUM	DS	2
NUMTRNS	DS	2
	DS	50
AXSAVE	DS	2
BXSAVE	DS	2
CXSAVE	DS	2
DXSAVE	DS	2
SISAVE	DS	2
DISAVE	DS	2
BPSAVE	DS	2
DSSAVE	DS	2
ESSAVE	DS	2
SSSAVE	DS	2
SPSAVE	DS	2
CURDRV	DS	2
DRVTAB:				;Address of start of DPBs
