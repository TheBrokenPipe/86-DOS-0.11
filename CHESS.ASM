;***********************************************************
;
;		SARGON
;
;	Sargon is a computer chess playing program designed
; and coded by Dan and Kathe Spracklen.  Copyright 1978. All
; rights reserved.  No part of this publication may be
; reproduced without the prior written permission.
;***********************************************************

;***********************************************************
; SYSTEM EQUATES
;***********************************************************
INCHAR	EQU	1
PRINTBUF EQU	9
INBUF	EQU	10
SYSTEM	EQU	5

;***********************************************************
; EQUATES
;***********************************************************
;
PAWN:	EQU	1
KNIGHT:	EQU	2
BISHOP:	EQU	3
ROOK:	EQU	4
QUEEN:	EQU	5
KING:	EQU	6
WHITE:	EQU	0
BLACK:	EQU	80H
BPAWN:	EQU	BLACK+PAWN

	ORG	100H
	PUT	100H

;***********************************************************
; MAIN PROGRAM DRIVER
;***********************************************************
; FUNCTION:   --  To coordinate the game moves.
;
; CALLED BY:  --  None
;
; CALLS:      --  INITBD
;                 CPTRMV
;                 PLYRMV
;
; ARGUMENTS:      None
;***********************************************************
DRIVER:	MOV	SP,STACK	; Set stack pointer
	MOV	DX,CLRMSG	; Request color choice
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	MOV	CL,INCHAR	; Accept response
	CALL	SYSTEM
	CMP	AL,57H		; Did player request white ?
	JZ	DR05		; Yes - branch
	CMP	AL,42H		; Did player request black ?
	JNZ	DRIVER		; No - error
	XOR	AL,AL
	JP	DR10		; Jump
DR05:	MOV	AL,BLACK	; Set computers color to black
DR10:	MOV	[KOLOR],AL
DR15:	MOV	DX,PLYDEP	; Request depth of search
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	MOV	CL,INCHAR
	CALL	SYSTEM
	SUB	AL,31H		; Subtract Ascii constant
	JB	DR15		; Under minimum - prompt again
	CMP	AL,6		; Over maximum of 6 ?
	JNB	DR15		; Yes - prompt again
	INC	AL		; Increment by one
	MOV	[PLYMAX],AL	; Set desired depth
	MOV	DX,CRLF		; Output CRLF
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	XOR	AL,AL
	MOV	[COLOR],AL	; Set color to white
	INC	AL
	MOV	[MOVENO],AL	; Set move number to 1
	CALL	INITBD		; Init board
	MOV	AL,[KOLOR]	; Get color
	OR	AL,AL		; Computer move ?
	JZ	DR25		; Yes - jump
DR20:	CALL	PLYRMV		; Do player move
DR25:	CALL	CPTRMV		; Do computer move
	MOV	BX,MOVENO
	INC	B,[BX]		; Increment move number
	JP	DR20		; Back to player move

;***********************************************************
; TABLES SECTION
;***********************************************************
	ORG	200H		; Start at 200H
START:
	ORG	START+80H
	PUT	START+80H
TBASE:	EQU	START+100H
;**********************************************************
; DIRECT  --  Direction Table.  Used to determine the dir-
;             ection of movement of each piece.
;***********************************************************
DIRECT:	EQU	$-TBASE
	DB	+09,+11,-11,-09
	DB	+10,-10,+01,-01
	DB	-21,-12,+08,+19
	DB	+21,+12,-08,-19
	DB	+10,+10,+11,+09
	DB	-10,-10,-11,-09
;***********************************************************
; DPOINT  --  Direction Table Pointer. Used to determine
;             where to begin in the direction table for any
;             given piece.
;***********************************************************
DPOINT:	EQU	$-TBASE
	DB	20,16,8,0,4,0,0

;***********************************************************
; DCOUNT  --  Direction Table Counter. Used to determine
;             the number of directions of movement for any
;             given piece.
;***********************************************************
DCOUNT:	EQU	$-TBASE
	DB	4,4,8,4,4,8,8

;***********************************************************
; PVALUE  --  Point Value. Gives the point value of each
;             piece, or the worth of each piece.
;***********************************************************
PVALUE:	EQU	$-TBASE-1
	DB	1,3,3,5,9,10

;***********************************************************
; PIECES  --  The initial arrangement of the first rank of
;             pieces on the board. Use to set up the board
;             for the start of the game.
;***********************************************************
PIECES:	EQU	$-TBASE
	DB	4,2,3,5,6,3,2,4

;***********************************************************
; BOARD   --  Board Array.  Used to hold the current position
;             of the board during play. The board itself
;             looks like:
;             FFFFFFFFFFFFFFFFFFFF
;             FFFFFFFFFFFFFFFFFFFF
;             FF0402030506030204FF
;             FF0101010101010101FF
;             FF0000000000000000FF
;             FF0000000000000000FF
;             FF0000000000000060FF
;             FF0000000000000000FF
;             FF8181818181818181FF
;             FF8482838586838284FF
;             FFFFFFFFFFFFFFFFFFFF
;             FFFFFFFFFFFFFFFFFFFF
;             The values of FF form the border of the
;             board, and are used to indicate when a piece
;             moves off the board. The individual bits of
;             the other bytes in the board array are as
;             follows:
;             Bit 7 -- Color of the piece
;                     1 -- Black
;                     0 -- White
;             Bit 6 -- Not used
;             Bit 5 -- Not used
;             Bit 4 --Castle flag for Kings only
;             Bit 3 -- Piece has moved flag
;             Bits 2-0 Piece type
;                     1 -- Pawn
;                     2 -- Knight
;                     3 -- Bishop
;                     4 -- Rook
;                     5 -- Queen
;                     6 -- King
;                     7 -- Not used
;                     0 -- Empty Square
;***********************************************************
BOARD:	EQU	$-TBASE
BOARDA:	DS	120

;***********************************************************
; ATKLIST -- Attack List. A two part array, the first
;            half for white and the second half for black.
;            It is used to hold the attackers of any given
;            square in the order of their value.
;
; WACT   --  White Attack Count. This is the first
;            byte of the array and tells how many pieces are
;            in the white portion of the attack list.
;
; BACT   --  Black Attack Count. This is the eighth byte of
;            the array and does the same for black.
;***********************************************************
ATKLST:	DW	0,0,0,0,0,0,0
WACT:	EQU	ATKLST
BACT:	EQU	ATKLST+7

;***********************************************************
; PLIST   --  Pinned Piece Array. This is a two part array.
;             PLISTA contains the pinned piece position.
;             PLISTD contains the direction from the pinned
;             piece to the attacker.
;***********************************************************
PLIST:	EQU	$-TBASE-1
PLISTD:	EQU	PLIST+10
PLISTA:	DW	0,0,0,0,0,0,0,0,0,0

;***********************************************************
; POSK    --  Position of Kings. A two byte area, the first
;             byte of which hold the position of the white
;             king and the second holding the position of
;             the black king.
;
; POSQ    --  Position of Queens. Like POSK,but for queens.
;***********************************************************
POSK:	DB	24,95
POSQ:	DB	14,94
	DB	-1

;***********************************************************
; SCORE   --  Score Array. Used during Alpha-Beta pruning to
;             hold the scores at each ply. It includes two
;             "dummy" entries for ply -1 and ply 0.
;***********************************************************
SCORE:	DW	0,0,0,0,0,0

;***********************************************************
; PLYIX   --  Ply Table. Contains pairs of pointers, a pair
;             for each ply. The first pointer points to the
;             top of the list of possible moves at that ply.
;             The second pointer points to which move in the
;             list is the one currently being considered.
;***********************************************************
PLYIX:	DW	0,0,0,0,0,0,0,0,0,0
	DW	0,0,0,0,0,0,0,0,0,0

;***********************************************************
; STACK   --  Contains the stack for the program.
;***********************************************************
	ORG	START+2FFH
STACK:

;***********************************************************
; TABLE INDICES SECTION
;
; M1-M4   --  Working indices used to index into
;             the board array.
;
; T1-T3   --  Working indices used to index into Direction
;             Count, Direction Value, and Piece Value tables.
;
; INDX1   --  General working indices. Used for various
; INDX2       purposes.
;
; NPINS   --  Number of Pins. Count and pointer into the
;             pinned piece list.
;
; MLPTRI  --  Pointer into the ply table which tells
;             which pair of pointers are in current use.
;
; MLPTRJ  --  Pointer into the move list to the move that is
;             currently being processed.
;
; SCRIX   --  Score Index. Pointer to the score table for
;             the ply being examined.
;
; BESTM   --  Pointer into the move list for the move that
;             is currently considered the best by the
;             Alpha-Beta pruning process.
;
; MLLST   --  Pointer to the previous move placed in the move
;             list. Used during generation of the move list.
;
; MLNXT   --  Pointer to the next available space in the move
;             list.
;
;***********************************************************
	ORG	START+0
	PUT	START+0
M1:	DW	TBASE
M2:	DW	TBASE
M3:	DW	TBASE
M4:	DW	TBASE
T1:	DW	TBASE
T2:	DW	TBASE
T3:	DW	TBASE
INDX1:	DW	TBASE
INDX2:	DW	TBASE
NPINS:	DW	TBASE
MLPTRI:	DW	PLYIX
MLPTRJ:	DW	0
SCRIX:	DW	0
BESTM:	DW	0
MLLST:	DW	0
MLNXT:	DW	MLIST

;***********************************************************
; VARIABLES SECTION
;
; KOLOR   --  Indicates computer's color. White is 0, and
;             Black is 80H.
;
; COLOR   --  Indicates color of the side with the move.
;
; P1-P3   --  Working area to hold the contents of the board
;             array for a given square.
;
; PMATE   --  The move number at which a checkmate is
;             discovered during look ahead.
;
; MOVENO  --  Current move number.
;
; PLYMAX  --  Maximum depth of search using Alpha-Beta
;             pruning.
;
; NPLY    --  Current ply number during Alpha-Beta
;             pruning.
;
; CKFLG   --  A non-zero value indicates the king is in check.
;
; MATEF   --  A zero value indicates no legal moves.
;
; VALM    --  The score of the current move being examined.
;
; BRDC    --  A measure of mobility equal to the total number
;             of squares white can move to minus the number
;             black can move to.
;
; PTSL    --  The maximum number of points which could be lost
;             through an exchange by the player not on the
;             move.
;
; PTSW1   --  The maximum number of points which could be won
;             through an exchange by the player not on the
;             move.
;
; PTSW2   --  The second highest number of points which could
;             be won through a different exchange by the player
;             not on the move.
;
; MTRL    --  A measure of the difference in material
;             currently on the board. It is the total value of
;             the white pieces minus the total value of the
;             black pieces.
;
; BC0     --  The value of board control(BRDC) at ply 0.
;
; MV0     --  The value of material(MTRL) at ply 0.
;
; PTSCK   --  A non-zero value indicates that the piece has
;             just moved itself into a losing exchange of
;             material.
;
; BMOVES  --  Our very tiny book of openings. Determines
;             the first move for the computer.
;
;***********************************************************
KOLOR:	DB	0
COLOR:	DB	0
P1:	DB	0
P2:	DB	0
P3:	DB	0
PMATE:	DB	0
MOVENO:	DB	0
PLYMAX:	DB	2
NPLY:	DB	0
CKFLG:	DB	0
MATEF:	DB	0
VALM:	DB	0
BRDC:	DB	0
PTSL:	DB	0
PTSW1:	DB	0
PTSW2:	DB	0
MTRL:	DB	0
BC0:	DB	0
MV0:	DB	0
PTSCK:	DB	0
BMOVES:	DB	35,55,10H
	DB	34,54,10H
	DB	85,65,10H
	DB	84,64,10H

