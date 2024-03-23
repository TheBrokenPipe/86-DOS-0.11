FCB	EQU	5CH

	ORG	100H
	PUT	100H

	JMP	START

SECS:	DW	52	;Patch for different configs

START:
	MOV	AL,[FCB]
	OR	AL,AL
	JZ	BADDRV
	DEC	AL
	JZ	BADDRV
	MOV	[FCB],AL
	MOV	CX,[SECS]
	MOV	DX,0
	MOV	BX,END
	MOV	AL,0
	INT	37
	JC	RDERR
	POPF
	MOV	CX,[SECS]
	MOV	DX,0
	MOV	BX,END
	MOV	AL,[FCB]
	MOV	AH,1
	INT	38
	JC	WRERR
	MOV	DX,SYSOK
	JP	QUIT

RDERR:
	MOV	DX,ERREAD

QUIT:
	MOV	AH,9
	INT	33
	INT	32

WRERR:
	MOV	DX,ERWRIT
	JP	QUIT

BADDRV:
	MOV	DX,DRVBAD
	JP	QUIT

SYSOK:	DB	"System transfered$"
ERREAD:	DB	"Disk read error$"
ERWRIT:	DB	"Disk write error$"
DRVBAD:	DB	"Bad drive specification"

END:
