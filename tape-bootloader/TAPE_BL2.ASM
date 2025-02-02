; ***  IMSAI PAPER TAPE LOADER  ***
;          REV 0  3/3/76
; THIS LOADER IS DESIGNED TO LOAD PAPER TAPES IN
; THE STANDARD OBJECT FORMAT (SEE THE SOFTWARE
; SECTION OF THE 8080 USER MANUAL) FROM AN ASR 33
; TELETYPE·. IT USES NO STACK AND NO LOCAL RAM, SO
; THAT IT MAY BE RUN FROM PROM WITHOUT REQUIRING
; A RAM CARD OF ITS OWN.
;
; USING THE LOADER:
;       IF THIS LOADER IS BROUGHT IN WITH THE
; BOOTSTRAP SEQUENCE (DOCUMENTED ELSEWHERE),
; IT WILL START ITSELF UP. OTHERWISE, MANUALLY
; START IT AT ITS BEGINNING. IT WILL RESPOND
; BY TYPING * ON THE TELETYPE. MOUNT THE TAPE
; TO BE LOADED IN THE READER, AND STRIKE ANY KEY.
; THE LOADER WILL START THE READER AUTOMATICALLY.
; THE LOADER WILL STOP THE TAPE AND TYPE * IN
; EITHER CF TWO CASES:
; (1) IT HAS SEEN AN END OF FILE RECORD. IN
;     THIS CASE, ZERO WILL BE DISPLAYED IN
;     THE PROGRAMMED OUTPUT LIGHTS.
; (2) IT ENCOUNTERED A BAD RECORD. IN THIS CASE
;     AN NON-ZERO QUANTITY WILL BE DISPLAYED
;     IN THE PROGRAMMED OUTPUT LIGHTS.
; IN EITHER CASE, LOADING MAY BE CONTINUED BY STRIKING
; A KEY.
;
;

        ORG     0FD00H
START:  LXI     D,1     ;WAIT ABOUT A SECOND SO A
        LXI     H,0     ;  PREVIOUS 'XOFF' CHARACTER
SL0:    DAD     D       ;  HAS TIME TO STOP THE READER
        JNC     SL0
            ;
            ; INITALIZE SIO BOARD.
            ;
        MVI     A,0AAH  ;GET DUMMY MODE BYTE
        OUT     3
        MVI     A,40H   ;GET RESET COMMAND
        OUT     3       ;ISSUE IT
        MVI     A,0FAH
        OUT     3       ;ISSUE MODE BYTE TO SIO
        MVI     A,17H
        OUT     3       ;ISSUE COMMAND BYTE
        MVI     A,'*'   ;GET AND ASTERISK
        OUT     02      ;PRINT IT
        IN      02      ;THROW AWAY ANY CHAR IN BUFFER
SL2:    IN      03      ;GET STATUS
        JZ      SL2     ;KEEP WAITING
        IN      02      ;READ CHAR AND IGNORE
        MVI     A,11H   ;GET 'XON' CHAR
        OUT     02      ;START READER
LOOP1:  MVI     E,0     ;CLEAR FLAG
        MVI     C,0     ;CLEAR CHECKSUM
LOOP2:  IN      3       ;GET SIO STATUS
        ANI     2       ;CHECK FOR CHARACTER
        JZ      LOOP2   ;KEEP WAITING
        MOV     A,E     ;GET FLAG
        ORA     A       ;IS IT ZERO?
        JNZ     X1      ;NO, GO PROCESS A HEX CHAR
        IN      2       ;YES, WE'RE LOOKING FOR A COLON
        ANI     127     ;STRIP OFF PARITY BIT
        CPI     ':'     ;IS IT A COLON?
        JNZ     LOOP2   ;NO, KEEP WAITING
        MVI     E,81H   ;YES, SET FLAG FOR COUNT BYTE
        JMP     LOOP2   ;AND GET ANOTHER CHAR
            ;
            ; WE'RE PUTTING TOGETHER A BYTE. FLAG BIT 7 = l => HIGH
            ; DIGIT OF BYTE, BIT 7:0 :> LOW DIGIT
            ;