;***********************************************************
; MOVE LIST SECTION
;
; MLIST   --  A 2048 byte storage area for generated moves.
;             This area must be large enough to hold all
;             the moves for a single leg of the move tree.
;
; MLEND   --  The address of the last available location
;             in the move list.
;
; MLPTR   --  The Move List is a linked list of individual
;             moves each of which is 6 bytes in length. The
;             move list pointer(MLPTR) is the link field
;             within a move.
;
; MLFRP   --  The field in the move entry which gives the
;             board position from which the piece is moving.
;
; MLTOP   --  The field in the move entry which gives the
;             board position to which the piece is moving.
;
; MLFLG   --  A field in the move entry which contains flag
;             information. The meaning of each bit is as
;             follows:
;             Bit 7  --  The color of any captured piece
;                        0 -- White
;                        1 -- Black
;             Bit 6  --  Double move flag (set for castling and
;                        en passant pawn captures)
;             Bit 5  --  Pawn Promotion flag; set when pawn
;                        promotes.
;             Bit 4  --  When set, this flag indicates that
;                        this is the first move for the
;                        piece on the move.
;             Bit 3  --  This flag is set is there is a piece
;                        captured, and that piece has moved at
;                        least once.
;             Bits 2-0   Describe the captured piece.  A
;                        zero value indicates no capture.
;
; MLVAL   --  The field in the move entry which contains the
;             score assigned to the move.
;
;***********************************************************
	ORG	START+300H
	PUT	START+300H
MLIST:	DS	2048
MLEND:	EQU	MLIST+2040
MLPTR:	EQU	0
MLFRP:	EQU	2
MLTOP:	EQU	3
MLFLG:	EQU	4
MLVAL:	EQU	5

;***********************************************************
; PROGRAM CODE SECTION
;***********************************************************
; BOARD SETUP ROUTINE
;***********************************************************
; FUNCTION:   To initialize the board array, setting the
;             pieces in their initial positions for the
;             start of the game.
;
; CALLED BY:  DRIVER
;
; CALLS:      None
;
; ARGUMENTS:  None
;***********************************************************
INITBD:	MOV	CX,60		; Pre-fill board with -1's
	MOV	DI,BOARDA
	MOV	AX,-1
	REP
	STOW
	MOV	CH,8
	MOV	SI,BOARDA
IB2:	MOV	AL,[SI-8]	; Fill non-border squares
	MOV	[SI+21],AL	; White pieces
	LAHF
	OR	AL,080H
	SAHF			; Change to black
	MOV	[SI+91],AL	; Black pieces
	MOV	B,[SI+31],PAWN	; White Pawns
	MOV	B,[SI+81],BPAWN	; Black Pawns
	MOV	B,[SI+41],0	; Empty squares
	MOV	B,[SI+51],0
	MOV	B,[SI+61],0
	MOV	B,[SI+71],0
	INC	SI
	DEC	CH
	JNZ	IB2
	MOV	SI,POSK		; Init King/Queen position list
	MOV	B,[SI+0],25
	MOV	B,[SI+1],95
	MOV	B,[SI+2],24
	MOV	B,[SI+3],94
	RET

;***********************************************************
; PATH ROUTINE
;***********************************************************
; FUNCTION:   To generate a single possible move for a given
;             piece along its current path of motion including:

;                Fetching the contents of the board at the new
;                position, and setting a flag describing the
;                contents:
;                          0  --  New position is empty
;                          1  --  Encountered a piece of the
;                                 opposite color
;                          2  --  Encountered a piece of the
;                                 same color
;                          3  --  New position is off the
;                                 board
;
; CALLED BY:  MPIECE
;             ATTACK
;             PINFND
;
; CALLS:      None
;
; ARGUMENTS:  Direction from the direction array giving the
;             constant to be added for the new position.
;***********************************************************
PATH:	ADD	[M2],CL		; Add direction constant to previous position
	MOV	SI,[M2]		; Load board index
	MOV	AL,[SI+BOARD]	; Get contents of board
	CMP	AL,-1		; In border area ?
	JZ	PA2		; Yes - jump
	MOV	[P2],AL		; Save piece
	MOV	AH,AL		; Save piece in register
	AND	AL,7		; Clear flags
	MOV	[T2],AL		; Save piece type
	JZ	RET		; Return if empty
	XOR	AH,[P1]		; Compare with moving piece
	SHL	AH		; Set flag
	MOV	AL,2
	SBB	AL,0
	RET			; Return
PA2:	MOV	AL,3		; Set off board flag
	RET

;***********************************************************
; PIECE MOVER ROUTINE
;***********************************************************
; FUNCTION:   To generate all the possible legal moves for a
;             given piece.
;
; CALLED BY:  GENMOV
;
; CALLS:      PATH
;             ADMOVE
;             CASTLE
;             ENPSNT
;
; ARGUMENTS:  The piece to be moved.
;***********************************************************
MPIECE:	XOR	AL,[BX]		; Piece to move
	AND	AL,87H		; Clear flag bit
	CMP	AL,BPAWN	; Is it a black Pawn ?
	JNZ	MP1		; No-Skip
	DEC	AL		; Decrement for black Pawns
MP1:	AND	AL,7		; Get piece type
	MOV	[T1],AL		; Save piece type
	MOV	DI,[T1]		; Load index to DCOUNT/DPOINT
	MOV	CH,[DI+DCOUNT]	; Get direction count
	MOV	AL,[DI+DPOINT]	; Get direction pointer
	MOV	[INDX2],AL	; Save as index to direct
	MOV	DI,[INDX2]	; Load index
MP5:	MOV	CL,[DI+DIRECT]	; Get move direction
	MOV	AL,[M1]		; From position
	MOV	[M2],AL		; Initialize to position
MP10:	CALL	PATH		; Calculate next position
	CMP	AL,2		; Ready for new direction ?
	JNC	MP15		; Yes - Jump
	AND	AL,AL		; Test for empty square
	PUSHF
	MOV	AL,[T1]		; Get piece moved
	CMP	AL,PAWN+1	; Is it a Pawn ?
	JC	MP20		; Yes - Jump
	CALL	ADMOVE		; Add move to list
	POPF
	JNZ	MP15		; No - Jump
	MOV	AL,[T1]		; Piece type
	CMP	AL,KING		; King ?
	JZ	MP15		; Yes - Jump
	CMP	AL,BISHOP	; Bishop, Rook, or Queen ?
	JNC	MP10		; Yes - Jump
MP15:	INC	DI		; Increment direction index
	DEC	CH
	JNZ	MP5		; Decr. count-jump if non-zerc
	MOV	AL,[T1]		; Piece type
	CMP	AL,KING		; King ?
	JNZ	RET
	JMP	CASTLE		; Yes - Try Castling
; ***** PAWN LOGIC *****
MP20:	MOV	AL,CH		; Counter for direction
	CMP	AL,3		; On diagonal moves ?
	JC	MP35		; Yes - Jump
	JZ	MP30		; -or-jump if on 2 square move
	POPF
	JNZ	MP15		; No - jump
	MOV	AL,[M2]		; Get "to" position
	CMP	AL,91		; Promote white Pawn ?
	JNC	MP25		; Yes - Jump
	CMP	AL,29		; Promote black Pawn ?
	JNC	MP26		; No - Jump
MP25:	OR	B,[P2],020H	; Set promote flag
MP26:	CALL	ADMOVE		; Add to move list
	INC	DI		; Adjust to two square move
	DEC	CH
	TEST	B,[P1],008H	; Check Pawn moved flag, has it moved before ?
	JZ	MP10		; No - Jump
	JMP	MP15		; Jump
MP30:	POPF
	JNZ	MP15		; No - Jump
MP31:	CALL	ADMOVE		; Add to move list
	JMP	MP15		; Jump
MP35:	POPF
	JZ	MP36		; Yes - Jump
	MOV	AL,[M2]		; Get "to" position
	CMP	AL,91		; Promote white Pawn ?
	JNC	MP37		; Yes - Jump
	CMP	AL,29		; Black Pawn promotion ?
	JNC	MP31		; No- Jump
MP37:	OR	B,[P2],020H	; Set promote flag
	JP	MP31		; Jump
MP36:	CALL	ENPSNT		; Try en passant capture
	JMP	MP15		; Jump

;***********************************************************
; EN PASSANT ROUTINE
;***********************************************************
; FUNCTION:   --  To test for en passant Pawn capture and
;                 to add it to the move list if it is
;                 legal.
;
; CALLED BY:  --  MPIECE
;
; CALLS:      --  ADMOVE
;                 ADJPTR
;
; ARGUMENTS:  --  None
;***********************************************************
ENPSNT:	MOV	AL,[M1]		; Set position of Pawn
	TEST	B,[P1],080H	; Check color, is it white ?
	JZ	EP5		; Yes - skip
	ADD	AL,10		; Add 10 for black
EP5:	CMP	AL,61		; On en passant capture rank ?
	JC	RET		; No - return
	CMP	AL,69		; On en passant capture rank ?
	JNC	RET		; No - return
	MOV	SI,[MLPTRJ]	; Get pointer to previous move
	TEST	B,[SI+MLFLG],010H ; First move for that piece ?
	JZ	RET		; No - return
	MOV	AL,[SI+MLTOP]	; Get "to" position
	MOV	[M4],AL		; Store as index to board
	MOV	SI,[M4]		; Load board index
	MOV	AL,[SI+BOARD]	; Get piece moved
	MOV	[P3],AL		; Save it
	AND	AL,7		; Get piece type
	CMP	AL,PAWN		; Is it a Pawn ?
	JNZ	RET		; No - return
	MOV	AL,[M4]		; Get "to" position
	MOV	BX,M2		; Get present "to" position
	SUB	AL,[BX]		; Find difference
	JNS	EP10		; Positive ? Yes - Jump
	NEG	AL		; Else take absolute value
EP10:	CMP	AL,10		; Is difference 10 ?
	JNZ	RET		; No - return
	OR	B,[P2],040H	; Set double move flag
	CALL	ADMOVE		; Add Pawn move to move list
	MOV	AL,[M1]		; Save initial Pawn position
	MOV	[M3],AL
	MOV	AL,[M4]		; Set "from" and "to" positions
				; for dummy move
	MOV	[M1],AL
	MOV	[M2],AL
	MOV	AL,[P3]		; Save captured Pawn
	MOV	[P2],AL
	CALL	ADMOVE		; Add Pawn capture to move list
	MOV	AL,[M3]		; Restore "from" position
	MOV	[M1],AL

;***********************************************************
; ADJUST MOVE LIST POINTER FOR DOUBLE MOVE
;***********************************************************
; FUNCTION:   --  To adjust move list pointer to link around
;                 second move in double move.
;
; CALLED BY:  --  ENPSNT
;                 CASTLE
;                 (This mini-routine is not really called,
;                 but is jumped to to save time.)
;
; CALLS:      --  None
;
; ARGUMENTS:  --  None
;***********************************************************
ADJPTR:	MOV	BX,[MLLST]	; Get list pointer
	SUB	BX,6		; Back up list pointer
	MOV	[MLLST],BX	; Save list pointer
	MOV	[BX],0		; Zero out link
	RET			; Return

;***********************************************************
; CASTLE ROUTINE
;***********************************************************
; FUNCTION:   --  To determine whether castling is legal
;                 (Queen side, King side, or both) and add it
;                 to the move list if it is.
;
; CALLED BY:  --  MPIECE
;
; CALLS:      --  ATTACK
;                 ADMOVE
;                 ADJPTR
;
; ARGUMENTS:  --  None
;***********************************************************
CASTLE:	
	TEST	B,[P1],008H	; Has king moved ?
	JNZ	RET		; Yes - return
	MOV	AL,[CKFLG]	; Fetch Check Flag
	AND	AL,AL		; Is the King in check ?
	JNZ	RET		; Yes - Return
	MOV	CX,0FF03H	; Initialize King-side values
CA5:	ADD	CL,[M1]		; Rook position
	MOV	AL,CL
	MOV	[M3],AL		; Store as board index
	MOV	SI,[M3]		; Load board index
	MOV	AL,[SI+BOARD]	; Get contents of board
	AND	AL,7FH		; Clear color bit
	CMP	AL,ROOK		; Has Rook ever moved ?
	JNZ	CA20		; Yes - Jump
	MOV	AL,CL		; Restore Rook position
	JP	CA15		; Jump
CA10:	MOV	SI,[M3]		; Load board index
	MOV	AL,[SI+BOARD]	; Get contents of board
	AND	AL,AL		; Empty ?
	JNZ	CA20		; No - Jump
	MOV	AL,[M3]		; Current position
	CMP	AL,22		; White Queen Knight square ?
	JZ	CA15		; Yes - Jump
	CMP	AL,92		; Black Queen Knight square ?
	JZ	CA15		; Yes - Jump
	CALL	ATTACK		; Look for attack on square
	AND	AL,AL		; Any attackers ?
	JNZ	CA20		; Yes - Jump
	MOV	AL,[M3]		; Current position
CA15:	ADD	AL,CH		; Next position
	MOV	[M3],AL		; Save as board index
	MOV	BX,M1		; King position
	CMP	AL,[BX]		; Reached King ?
	JNZ	CA10		; No - jump
	SUB	AL,CH		; Determine King's position
	SUB	AL,CH
	MOV	[M2],AL		; Save it
	MOV	BX,P2		; Address of flags
	MOV	B,[BX],40H	; Set double move flag
	CALL	ADMOVE		; Put king move in list
	MOV	BX,M1		; Addr of King "from" position
	MOV	AL,[BX]		; Get King's "from" position
	MOV	[BX],CL		; Store Rook "from" position
	SUB	AL,CH		; Get Rook "to" position
	MOV	[M2],AL		; Store Rook "to" position
	XOR	AL,AL		; Zero
	MOV	[P2],AL		; Zero move flags
	CALL	ADMOVE		; Put Rook move in list
	CALL	ADJPTR		; Re-adjust move list pointer
	MOV	AL,[M3]		; Restore King position
	MOV	[M1],AL		; Store
CA20:	MOV	AL,CH		; Scan Index
	CMP	AL,1		; Done ?
	JZ	RET		; Yes - return
	MOV	CX,01FCH	; Set Queen-side initial values
	JMP	CA5		; Jump

;***********************************************************
; ADMOVE ROUTINE
;***********************************************************
; FUNCTION:   --  To add a move to the move list
;
; CALLED BY:  --  MPIECE
;                 ENPSNT
;                 CASTLE
;
; CALLS:      --  None
;
; ARGUMENT:  --  None
;***********************************************************
ADMOVE:	MOV	DX,[MLNXT]	; Addr of next loc in move list
	MOV	BX,MLEND	; Address of list end
	SUB	BX,DX		; Calculate difference
	JC	AM10		; Jump if out of space
	MOV	BX,[MLLST]	; Addr of prev. list area
	MOV	[MLLST],DX	; Save next as previous
	MOV	[BX],DX		; Store link address
	TEST	B,[P1],008H	; Has moved piece moved before ?
	JNZ	AM5		; Yes - jump
	OR	B,[P2],010H	; Set first move flag
AM5:	XCHG	DX,DI		; Address of move area
	XOR	AX,AX		; Store zero in link address
	CLD
	STOW
	MOV	AL,[M1]		; Store "from" move position
	STOB
	MOV	AL,[M2]		; Store "to" move position
	STOB
	MOV	AL,[P2]		; Store move flags/capt. piece
	STOB
	XOR	AL,AL		; Store initial move value
	STOB
	MOV	[MLNXT],DI	; Save address for next move
	MOV	DI,DX
	RET			; Return
AM10:	MOV	[BX],0		; Abort entry on table ovflow
	RET

;***********************************************************
; GENERATE MOVE ROUTINE
;***********************************************************
; FUNCTION:  --  To generate the move set for all of the
;                pieces of a given color.
;
; CALLED BY: --  FNDMOV
;
; CALLS:     --  MPIECE
;                INCHK
;
; ARGUMENTS: --  None
;***********************************************************
GENMOV:	CALL	INCHK		; Test for King in check
	MOV	[CKFLG],AL	; Save attack count as flag
	MOV	DX,[MLNXT]	; Addr of next avail list space
	MOV	BX,[MLPTRI]	; Ply list pointer index
	INC	BX		; Increment to next ply
	INC	BX
	MOV	[BX],DX		; Save move list pointer
	INC	BX
	INC	BX
	MOV	[MLPTRI],BX	; Save new index
	MOV	[MLLST],BX	; Last pointer for chain init.
	MOV	AL,21		; First position on board
GM5:	MOV	[M1],AL		; Save as index
	MOV	SI,[M1]		; Load board index
	MOV	AL,[SI+BOARD]	; Fetch board contents
	AND	AL,AL		; Is it empty ?
	JZ	GM10		; Yes - Jump
	CMP	AL,-1		; Is it a border square ?
	JZ	GM10		; Yes - Jump
	MOV	[P1],AL		; Save piece
	MOV	BX,COLOR	; Address of color of piece
	XOR	AL,[BX]		; Test color of piece
	TEST	AL,080H		; Match ?
	JNZ	GM10
	CALL	MPIECE		; Yes - call Move Piece
GM10:	MOV	AL,[M1]		; Fetch current board position
	INC	AL		; Incr to next board position
	CMP	AL,99		; End of board array ?
	JNZ	GM5		; No - Jump
	RET			; Return

;***********************************************************
; CHECK ROUTINE
;***********************************************************
; FUNCTION:   --  To determine whether or not the
;                 King is in check.
;
; CALLED BY:  --  GENMOV
;                 FNDMOV
;                 EVAL
;
; CALLS:      --  ATTACK
;
; ARGUMENTS:  --  Color of King
;***********************************************************
INCHK:	MOV	AL,[COLOR]	; Get color
INCHK1:	MOV	BX,POSK		; Addr of white King position
	AND	AL,AL		; White ?
	JZ	IC5		; Yes - Skip
	INC	BX		; Addr of black King position
IC5:	MOV	AL,[BX]		; Fetch King position
	MOV	[M3],AL		; Save
	MOV	SI,[M3]		; Load board index
	MOV	AL,[SI+BOARD]	; Fetch board contents
	MOV	[P1],AL		; Save
	AND	AL,7		; Get piece type
	MOV	[T1],AL		; Save

;***********************************************************
; ATTACK ROUTINE
;***********************************************************
; FUNCTION:   --  To find all attackers on a given square
;                 by scanning outward from the square
;                 until a piece is found that attacks
;                 that square, or a piece is found that
;                 doesn't attack that square, or the edge
;                 of the board is reached.
;
;                 In determining which pieces attack
;                 a square, this routine also takes into
;                 account the ability of certain pieces to
;                 attack through another attacking piece. (For
;                 example a queen lined up behind a bishop
;                 of her same color along a diagonal.) The
;                 bishop is then said to be transparent to the
;                 queen, since both participate in the
;                 attack.
;
;                 In the case where this routine is called
;                 by CASTLE or INCHK, the routine is
;                 terminated as soon as an attacker of the
;                 opposite color is encountered.
;
; CALLED BY:  --  POINTS
;                 PINFND
;                 CASTLE
;                 INCHK
;
; CALLS:      --  ATKADJ
;                 ATKOUT
;
; ARGUMENTS:  --  None
;***********************************************************
ATTACK:	PUSH	CX		; Save Register CX
	MOV	BP,[M3]		; Get piece index
	ADD	BP,BOARD	; Add board pointer to it
	MOV	DH,0		; Init. scan count/flags
	MOV	SI,DIRECT+TBASE	; Load direction table
	MOV	AH,KING		; Check for a King
	CALL	ATKADJ		; Scan adjacent squares
	MOV	AH,KNIGHT	; Check for a Knight
	CALL	ATKADJ		; Scan adjacent squares
	MOV	AH,20H		; Bit 5 set
	MOV	AL,[BP+11]	; Get piece at +11
	AND	AL,87H		; Clear flag bit
	CMP	AL,BPAWN	; Black Pawn ?
	JNZ	AT5		; No - jump
	OR	[BP+11],AH	; Turn on bit 5
AT5:	MOV	AL,[BP+9]	; Get piece at +9
	AND	AL,87H		; Clear flag bit
	CMP	AL,BPAWN	; Black Pawn ?
	JNZ	AT10		; No - jump
	OR	[BP+9],AH	; Turn on bit 5
AT10:	MOV	AL,[BP-11]	; Get piece at -11
	AND	AL,87H		; Clear flag bit
	CMP	AL,PAWN		; White Pawn ?
	JNZ	AT15		; No - jump
	OR	[BP-11],AH	; Turn on bit 5
AT15:	MOV	AL,[BP-9]	; Get piece at -9
	AND	AL,87H		; Clear flag bit
	CMP	AL,PAWN		; White Pawn ?
	JNZ	AT20		; No - jump
	OR	[BP-9],AH	; Turn on bit 5
AT20:	MOV	SI,DIRECT+TBASE	; Load direction table
	MOV	AH,BISHOP	; Check for a Bishop
	CALL	ATKOUT		; Scan outwards
	MOV	AH,ROOK		; Check for a Rook
	CALL	ATKOUT		; Scan outwards
	XOR	AL,AL		; No attackers
	POP	CX		; Restore CX reg
	RET			; Return