X1:     JP      Y1      ;JUMP IF LOW DIGIT
        ANI     127     ;ELSE STRIP OFF HIGH BIT
        MOV     E,A     ;PUT FLAG BACK IN E-REG
        IN      2       ;GET THE CHAR
        ANI     127     ;STRIP OFF THE PARITY BIT
        CPI     '9'+1   ;IS IT .LE. '9'
        JM      X2      ;SKIP IF YES
        ADI     9       ;IF NOT, ADJUST IT
X2:     ANI     0FH     ;GET HEX DIGIT
        ADD     A       ;SHIFT IT LEFT ONE BIT
        ADD     A       ;  TWO BITS
        ADD     A       ;  THREE BITS
        ADD     A       ;AND FOUR BITS.
        MOV     D,A     ;SAVE THE NIBBLE IN D REG
        JMP     LOOP2
            ;
            ; PROCESS LOW DIGIT OF BYTE, THEN DECIDE WHAT TO DO WITH IT
            ;
Y1:     IN      2       ;GET THE CHAR
        ANI     127     ;GET RID OF THE PARITY BIT
        CPI     '9'+1   ;HEX IS SUCH A PAIN.
        JM      Y2
        ADI     9
Y2:     ANI     0FH
        ORA     D       ;MAKE THE BYTE
        OUT     0FFH    ;PUT IT IN LIGHTS
        MOV     D,1     ;SAVE IT IN D REG
        ADD     C       ;ADD IT INTO CHECKSUM
        MOV     C,A     ;SAVE RUNNING CHECKSUM
        MOV     A,E     ;GET FLAG IN A
        DCR     A       ;THEN DISPATCH ON IT
        JZ      COUNT
        DCR     A
        JZ      HADD
        DCR     A
        JZ      LADD
        DCR     A
        JZ      TYPE
        DCR     A
        JZ      PUT
        MOV     A,C     ;MUST BE TIME TO CHECK THE
        ORA     A       ; CHECKSUM. IS IT ZERO?
        JZ      LOOP1   ;YES, GO GET NEXT RECORD
STOP:   CMA             ;DISPLAY REASON FOR STOPPING
        OUT     0FFH
        MVI     A,13H   ;ELSE, GET 'XOFF' CHAR
        OUT     2       ;TURN OFF READER
STPL:   IN      3       ;WAIT TILL XMTR BUFFER EMPTY
        ANI     4
        JZ      STPL
        JMP     START
            ;
            ;PUT A DATA BYTE INTO CORE
            ;
PUT:    MOV     M,D     ;STORE THE DATA
        INX     H       ;INCREMENT THE H REG
        MVI     E,85H   ;REESET FLAG FOR NEXT DATA BYTE
        DCR     B       ;DECREMENT COUNT
        JNZ     LOOP2   ;GO BACK FOR MORE DATA
        INR     E       ;OUT OF DATA, SET FLAG FOR
        JMP     LOOP2   ;  CHECKSUM
            ;
            ; IGNORE A TYPE BYTE
            ;
TYPE:   MVI     E,85H   ;SET FLAG FOR DATA
        JMP     LOOP2   ;GO GET DATA
            ;
            ; GET LOW BYTE OF ADDRESS
            ;
LADD:   MOV     L,D     ;GET BYTE INTO L-REG
        MVI     E,84H   ;SET FLAG FOR TYPE BYTE
        JMP     LOOP2
            ;
            ; GET HIGH BYTE OF ADDRESS
            ;
HADD:   MOV     H,D     ;GET BYTE INTO H
        MVI     E,83H   ;SET FLAG FOR LOW ADDRESS BYTE
        JMP     LOOP2
            ;
            ; GET COUNT BYTE
            ;
COUNT:  MOV     B,D     ;PUT COUNT INTO B
        MOV     A,D     ;CHECK FOR EOF
        ORA     A
        JZ      STOP    ;IF EOF, GO STOP READER
        MVI     E,82H   ;ELSE SET FLAG FOR ADDRESS BYTE
        JMP     LOOP2
        END