;***********************************************************
; ATTACK ADJACENT SCAN ROUTINE
;***********************************************************
; FUNCTION:   --  To scan for a specified attacker on adjacent
;                 squares.
;
; CALLED BY:  --  ATTACK
;
; CALLS:      --  ATKCHK
;
; ARGUMENTS:  --  The piece under attack. The attacker.
;***********************************************************
ATKADJ:	MOV	CX,8		; 8 directions to scan
AA5:	XCHG	AX,BX		; Save AX
	LODB			; Get direction byte
	CBW			; Convert to word
	XCHG	AX,BX		; Save direction and restore AX
	MOV	DI,BP		; Load pointer to piece
	ADD	DI,BX		; Add direction constant
	MOV	AL,[DI]		; Get attacking piece
	AND	AL,7		; Get piece type
	CMP	AL,AH		; Same as what we want ?
	JNZ	AA10		; No - jump
	CALL	ATKCHK		; Check and save attacker
AA10:	LOOP	AA5		; Go check for next direction
	RET			; Return

;***********************************************************
; ATTACK OUTWARD SCAN ROUTINE
;***********************************************************
; FUNCTION:   --  To scan for a specified attacker outwards
;                 from the piece under attack, until found
;                 or edge of the board is reached.
;
; CALLED BY:  --  ATTACK
;
; CALLS:      --  ATKCHK
;
; ARGUMENTS:  --  The piece under attack. The attacker.
;***********************************************************
ATKOUT:	MOV	CL,4		; 4 directions to scan
AO5:	MOV	DX,0C0H		; Bitmask for color flags
	XCHG	AX,BX		; Save AX
	LODB			; Get direction byte
	CBW			; Convert to word
	XCHG	AX,BX		; Save direction and restore AX
	MOV	DI,BP		; Load pointer to piece
AO10:	ADD	DI,BX		; Add direction constant
	MOV	AL,[DI]		; Get attacking piece
	AND	AL,27H		; Get piece type and bit 5
	JZ	AO10		; No piece, keep going
	CMP	AL,AH		; Same as what we want ?
	JZ	AO22		; Yes - jump
	CMP	AL,QUEEN	; Queen ?
	JZ	AO20		; Yes - jump
	CMP	AL,PAWN+20H	; Pawn with bit 5 ?
	JZ	AO21		; Yes - jump
AO15:	LOOP	AO5		; Go check for next direction
	RET			; Return
AO20:	INC	DH		; Set Queen found flag
AO21:	AND	B,[DI],0DFH	; Remove bit 5 for piece
AO22:	MOV	AL,[DI]		; Get piece
	ADD	AL,80H		; CY if back, NC if white
	RCR	AL		; Bit 7 set if black, bit 6 if white
	AND	DL,AL		; Keep only bits 6 and 7
	JZ	AO15		; Nothing, next direction
	CALL	ATKCHK		; Check and save attack
	JP	AO10		; Keeping going that direction

;***********************************************************
; ATTACK CHECK AND SAVE ROUTINE
;***********************************************************
; FUNCTION:   --  To check if a piece can attack the target
;                 square and save the attacking piece value
;                 in the attack list.
;
;                 The pin piece list is checked for the
;                 attacking piece, and if found there, the
;                 piece is not included in the attack list.
;
;                 In the case where ATTACK is called by
;                 CASTLE or INCHK, control is returned to
;                 the aforementioned routines as soon as an
;                 attacker of the opposite color is encountered.
;
; CALLED BY:  --  ATTACK
;
; CALLS:      --  None
;
; ARGUMENTS:  --  The attacking piece. The piece under attack.
;***********************************************************
ATKCHK:	MOV	AL,[DI]		; Get piece
	CMP	B,[T1],7	; Call from POINTS ?
	JZ	ACK10		; Yes - jump
	XOR	AL,[BP]		; Attacker and target same color ?
	JNS	RET		; Yes - return
	POP	AX
	POP	AX		; Set SP level to ATTACK
	MOV	AX,0DFFFH	; FF (border) in AL and DF in AH
	CMP	[BP+9],AL	; Is +9 border ?
	JZ	ACK5		; Yes, jump
	AND	[BP+9],AH	; Remove bit 5 for piece
ACK5:	CMP	[BP+11],AL	; Is +11 border ?
	JZ	ACK6		; Yes - jump
	AND	[BP+11],AH	; Remove bit 5 for piece
ACK6:	CMP	[BP-9],AL	; Is -9 border ?
	JZ	ACK7		; Yes - jump
	AND	[BP-9],AH	; Remove bit 5 for piece
ACK7:	CMP	[BP-11],AL	; Is -11 border ?
	JZ	ACK8		; Yes - jump
	AND	[BP-11],AH	; Remove bit 5 for piece
ACK8:	MOV	AL,1		; Set attacker found flag
	POP	CX		; Restore CX reg
	RET			; Return from ATTACK
ACK10:	PUSH	CX		; Save regs
	PUSH	DI
	MOV	CL,[NPINS]	; Number of pinned pieces
	JCXZ	ACK26		; No pins - jump
	PUSH	AX		; Save AX
	MOV	AX,DI		; Load piece pointer in AX
	SUB	AX,BOARDA	; Minus BOARDA for position
	MOV	DI,PLISTA	; Pin list address
ACK15:	OR	AL,AL		; Set flags for REP
	REPZ
	SCAB			; Search list for position
	JNZ	ACK25		; Continue if not found
	OR	AH,AH		; Is this the first find ?
	JNZ	ACK20		; No - jump
	MOV	AH,[DI+9]	; Get direction
	CMP	AH,BL		; Same as attacking direction ?
	JZ	ACK15		; Yes - jump
	NEG	AH		; Opposite direction ?
	CMP	AH,BL		; Same as attacking direction ?
	JZ	ACK15		; Yes - jump
ACK20:	POP	AX		; Restore regs.
	POP	DI
	POP	CX
	RET			; Return to ATTACK
ACK25:	POP	AX		; Restore AX
ACK26:	MOV	CL,AL		; Put piece in CL
	AND	CL,7		; Get piece type
	MOV	DI,PVALUE+TBASE	; PVALUE list address
	ADD	DI,CX		; Point to piece value
	MOV	CL,[DI]		; Get point value of piece
	MOV	DI,ATKLST	; Init address of attack list
	TEST	AL,80H		; Is it white ?
	JZ	ACK30		; Yes - jump
	ADD	DI,7		; Attack list address
ACK30:	OR	DH,DH		; Queen found this scan ?
	JZ	ACK31		; No - jump
	MOV	AL,QUEEN	; Use Queen slot in attack list
ACK31:	AND	AL,7		; Attacking piece type
	INC	B,[DI]		; Increment list count
	XCHG	AL,CL		; Save point value in AL
	ADD	DI,CX		; Attack list slot address
	MOV	CH,[DI]		; Get data already there
	TEST	CH,0FH		; Is first slot empty ?
	JZ	ACK40		; Yes - jump
	TEST	CH,0F0H		; Is second slot empty ?
	JZ	ACK35		; Yes - jump
	INC	DI		; Increment to King slot
	MOV	CH,[DI]		; Get byte
	XCHG	AL,CH		; Byte to AL, point value to CH
ACK35:	SHL	AL		; Lower bits to upper
	SHL	AL
	SHL	AL
	SHL	AL
	OR	AL,CH		; Combine with point value
ACK40:	MOV	[DI],AL		; Put back into attack list
	POP	DI		; Restore regs
	POP	CX
	RET			; Return

;***********************************************************
; PIN FIND ROUTINE
;***********************************************************
; FUNCTION:   --  To produce a list of all pieces pinned
;                 against the King or Queen, for both white
;                 and black.
;
; CALLED BY:  --  FNDMOV
;                 EVAL
;
; CALLS:      --  PATH
;                 ATTACK
;
; ARGUMENTS:  --  None
;***********************************************************
PINFND:	XOR	AL,AL		; Zero pin count
	MOV	[NPINS],AL
	MOV	DX,POSK		; Addr of King/Queen pos list
PF1:	MOV	BP,DX
	MOV	AL,[BP]		; Get position of royal piece
	AND	AL,AL		; Is it on board ?
	JNZ	PF1A		; Yes- continue
	JMP	PF26
PF1A:	CMP	AL,-1		; At end of list ?
	JZ	RET		; Yes return
	MOV	[M3],AL		; Save position as board index
	MOV	SI,[M3]		; Load index to board
	MOV	AL,[SI+BOARD]	; Get contents of board
	MOV	[P1],AL		; Save
	MOV	CH,8		; Init scan direction count
	XOR	AL,AL
	MOV	[INDX2],AL	; Init direction index
	MOV	DI,[INDX2]
PF2:	MOV	AL,[M3]		; Get King/Queen position
	MOV	[M2],AL		; Save
	XOR	AL,AL
	MOV	[M4],AL		; Clear pinned piece saved pos
	MOV	CL,[DI+DIRECT]	; Get direction of scan
PF5:	CALL	PATH		; Compute next position
	AND	AL,AL		; Is it empty ?
	JZ	PF5		; Yes - jump
	CMP	AL,3		; Off board ?
	JZ	JPF25		; Yes - jump
	CMP	AL,2		; Piece of same color
	MOV	AL,[M4]		; Load pinned piece position
	JZ	PF15		; Yes - jump
	AND	AL,AL		; Possible pin ?
	JZ	JPF25		; No - jump
	MOV	AL,[T2]		; Piece type encountered
	CMP	AL,QUEEN	; Queen ?
	JZ	PF19		; Yes - jump
	MOV	BL,AL		; Save piece type
	MOV	AL,CH		; Direction counter
	CMP	AL,5		; Non-diagonal direction ?
	JC	PF10		; Yes - jump
	MOV	AL,BL		; Piece type
	CMP	AL,BISHOP	; Bishop ?
	JNZ	PF25		; No - jump
	JMP	PF20		; Jump
JPF25:	JMP	PF25
PF10:	MOV	AL,BL		; Piece type
	CMP	AL,ROOK		; Rook ?
	JNZ	PF25		; No - jump
	JMP	PF20		; Jump
PF15:	AND	AL,AL		; Possible pin ?
	JNZ	PF25		; No - jump
	MOV	AL,[M2]		; Save possible pin position
	MOV	[M4],AL
	JMP	PF5		; Jump
PF19:	MOV	AL,[P1]		; Load King or Queen
	AND	AL,7		; Clear flags
	CMP	AL,QUEEN	; Queen ?
	JNZ	PF20		; No - jump
	PUSH	CX		; Save regs.
	PUSH	DX
	PUSH	DI
	XOR	AX,AX		; Zero out attack list
	MOV	CX,7
	MOV	BX,ATKLST
	XCHG	DI,BX
	CLD
	REP
	STOW
	XCHG	DI,BX
	MOV	AL,7		; Set attack flag
	MOV	[T1],AL
	CALL	ATTACK		; Find attackers/defenders
	MOV	BX,WACT		; White queen attackers
	MOV	DX,BACT		; Black queen attackers
	TEST	B,[P1],080H	; Is queen white ?
	JZ	PF19A		; Yes - skip
	XCHG	DX,BX		; Reverse for black
PF19A:	MOV	AL,[BX]		; Number of defenders
	XCHG	DX,BX		; Reverse for attackers
	SUB	AL,[BX]		; Defenders minus attackers
	DEC	AL		; Less 1
	POP	DI		; Restore regs.
	POP	DX
	POP	CX
	JNS	PF25		; Jump if pin not valid
PF20:	MOV	BX,NPINS	; Address of pinned piece count
	INC	B,[BX]		; Increment
	MOV	SI,[NPINS]	; Load pin list index
	MOV	[SI+PLISTD],CL	; Save direction of pin
	MOV	AL,[M4]		; Position of pinned piece
	MOV	[SI+PLIST],AL	; Save in list
PF25:	INC	DI		; Increment direction index
	DEC	CH
	JZ	PF26		; Done ? Yes - Continue
	JMP	PF2
PF26:	INC	DX		; Incr King/Queen pos index
	JMP	PF1		; Jump

;***********************************************************
; EXCHANGE ROUTINE
;***********************************************************
; FUNCTION:   --  To determine the exchange value of a
;                 piece on a given square by examining all
;                 attackers and defenders of that piece.
;
; CALLED BY:  --  POINTS
;
; CALLS:      --  NEXTAD
;
; ARGUMENTS:  --  None.
;***********************************************************
XCHNG:	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]		; Swap regs.
	MOV	AL,[P1]		; Piece attacked
	MOV	BX,WACT		; Addr of white attkrs/dfndrs
	MOV	DX,BACT		; Addr of black attkrs/dfndrs
	TEST	AL,080H		; Is piece white ?
	JZ	XC5		; Yes - jump
	XCHG	DX,BX		; Swap list pointers
XC5:	MOV	CH,[BX]		; Init list counts
	XCHG	DX,BX
	MOV	CL,[BX]
	XCHG	DX,BX
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]		; Restore regs.
	MOV	CL,0		; Init attacker/defender flag
	MOV	DL,0		; Init points lost count
	MOV	SI,[T3]		; Load piece value index
	MOV	DH,[SI+PVALUE]	; Get attacked piece value
	SAL	DH		; Double it
	MOV	CH,DH		; Save
	CALL	NEXTAD		; Retrieve first attacker
	JNZ	XC10
	JMP	RET		; Return if none
XC10:	MOV	BL,AL		; Save attacker value
	CALL	NEXTAD		; Get next defender
	JZ	XC18		; Jump if none
	LAHF
	CMP	CH,BL		; Attacked less than attacker ?
	JNC	XC19		; No - jump
XC15:	CMP	AL,BL		; Defender less than attacker ?
	JC	RET		; Yes - return
	CALL	NEXTAD		; Retrieve next attacker value
	JZ	RET		; Return if none
	MOV	BL,AL		; Save attacker value
	CALL	NEXTAD		; Retrieve next defender value
	JNZ	XC15		; Jump if none
XC18:	LAHF
XC19:	TEST	CL,001H		; Attacker or defender ?
	JZ	XC20		; Jump if defender
	NEG	CH		; Negate value for attacker
XC20:	ADD	DL,CH		; Total points lost
	SAHF
	JZ	RET		; Return if none
	MOV	CH,BL		; Prev attckr becomes defender
	JMP	XC10		; Jump

;***********************************************************
; NEXT ATTACKER/DEFENDER ROUTINE
;***********************************************************
; FUNCTION:   --  To retrieve the next attacker or defender
;                 piece value from the attack list, and delete
;                 that piece from the list.
;
; CALLED BY:  --  XCHNG
;
; CALLS:      --  None
;
; ARGUMENTS:  --  Attack list addresses.
;                 Side flag
;                 Attack list counts
;***********************************************************
NEXTAD:	INC	CL		; Increment side flag
	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]		; Swap registers
	XCHG	CH,CL		; Swap list counts
	XCHG	DX,BX		; Swap list pointers
	XOR	AL,AL
	CMP	AL,CH		; At end of list ?
	JZ	NX6		; Yes - jump
	DEC	CH		; Decrement list count
NX5:	INC	BX		; Increment list pointer
	CMP	AL,[BX]		; Check next item in list
	JZ	NX5		; Jump if empty
	MOV	AL,[BX]		; Get value from list
	MOV	AH,AL
	SHR	AH
	SHR	AH
	SHR	AH
	SHR	AH
	MOV	[BX],AH
	AND	AL,0FH
	DEC	BX		; Decrement list pointer
	ADD	AL,AL		; Double it
NX6:	XCHG	BX,[HL]
	XCHG	DX,[DE]
	XCHG	CX,[BC]		; Restore regs.
	RET			; Return

;***********************************************************
; POINT EVALUATION ROUTINE
;***********************************************************
;FUNCTION:   --  To perform a static board evaluation and
;                derive a score for a given board position
;
; CALLED BY:  --  FNDMOV
;                 EVAL
;
; CALLS:      --  ATTACK
;                 XCHNG
;                 LIMIT
;
; ARGUMENTS:  --  None
;***********************************************************
POINTS:	XOR	AL,AL		; Zero out variables
	MOV	[MTRL],AL
	MOV	[BRDC],AL
	MOV	[PTSL],AL
	MOV	[PTSW1],AL
	MOV	[PTSW2],AL
	MOV	[PTSCK],AL
	MOV	BX,T1		; Set attacker flag
	MOV	B,[BX],7
	MOV	AL,21		; Init to first square on board
PT5:	MOV	[M3],AL		; Save as board index
	MOV	SI,[M3]		; Load board index
	MOV	AL,[SI+BOARD]	; Get piece from board
	CMP	AL,-1		; Off board edge ?
	JNZ	PT5A
	JMP	PT25		; Yes - jump
PT5A:	MOV	BX,P1		; Save piece, if any
	MOV	[BX],AL
	AND	AL,7		; Save piece type, if any
	MOV	[T3],AL
	CMP	AL,KNIGHT	; Less than a Knight (Pawn) ?
	JC	PT6X		; Yes - Jump
	CMP	AL,ROOK		; Rook, Queen or King ?
	JC	PT6B		; No - jump
	CMP	AL,KING		; Is it a King ?
	JZ	PT6AA		; Yes - jump
	MOV	AL,[MOVENO]	; Get move number
	CMP	AL,7		; Less than 7 ?
	JC	PT6A		; Yes - Jump
	JMP	PT6X		; Jump
PT6AA:	TEST	B,[BX],010H	; Castled yet ?
	JZ	PT6A		; No - jump
	MOV	AL,+6		; Bonus for castling
	TEST	B,[BX],080H	; Check piece color
	JZ	PT6D		; Jump if white
	MOV	AL,-6		; Bonus for black castling
	JP	PT6D		; Jump
PT6A:	TEST	B,[BX],008H	; Has piece moved yet ?
	JZ	PT6X		; No - jump
	JP	PT6C		; Jump
PT6B:	TEST	B,[BX],008H	; Has piece moved yet ?
	JNZ	PT6X		; Yes - jump
PT6C:	MOV	AL,-2		; Two point penalty for white
	TEST	B,[BX],080H	; Check piece color
	JZ	PT6D		; Jump if white
	MOV	AL,+2		; Two point penalty for black
PT6D:	MOV	BX,BRDC		; Get address of board control
	ADD	[BX],AL		; Add on penalty/bonus points
PT6X:	XOR	AX,AX		; Zero out attack list
	MOV	CX,7
	MOV	BX,ATKLST
	XCHG	DI,BX
	CLD
	REP
	STOW
	XCHG	DI,BX
	CALL	ATTACK		; Build attack list for square
	MOV	BX,BACT		; Get black attacker count addr
	MOV	AL,[WACT]	; Get white attacker count
	SUB	AL,[BX]		; Compute count difference
	MOV	BX,BRDC		; Address of board control
	ADD	AL,[BX]		; Accum board control score
	MOV	[BX],AL		; Save
	MOV	AL,[P1]		; Get piece on current square
	AND	AL,AL		; Is it empty ?
	JZ	PT25		; Yes - jump
	CALL	XCHNG		; Evaluate exchange, if any
	XOR	AL,AL		; Check for a loss
	CMP	AL,DL		; Points lost ?
	JZ	PT23		; No - Jump
	DEC	DH		; Deduct half a Pawn value
	MOV	AL,[P1]		; Get piece under attack
	XOR	AL,[COLOR]	; Compare color of side just moved with piece
	TEST	AL,080H		; Do colors match ?
	MOV	AL,DL		; Points lost
	JNZ	PT20		; Jump if no match
	MOV	BX,PTSL		; Previous max points lost
	CMP	AL,[BX]		; Compare to current value
	JC	PT23		; Jump if greater than
	MOV	[BX],DL		; Store new value as max lost
	MOV	SI,[MLPTRJ]	; Load pointer to this move
	MOV	AL,[M3]		; Get position of lost piece
	CMP	AL,[SI+MLTOP]	; Is it the one moving ?
	JNZ	PT23		; No - jump
	MOV	[PTSCK],AL	; Save position as a flag
	JP	PT23		; Jump
PT20:	MOV	BX,PTSW1	; Previous maximum points won
	CMP	AL,[BX]		; Compare to current value
	JC	PT21		; Jump if greater than
	MOV	AL,[BX]		; Load previous max value
	MOV	[BX],DL		; Store new value as max won
PT21:	MOV	BX,PTSW2	; Previous 2nd max points won
	CMP	AL,[BX]		; Compare to current value
	JC	PT23		; Jump if greater than
	MOV	[BX],AL		; Store as new 2nd max lost
PT23:	TEST	B,[P1],080H	; Test piece color
	MOV	AL,DH		; Value of piece
	JZ	PT24		; Jump if white
	NEG	AL		; Negate for black
PT24:	MOV	BX,MTRL		; Get addrs of material total
	ADD	AL,[BX]		; Add new value
	MOV	[BX],AL		; Store
PT25:	MOV	AL,[M3]		; Get current board position
	INC	AL		; Increment
	CMP	AL,99		; At end of board ?
	JZ	PT25AA
	JMP	PT5		; No - jump
PT25AA:	MOV	AL,[PTSCK]	; Moving piece lost flag
	AND	AL,AL		; Was it lost ?
	JZ	PT25A		; No - jump
	MOV	AL,[PTSW2]	; 2nd max points won
	MOV	[PTSW1],AL	; Store as max points won
	XOR	AL,AL		; Zero out 2nd max points won
	MOV	[PTSW2],AL
PT25A:	MOV	AL,[PTSL]	; Get max points lost
	AND	AL,AL		; Is it zero ?
	JZ	PT26		; Yes - jump
	DEC	AL		; Decrement it
PT26:	MOV	CH,AL		; Save it
	MOV	AL,[PTSW1]	; Max,points won
	AND	AL,AL		; Is it zero ?
	JZ	PT27		; Yes - jump
	MOV	AL,[PTSW2]	; 2nd max points won
	AND	AL,AL		; Is it zero ?
	JZ	PT27		; Yes - jump
	DEC	AL		; Decrement it
	SHR	AL		; Divide it by 2
PT27:	SUB	AL,CH		; Subtract points lost
	TEST	B,[COLOR],080H	; Is color of side just moved white ?
	JZ	PT28		; Yes - jump
	NEG	AL		; Negate for black
PT28:	MOV	BX,MTRL		; Net material on board
	ADD	AL,[BX]		; Add exchange adjustments
	MOV	BX,MV0		; Material at ply 0
	SUB	AL,[BX]		; Subtract from current
	MOV	CH,AL		; Save
	MOV	AL,30		; Load material limit
	CALL	LIMIT		; Limit to plus or minus value
	MOV	DL,AL		; Save limited value
	MOV	AL,[BRDC]	; Get board control points
	MOV	BX,BC0		; Board control at ply zero
	SUB	AL,[BX]		; Get difference
	MOV	CH,AL		; Save
	MOV	AL,[PTSCK]	; Moving piece lost flag
	AND	AL,AL		; Is it zero ?
	JZ	PT29		; Yes - jump
	MOV	CH,0		; Zero board control points
PT29:	MOV	AL,6		; Load board control limit
	CALL	LIMIT		; Limit to plus or minus value
	MOV	DH,AL		; Save limited value
	MOV	AL,DL		; Get material points
	ADD	AL,AL		; Multiply by 4
	ADD	AL,AL
	ADD	AL,DH		; Add board control
	TEST	B,[COLOR],080H	; Is color of side just moved white ?
	JNZ	PT30		; No - jump
	NEG	AL		; Negate for white
PT30:	ADD	AL,80H		; Rescale score (neutral = 80H)
	MOV	[VALM],AL	; Save score
	MOV	SI,[MLPTRJ]	; Load move list pointer
	MOV	[SI+MLVAL],AL	; Save score in move list
	RET			; Return

;***********************************************************
; LIMIT ROUTINE
;***********************************************************
; FUNCTION:   --  To limit the magnitude of a given value
;                 to another given value.
;
; CALLED BY:  --  POINTS
;
; CALLS:      --  None
;
; ARGUMENTS:  --  Input  - Value, to be limited in the CH
;                          register.
;                        - Value to limit to in the AL register
;                 Output - Limited value in the AL register.
;***********************************************************
LIMIT:	TEST	CH,080H		; Is value negative ?
	JZ	LIM10		; No - jump
	NEG	AL		; Make positive
	CMP	AL,CH		; Compare to limit
	JNC	RET		; Return if outside limit
	MOV	AL,CH		; Output value as is
	RET			; Return
LIM10:	CMP	AL,CH		; Compare to limit
	JC	RET		; Return if outside limit
	MOV	AL,CH		; Output value as is
	RET			; Return

;***********************************************************
; MOVE ROUTINE
;***********************************************************
; FUNCTION:   --  To execute a move from the move list on the
;                 board array.
;
; CALLED BY:  --  CPTRMV
;                 PLYRMV
;                 EVAL
;                 FNDMOV
;                 VALMOV
;
; CALLS:      --  None
;
; ARGUMENTS:  --  None
;***********************************************************
MOVE:	MOV	BX,[MLPTRJ]	; Load move list pointer
	INC	BX		; Increment past link bytes
	INC	BX
MV1:	MOV	AL,[BX]		; "From" position
	MOV	[M1],AL		; Save
	INC	BX		; Increment pointer
	MOV	AL,[BX]		; "To" position
	MOV	[M2],AL		; Save
	INC	BX		; Increment pointer
	MOV	DH,[BX]		; Get captured piece/flags
	MOV	SI,[M1]		; Load "from" pos board index
	MOV	DL,[SI+BOARD]	; Get piece moved
	TEST	DH,020H		; Test Pawn promotion flag
	JNZ	MV15		; Jump if set
	MOV	AL,DL		; Piece moved
	AND	AL,7		; Clear flag bits
	CMP	AL,QUEEN	; Is it a queen ?
	JZ	MV20		; Yes - jump
	CMP	AL,KING		; Is it a king ?
	JZ	MV30		; Yes - jump
MV5:	MOV	DI,[M2]		; Load "to" pos board index
	OR	DL,008H		; Set piece moved flag
	MOV	[DI+BOARD],DL	; Insert piece at new position
	MOV	B,[SI+BOARD],0	; Empty previous position
	TEST	DH,040H		; Double move ?
	JNZ	MV40		; Yes - jump
	MOV	AL,DH		; Get captured piece, if any
	AND	AL,7
	CMP	AL,QUEEN	; Was it a queen ?
	JNZ	RET		; No - return
	MOV	BX,POSQ		; Addr of saved Queen position
	TEST	DH,080H		; Is Queen white ?
	JZ	MV10		; Yes - jump
	INC	BX		; Increment to black Queen pos
MV10:	XOR	AL,AL		; Set saved position to zero
	MOV	[BX],AL
	RET			; Return
MV15:	OR	DL,004H		; Change Pawn to a Queen
	JMP	MV5		; Jump
MV20:	MOV	BX,POSQ		; Addr of saved Queen position
MV21:	TEST	DL,080H		; Is Queen white ?
	JZ	MV22		; Yes - jump
	INC	BX		; Increment to black Queen pos
MV22:	MOV	AL,[M2]		; Get new Queen position
	MOV	[BX],AL		; Save
	JMP	MV5		; Jump
MV30:	MOV	BX,POSK		; Get saved King position
	TEST	DH,020H		; Castling ?
	JZ	MV21		; No - jump
	OR	DL,010H		; Set King castled flag
	JMP	MV21		; Jump
MV40:	MOV	BX,[MLPTRJ]	; Get move list pointer
	ADD	BX,8		; Increment to next move
	JMP	MV1		; Jump (2nd part of dbl move)

;***********************************************************
; UN-MOVE ROUTINE
;***********************************************************
; FUNCTION:   --  To reverse the process of the move routine,
;                 thereby restoring the board array to its
;                 previous position.
;
; CALLED BY:  --  VALMOV
;                 EVAL
;                 FNDMOV
;                 ASCEND
;
; CALLS:      --  None
;
; ARGUMENTS:  --  None
;***********************************************************
UNMOVE:	MOV	BX,[MLPTRJ]	; Load move list pointer
	INC	BX		; Increment past link bytes
	INC	BX
UM1:	MOV	AL,[BX]		; Get "from" position
	MOV	[M1],AL		; Save
	INC	BX		; Increment pointer
	MOV	AL,[BX]		; Get "to" position
	MOV	[M2],AL		; Save
	INC	BX		; Increment pointer
	MOV	DH,[BX]		; Get captured piece/flags
	MOV	SI,[M2]		; Load "to" pos board index
	MOV	DL,[SI+BOARD]	; Get piece moved
	TEST	DH,020H		; Was it a Pawn promotion ?
	JNZ	UM15		; Yes - jump
	MOV	AL,DL		; Get piece moved
	AND	AL,7		; Clear flag bits
	CMP	AL,QUEEN	; Was it a Queen ?
	JZ	UM20		; Yes - jump
	CMP	AL,KING		; Was it a King ?
	JZ	UM30		; Yes - jump
UM5:	TEST	DH,010H		; Is this 1st move for piece ?
	JNZ	UM16		; Yes - jump
UM6:	MOV	DI,[M1]		; Load "from" pos board index
	MOV	[DI+BOARD],DL	; Return to previous board pos
	MOV	AL,DH		; Get captured piece, if any
	AND	AL,8FH		; Clear flags
	MOV	[SI+BOARD],AL	; Return to board
	TEST	DH,040H		; Was it a double move ?
	JNZ	UM40		; Yes - jump
	MOV	AL,DH		; Get captured piece, if any
	AND	AL,7		; Clear flag bits
	CMP	AL,QUEEN	; Was it a Queen ?
	JNZ	RET		; No - return
	MOV	BX,POSQ		; Address of saved Queen pos
	TEST	DH,080H		; Is Queen white ?
	JZ	UM10		; Yes - jump
	INC	BX		; Increment to black Queen pos
UM10:	MOV	AL,[M2]		; Queen's previous position
	MOV	[BX],AL		; Save
	RET			; Return
UM15:	AND	DL,0FBH		; Restore Queen to Pawn
	JMP	UM5		; Jump
UM16:	AND	DL,0F7H		; Clear piece moved flag
	JMP	UM6		; Jump
UM20:	MOV	BX,POSQ		; Addr of saved Queen position
UM21:	TEST	DL,080H		; Is Queen white ?
	JZ	UM22		; Yes - jump
	INC	BX		; Increment to black Queen pos
UM22:	MOV	AL,[M1]		; Get previous position
	MOV	[BX],AL		; Save
	JMP	UM5		; Jump
UM30:	MOV	BX,POSK		; Address of saved King pos
	TEST	DH,040H		; Was it a castle ?
	JZ	UM21		; No - jump
	AND	DL,0EFH		; Clear castled flag
	JMP	UM21		; Jump
UM40:	MOV	BX,[MLPTRJ]	; Load move list pointer
	ADD	BX,8		; Increment to next move
	JMP	UM1		; Jump (2nd part of dbl move)

;***********************************************************
; SORT ROUTINE
;***********************************************************
; FUNCTION:   --  To sort the move list in order of
;                 increasing move value scores.
;
; CALLED BY:  --  FNDMOV
;
; CALLS:      --  EVAL
;
; ARGUMENTS:  --  None
;***********************************************************
SORTM:	MOV	CX,[MLPTRI]	; Move list begin pointer
	MOV	DX,0		; Initialize working pointers
SR5:	MOV	BH,CH
	MOV	BL,CL
	MOV	CL,[BX]		; Link to next move
	INC	BX
	MOV	CH,[BX]
	MOV	[BX],DH		; Store to link in list
	DEC	BX
	MOV	[BX],DL
	XOR	AL,AL		; End of list ?
	CMP	AL,CH
	JZ	RET		; Yes - return
SR10:	MOV	[MLPTRJ],CX	; Save list pointer
	CALL	EVAL		; Evaluate move
	MOV	BX,[MLPTRI]	; Begining of move list
	MOV	CX,[MLPTRJ]	; Restore list pointer
SR15:	MOV	DL,[BX]		; Next move for compare
	INC	BX
	MOV	DH,[BX]
	XOR	AL,AL		; At end of list ?
	CMP	AL,DH
	JZ	SR25		; Yes - jump
	MOV	SI,DX		; Transfer move pointer
	MOV	AL,[VALM]	; Get new move value
	CMP	AL,[SI+MLVAL]	; Less than list value ?
	JNC	SR30		; No - jump
SR25:	MOV	[BX],CH		; Link new move into list
	DEC	BX
	MOV	[BX],CL
	JMP	SR5		; Jump
SR30:	XCHG	DX,BX		; Swap pointers
	JMP	SR15		; Jump

;***********************************************************
; EVALUATION ROUTINE
;***********************************************************
; FUNCTION:   --  To evaluate a given move in the move list.
;                 It first makes the move on the board, then if
;                 the move is legal, it evaluates it, and then
;                 restores the board position.
;
; CALLED BY:  --  SORT
;
; CALLS:      --  MOVE
;                 INCHK
;                 PINFND
;                 POINTS
;                 UNMOVE
;
; ARGUMENTS:  --  None
;***********************************************************
EVAL:	CALL	MOVE		; Make move on the board array
	CALL	INCHK		; Determine if move is legal
	AND	AL,AL		; Legal move ?
	JZ	EV5		; Yes - jump
	XOR	AL,AL		; Score of zero
	MOV	[VALM],AL	; For illegal move
	JMP	UNMOVE		; Jump
EV5:	CALL	PINFND		; Compile pinned list
	CALL	POINTS		; Assign points to move
	JMP	UNMOVE		; Restore board array

;***********************************************************
; FIND MOVE ROUTINE
;***********************************************************
; FUNCTION:   --  To determine the computer's best move by
;                 performing a depth first tree search using
;                 the techniques of alpha-beta pruning.
;
; CALLED BY:  --  CPTRMV
;
; CALLS:      --  PINFND
;                 POINTS
;                 GENMOV
;                 SORTM
;                 ASCEND
;                 UNMOVE
;
; ARGUMENTS:  --  None
;***********************************************************
FNDMOV:	MOV	AL,[MOVENO]	; Current move number
	CMP	AL,1		; First move ?
	JNZ	L0003
	CALL	BOOK		; Yes - execute book opening
L0003:
	XOR	AL,AL		; Initialize ply number to zero
	MOV	[NPLY],AL
	MOV	BX,0		; Initialize best move to zero
	MOV	[BESTM],BX
	MOV	BX,MLIST	; Initialize ply list pointers
	MOV	[MLNXT],BX
	MOV	BX,PLYIX-2
	MOV	[MLPTRI],BX
	MOV	AL,[KOLOR]	; Initialize color
	MOV	[COLOR],AL
	MOV	BX,SCORE	; Initialize score index
	MOV	[SCRIX],BX
	MOV	AL,[PLYMAX]	; Get max ply number
	ADD	AL,2		; Add 2
	MOV	CH,AL		; Save as counter
	XOR	AL,AL		; Zero out score table
FM1:	MOV	[BX],AL
	INC	BX
	DEC	CH
	JNZ	FM1
	MOV	[BC0],AL	; Zero ply 0 board control
	MOV	[MV0],AL	; Zero ply 0 material
	CALL	PINFND		; Compile pin list
	CALL	POINTS		; Evaluate board at ply 0
	MOV	AL,[BRDC]	; Get board control points
	MOV	[BC0],AL	; Save
	MOV	AL,[MTRL]	; Get material count
	MOV	[MV0],AL	; Save
FM5:	MOV	BX,NPLY		; Address of ply counter
	INC	B,[BX]		; Increment ply count
	XOR	AL,AL		; Initialize mate flag
	MOV	[MATEF],AL
	CALL	GENMOV		; Generate list of moves
	MOV	AL,[NPLY]	; Current ply counter
	MOV	BX,PLYMAX	; Address of maximum ply number
	CMP	AL,[BX]		; At max ply ?
	JNC	L0004
	CALL	SORTM		; No - call sort
L0004:
	MOV	BX,[MLPTRI]	; Load ply index pointer
	MOV	[MLPTRJ],BX	; Save as last move pointer
FM15:	MOV	BX,[MLPTRJ]	; Load last move pointer
	MOV	DL,[BX]		; Get next move pointer
	INC	BX
	MOV	DH,[BX]
	MOV	AL,DH
	AND	AL,AL		; End of move list ?
	JNZ	FM15A
	JMP	FM25		; Yes - jump
FM15A:	MOV	[MLPTRJ],DX	; Save current move pointer
	MOV	BX,[MLPTRI]	; Save in ply pointer list
	MOV	[BX],DL
	INC	BX
	MOV	[BX],DH
	MOV	AL,[NPLY]	; Current ply counter
	MOV	BX,PLYMAX	; Maximum ply number ?
	CMP	AL,[BX]		; Compare
	JC	FM18		; Jump if not max
	CALL	MOVE		; Execute move on board array
	CALL	INCHK		; Check for legal move
	AND	AL,AL		; Is move legal
	JZ	FM16		; Yes - jump
	CALL	UNMOVE		; Restore board position
	JMP	FM15		; Jump
FM16:	MOV	AL,[NPLY]	; Get ply counter
	MOV	BX,PLYMAX	; Max ply number
	CMP	AL,[BX]		; Beyond max ply ?
	JZ	FM17
	JMP	FM35		; Yes - jump
FM17:	MOV	AL,[COLOR]	; Get current color
	XOR	AL,80H		; Get opposite color
	CALL	INCHK1		; Determine if King is in check
	AND	AL,AL		; In check ?
	JZ	FM35		; No - jump
	JMP	FM19		; Jump (One more ply for check)
FM18:	MOV	SI,[MLPTRJ]	; Load move pointer
	MOV	AL,[SI+MLVAL]	; Get move score
	AND	AL,AL		; Is it zero (illegal move) ?
	JZ	FM15		; Yes - jump
	CALL	MOVE		; Execute move on board array
FM19:	XOR	B,[COLOR],80H	; Toggle color, is new color white ?
	JS	FM20		; No - jump
	INC	B,[MOVENO]	; Increment move number
FM20:	MOV	BX,[SCRIX]	; Load score table pointer
	MOV	AL,[BX]		; Get score two plys above
	INC	BX		; Increment to current ply
	MOV	[SCRIX],BX	; Save it
	INC	BX
	MOV	[BX],AL		; Save score as initial value
	JMP	FM5		; Jump
FM25:	MOV	AL,[MATEF]	; Get mate flag
	AND	AL,AL		; Checkmate or stalemate ?
	JNZ	FM30		; No - jump
	MOV	AL,[CKFLG]	; Get check flag
	AND	AL,AL		; Was King in check ?
	MOV	AL,80H		; Pre-set stalemate score
	JZ	FM36		; No - jump (stalemate)
	MOV	AL,[MOVENO]	; Get move number
	MOV	[PMATE],AL	; Save
	MOV	AL,0FFH		; Pre-set checkmate score
	JMP	FM36		; Jump
FM30:	MOV	AL,[NPLY]	; Get ply counter
	CMP	AL,1		; At top of tree ?
	JZ	RET		; Yes - return
	CALL	ASCEND		; Ascend one ply in tree
	MOV	BX,[SCRIX]	; Load score table pointer
	INC	BX		; Increment to current ply
	INC	BX
	MOV	AL,[BX]		; Get score
	DEC	BX		; Restore pointer
	DEC	BX
	JMP	FM37		; Jump
JFM15:	JMP	FM15
FM35:	CALL	PINFND		; Compile pin list
	CALL	POINTS		; Evaluate move
	CALL	UNMOVE		; Restore board position
	MOV	AL,[VALM]	; Get value of move
FM36:	OR	B,[MATEF],001H	; Set mate flag
	MOV	BX,[SCRIX]	; Load score table pointer
FM37:	CMP	AL,[BX]		; Compare to score 2 ply above
	JC	FM40		; Jump if less
	JZ	FM40		; Jump if equal
	NEG	AL		; Negate score
	INC	BX		; Incr score table pointer
	CMP	AL,[BX]		; Compare to score 1 ply above
	JC	JFM15		; Jump if less than
	JZ	JFM15		; Jump if equal
	MOV	[BX],AL		; Save as new score 1 ply above
	MOV	AL,[NPLY]	; Get current ply counter
	CMP	AL,1		; At top of tree ?
	JNZ	JFM15		; No - jump
	MOV	BX,[MLPTRJ]	; Load current move pointer
	MOV	[BESTM],BX	; Save as best move pointer
	MOV	AL,[SCORE+1]	; Get best move score
	CMP	AL,0FFH		; Was it a checkmate ?
	JNZ	JFM15		; No - jump
	MOV	BX,PLYMAX	; Get maximum ply number
	SUB	B,[BX],2	; Subtract 2
	MOV	AL,[KOLOR]	; Get computer's color
	TEST	AL,080H		; Is it white ?
	JZ	RET		; Yes - return
	MOV	BX,PMATE	; Checkmate move number
	DEC	B,[BX]		; Decrement
	RET			; Return
FM40:	CALL	ASCEND		; Ascend one ply in tree
	JMP	FM15		; Jump

;***********************************************************
; ASCEND TREE ROUTINE
;***********************************************************
; FUNCTION:  --  To adjust all necessary parameters to
;                ascend one ply in the tree.
;
; CALLED BY: --  FNDMOV
;
; CALLS:     --  UNMOVE
;
; ARGUMENTS: --  None
;***********************************************************
ASCEND:	XOR	B,[COLOR],80H	; Toggle color, is new color white ?
	JNS	AC5		; Yes - jump
	DEC	B,[MOVENO]	; Decrement move number
AC5:	DEC	[SCRIX]		; Decrement score table index
	DEC	B,[NPLY]	; Decrement ply counter
	MOV	BX,[MLPTRI]	; Load ply list pointer
	DEC	BX 		; Load pointer to move list top
	DEC	BX
	MOV	DX,[BX]
	MOV	[MLNXT],DX	; Update move list avail ptr
	DEC	BX		; Get ptr to next move to undo
	DEC	BX
	MOV	DX,[BX]
	MOV	[MLPTRI],BX	; Save new ply list pointer
	MOV	[MLPTRJ],DX	; Save next move pointer
	JMP	UNMOVE		; Restore board to previous ply

;***********************************************************
; ONE MOVE BOOK OPENING
; **********************************************************
; FUNCTION:   --  To provide an opening book of a single
;                 move.
;
; CALLED BY:  --  FNDMOV
;
; CALLS:      --  None
;
; ARGUMENTS:  --  None
;***********************************************************
BOOK:	POP	AX
	MOV	B,[SCORE+1],0	; Zero out score table
	MOV	[BESTM],BMOVES-2 ; Init best move ptr to book
	MOV	BX,BESTM	; Initialize address of pointer
	MOV	AL,[KOLOR]	; Get computer's color
	AND	AL,AL		; Is it white ?
	JNZ	BM5		; No - jump
	MOV	AL,0		; Load random number (0)
	TEST	AL,001H		; Test random bit
	JZ	RET		; Return if zero (P-K4)
	ADD	B,[BX],3	; P-Q4
	RET			; Return
BM5:	ADD	B,[BX],6	; Increment to black moves
	MOV	SI,[MLPTRJ]	; Pointer to opponents 1st move
	MOV	AL,[SI+MLFRP]	; Get "from" position
	CMP	AL,22		; Is it a Queen Knight move ?
	JZ	BM9		; Yes - Jump
	CMP	AL,27		; Is it a King Knight move ?
	JZ	BM9		; Yes - jump
	CMP	AL,34		; Is it a Queen Pawn ?
	JZ	BM9		; Yes - jump
	JC	RET		; If Queen side Pawn opening -
				; return (P-K4)
	CMP	AL,35		; Is it a King Pawn ?
	JZ	RET		; Yes - return (P-K4)
BM9:	ADD	B,[BX],3	; (P-Q4)
	RET			; Return to CPTRMV

;***********************************************************
; COMPUTER MOVE ROUTINE
;***********************************************************
; FUNCTION:   --  To control the search for the computers move
;                 and the display of that move on the board
;                 and in the move list.
;
; CALLED BY:  --  DRIVER
;
; CALLS:      --  FNDMOV
;                 FCDMAT
;                 MOVE
;                 BITASN
;                 INCHK
;
; ARGUMENTS:  --  None
;***********************************************************
CPTRMV:	CALL	FNDMOV		; Select best move
	MOV	BX,[BESTM]	; Move list pointer variable
	MOV	[MLPTRJ],BX	; Pointer to move data
	MOV	AL,[SCORE+1]	; To check for mates
	CMP	AL,1		; Mate against computer ?
	JNZ	CP0C		; No - jump
	MOV	CL,1		; Computer mate flag
	CALL	FCDMAT		; Full checkmate ?
CP0C:	CALL	MOVE		; Produce move on board array
	MOV	SI,[MLPTRJ]	; Get pointer to move
	MOV	DH,[SI+MLTOP]	; "To" position of the move
	CALL	BITASN		; Convert to Ascii
	MOV	[MVEMSG+3],BX	; Put in move message
	MOV	DH,[SI+MLFRP]	; "From" position of the move
	CALL	BITASN		; Convert to Ascii
	MOV	[MVEMSG],BX	; Put in move message
	MOV	DX,MVEMSG	; Output move
	MOV	CL,PRINTBUF
	CALL	SYSTEM
CP1C:	MOV	AL,[COLOR]	; Should computer call check ?
	MOV	CH,AL
	XOR	AL,80H		; Toggle color
	MOV	[COLOR],AL
	CALL	INCHK		; Check for check
	AND	AL,AL		; Is enemy in check ?
	MOV	AL,CH		; Restore color
	MOV	[COLOR],AL
	JZ	CP24		; No - return
	MOV	DX,CKMSG	; Output "check"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
CP24:	MOV	AL,[SCORE+1]	; Check again for mates
	CMP	AL,0FFH		; Player mated ?
	JNZ	RET		; No - return
	MOV	CL,0		; Set player mate flag
	CALL	FCDMAT		; Full checkmate ?
	RET			; Return

;***********************************************************
; FORCED MATE HANDLING
;***********************************************************
; FUNCTION:   --  To examine situations where there exits
;                 a forced mate and determine whether or
;                 not the current move is checkmate. If it is,
;                 a losing player is offered another game,
;                 while a loss for the computer signals the
;                 King to tip over in resignation.
;
; CALLED BY:  --  CPTRMV
;
; CALLS:      --  None
;
; ARGUMENTS:  --  The only value passed in a register is the
;                 flag which tells FCDMAT whether the computer
;                 or the player is mated.
;***********************************************************
FCDMAT:	MOV	AL,[MOVENO]	; Current move number
	MOV	CH,AL		; Save
	MOV	AL,[PMATE]	; Move number where mate occurs
	SUB	AL,CH		; Number of moves till mate
	AND	AL,AL		; Checkmate ?
	JNZ	RET		; No - return
	RCR	AH
	TEST	CL,001H		; Check flag for who is mated
	RCL	AH
	JZ	FM04		; Jump if player
	MOV	DX,CKMSG	; Print "CHECK"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	MOV	DX,UWIN		; Output "YOU WIN"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	JP	FM08		; Jump
FM04:	MOV	DX,CKMSG	; Print "CHECK"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	MOV	DX,IWIN		; Output "I WIN"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
FM08:	POP	BX		; Remove return addresses
	POP	BX
	MOV	CL,INCHAR	; Input any char to play again
	CALL	SYSTEM
	JMP	DRIVER		; Jump (Rest of game init)

;***********************************************************
; BOARD INDEX TO ASCII SQUARE NAME
;***********************************************************
; FUNCTION:   --  To translate a hexadecimal index in the
;                 board array into an ascii description
;                 of the square in algebraic chess notation.
;
; CALLED BY:  --  CPTRMV
;
; CALLS:      --  DIVIDE
;
; ARGUMENTS:  --  Board index input in register DH and the
;                 Ascii square name is output in register BX.
;***********************************************************
BITASN:	SUB	AL,AL		; Get ready for division
	MOV	DL,10
	CALL	DIVIDE		; Divide
	DEC	DH		; Get rank on 1-8 basis
	ADD	AL,60H		; Convert file to Ascii (a-h)
	MOV	BL,AL		; Save
	MOV	AL,DH		; Rank
	ADD	AL,30H		; Convert rank to Ascii (1-8)
	MOV	BH,AL		; Save
	RET			; Return

;***********************************************************
; PLAYERS MOVE ANALYSIS
;***********************************************************
; FUNCTION:   --  To accept and validate the players move
;                 Also allows player to resign the game by
;                 entering R.
;
; CALLED BY:  --  DRIVER
;
; CALLS:      --  ASNTBI
;                 VALMOV
;
; ARGUMENTS:  --  None
;***********************************************************
PLYRMV:	MOV	DX,BUFFER	; Ask for input
	MOV	CL,INBUF
	CALL	SYSTEM
	MOV	DX,CRLF		; Output CRLF
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	MOV	BX,BUFFER+1	; Point to input length
	MOV	AL,[BX]		; Get input length
	OR	AL,AL		; Empty ?
	JZ	PLYRMV		; Jump if empty
	MOV	CH,AL		; Save length
	LAHF
	INC	BX		; Point to actual buffer
	SAHF
	MOV	AL,[BX]		; Get first char
	CMP	AL,"R"		; Restart game ?
	JNZ	PL05		; Jump if not restart
	JMP	DRIVER
PL05:	MOV	AL,CH		; Get input length
	CMP	AL,5		; Long enough ?
	JC	PL08		; Jump if less than 5 chars
	CALL	ASNTBI		; Convert "from" to a board index
	JC	PL08		; Jump if invalid
	MOV	[MVEMSG],AL	; Move list "from" position
	CALL	ATBINX		; Convert "to" to a board index
	JC	PL08		; Jump if invalid
	MOV	[MVEMSG+1],AL	; Move list "to" position
	CALL	VALMOV		; Determines if a legal move
	OR	AL,AL		; Legal ?
	JZ	RET		; Yes - return
PL08:	MOV	DX,INVAL	; Output "INVALID MOVE--TRY AGAIN"
	MOV	CL,PRINTBUF
	CALL	SYSTEM
	JP	PLYRMV		; Jump

;***********************************************************
; ASCII SQUARE NAME TO BOARD INDEX
;***********************************************************
; FUNCTION:   --  To convert an algebraic square name in
;                 Ascii to a hexadecimal board index.
;                 This routine also checks the input for
;                 validity.
;
; CALLED BY:  --  PLYRMV
;
; CALLS:      --  None
;
; ARGUMENTS:  --  Accepts the square name in pointer BX
;                 and outputs the board index in register AL.
;                 CF = 0 if ok. CF = 1 if invalid.
;***********************************************************
ATBINX:	INC	BX		; Increment pointer to skip a char
ASNTBI:	MOV	AL,[BX]		; Ascii file letter (a - h)
	INC	BX
	SUB	AL,41H		; File 1 - 8
	JC	RET		; Not file letter
	CMP	AL,8		; Check upper bound
	CMC
	JC	RET		; Invalid
	MOV	CH,AL
	MOV	AL,[BX]
	SUB	AL,31H		; Rank 1 - 8
	JC	RET
	CMP	AL,8		; Check upper bound
	CMC
	JC	RET
	ADD	AL,AL		; Multiply rank by 10
	MOV	CL,AL
	ADD	AL,AL
	ADD	AL,AL
	ADD	AL,CL
	ADD	AL,CH		; 10 * rank + file
	INC	BX		; Increment pointer
	ADD	AL,21
	RET			; Return

;***********************************************************
; VALIDATE MOVE SUBROUTINE
;***********************************************************
; FUNCTION:   --  To check a players move for validity.
;
; CALLED BY:  --  PLYRMV
;
; CALLS:      --  GENMOV
;                 MOVE
;                 INCHK
;                 UNMOVE
;
; ARGUMENTS:  --  Returns flag in register AL, 0 for valid
;                 and 1 for invalid move.
;***********************************************************
VALMOV:	MOV	BX,[MLPTRJ]	; Save last move pointer
	PUSH	BX		; Save register
	MOV	AL,[KOLOR]	; Computers color
	XOR	AL,80H		; Toggle color
	MOV	[COLOR],AL	; Store
	MOV	BX,PLYIX-2	; Load move list index
	MOV	[MLPTRI],BX
	MOV	BX,MLIST+1024	; Next available list pointer
	MOV	[MLNXT],BX
	CALL	GENMOV		; Generate opponents moves
	MOV	SI,MLIST+1024	; Index to start of moves
VA5:	MOV	AL,[MVEMSG]	; "From" position
	CMP	AL,[SI+MLFRP]	; Is it in list ?
	JNZ	VA6		; No - jump
	MOV	AL,[MVEMSG+1]	; "To" position
	CMP	AL,[SI+MLTOP]	; Is it in list ?
	JZ	VA7		; Yes - jump
VA6:	MOV	DL,[SI+MLPTR]	; Pointer to next list move
	MOV	DH,[SI+MLPTR+1]
	XOR	AL,AL		; At end of list ?
	CMP	AL,DH
	JZ	VA10		; Yes - jump
	PUSH	DX		; Move to SI register
	POP	SI
	JP	VA5		; Jump
VA7:	MOV	[MLPTRJ],SI	; Save opponents move pointer
	CALL	MOVE		; Make move on board array
	CALL	INCHK		; Was it a legal move ?
	AND	AL,AL
	JNZ	VA9		; No - jump
VA8:	POP	BX		; Restore saved register
	RET			; Return
VA9:	CALL	UNMOVE		; Un-do move on board array
VA10:	MOV	AL,1		; Set flag for invalid move
	POP	BX		; Restore saved register
	MOV	[MLPTRJ],BX	; Save move pointer
	RET			; Return

;***********************************************************
; POSITIVE INTEGER DIVISION
;***********************************************************
DIVIDE:	PUSH	CX
	MOV	CH,8
DD04:	SAL	DH
	RCL	AL
	SUB	AL,DL
	JS	DD05
	INC	DH
	JP	DD06
DD05:	ADD	AL,DL
DD06:	DEC	CH
	JNZ	DD04
	POP	CX
	RET

CLRMSG:	DB	13,10,"Choose your color (W/B): $"
PLYDEP:	DB	13,10,"Ply depth (1-6): $"
MVEMSG:	DB	"     ",13,10,"$"
CKMSG:	DB	"CHECK",13,10,"$"
UWIN:	DB	"You win",13,10,"$"
IWIN:	DB	"I win"
CRLF:	DB	13,10,"$"
INVAL:	DB	"INVALID MOVE--TRY AGAIN",13,10,"$"
BUFFER:	DB	7
	DS	6

IX:	DS	2
IY:	DS	2
BC:	DS	2
DE:	DS	2
HL:	DS	2
