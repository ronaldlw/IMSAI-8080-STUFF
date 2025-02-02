; SECOND LEVEL BOOTSTRAP

; THIS LOADER IS PULLED IN BY THE BASIC KEY-IN
; LOADER. WHEN STARTED UP BY THE KEY-IN LOADER,
; IT CHECKSUMS ITSELF, TO MAKE SURE THAT IT
; HAS BEEN LOADED CORRECTLY, THEN PULLS IN AND
; RELOCATES THE MAIN PAPERTAPE LOAOER.

; NOTE THAT THIS LOADER IS A SLIGHTLY MODIFIED
; VERSION OF THE MAIN PAPER TAPE LOADER.
;  DATAPT EQU  02h   ; SIO 1 Channel B data port
;  CNTRPT EQU  03h   ; SIO 1 Channel B control port
;
        ORG     100H
DATAPT  EQU     034     ; SIO 2 channel A data port
CNTRPT  EQU     035     ; SIO 2 channel A control port

BOOT2:  MVI     A,13H   ;GET STOP CHAR
        OUT     DATAPT  ;STOP THE READER
        MVI     B,CHKSM-BOOT2  ;GET SIZE OF LDR
        LXI     H,BOOT2 ;GET ADDRESS OF LDR
        XRA     A       ;CLEAR A AND CARRY
            ;
            ; PERFORM AN END-AROUND CHECKSUM, TO MAKE SURE
            ; WE WERE LOADED CORRECTLY
            ;
CHECK:  ADC     M       ;ADD IN A BYTE WITH CARRY
        INX     H       ;BUMP POINTER
        DCR     B       ;DECREMENT COUNT
        JNZ     CHECK   ;KEEP GOING
        ACI     0       ;ADD IN LAST CARRY
        CMP     M       ;COMPARE WITH CHECKSUM
XXX:    JNZ     XXX     ;HANG UP IF NO GOOD.
            ;
            ; WE DO THE FOLLOWING NONSENSE BECAUSE THE
            ; BASIC KEY-IN BOOTSTRAP WILL NOT LOAD
            ; AN OFFH CHARACTER
            ;
        LXI     H,FF1+1 ;GET ADDRESS OF 'IN 0FEH' INST
        INR     M       ;MAKE IT 'IN 0FFH'
        LXI     H,FF2+1 ;DO IT AGAIN
        INR     M
        LXI     H,FF3+1 ;AND AGAIN
        INR     M
            ;
            ; NOW WE'RE READY TO LOAD AND RELOCATE THE LOADER
            ;
        JMP STR         ;1ST TIME, SKIP RE-INIT STUFF.
START:  MVI     A,0AAH  ;GET DUMMY MODE BYTE
        OUT     CNTRPT
        MVI     A,40H   ;GET RESET COMMAND
        OUT     CNTRPT  ;ISSUE IT
        MVI     A,0FAH
        OUT     CNTRPT  ;ISSUE MODE BYTE TO SIO
        MVI     A,17H
        OUT     CNTRPT  ;ISSUE COMMAND BYTE
SL:     IN      CNTRPT  ;GET STATUS
        ANI     02      ;CHECK FOR CHAR READY
        JZ      SL      ;KEEP WAITING
        IN      DATAPT  ;READ CHAR AND IGNORE
STR:    IN      CNTRPT  ;GET STATUS
        ANI     1       ;MAKE SURE WE HAVE XMTR RDY
        JZ      STR
        MVI     A,11H   ;GET 'XON' CHAR
        OUT     DATAPT  ;START READER
LOOP1:  MVI     E,0     ;CLEAR FLAG
        MVI     C,0     ;CLEAR CHECKSUM
LOOP2:  IN      CNTRPT  ;GET SIO STATUS
        ANI     2       ;CHECK FOR CHARACTER
        JZ      LOOP2   ;KEEP WAITING
        MOV     A,E     ;GET FLAG
        ORA     A       ;IS IT ZERO?
        JNZ     X1      ;NO, GO PROCESS A HEX CHAR
        IN      DATAPT  ;YES, WE'RE LOOKING FOR A COLON
        ANI     127     ;STROP OFF PARITY BIT
        CPI     ':'     ;IS IT A COLON?
        JNZ     LOOP2   ;NO, KEEP WAITING
        MVI     E,81H   ;YES, SET FLAG FOR COUNT BYTE
        JMP     LOOP2   ;AND GET ANOTHER CHAR.
            ;
            ; WE'RE PUTTING TOGETHER A BYTE. FLAG BIT 7 = l => HIGH
            ; DIGIT OF BYTE, BIT 7=0 => LOW DIGIT
            ;
X1:     JP      Y1      ;JUMP IF LOW DIGIT
        ANI     127     ;ELSE STRIP OFF HIGH BIT
        MOV     E,A     ;PUT FLAG BACK IN E-REG
        IN      DATAPT  ;GET THE CHAR
        ANI     127     ;STROP OFF THE PARITY BIT
        CPI     '9'+1   ;IS IT .LE. '9'
        JM      X2      ;SKIP IF YES
        ADI     9       ;IF NOT, ADJUST IT
X2:     ANI     0FH     ;GET HEX DIGIT
        ADD     A       ;SHIFT LEFT ONE BIT
        ADD     A       ;    TWO BITS
        ADD     A       ;    THREE BITS
        ADD     A       ;AND FOUR BITS
        MOV     D,A     ;SAVE NIBBLE IN D REG
        JMP     LOOP2
            ;
            ; PROCESS LOW DIGIT OF BYTE, THEN DECIDE WHAT TO DO WITH
            ;
Y1:     IN      DATAPT  ;GET THE CHAR
        ANI     127     ;GET RID OF PARITY BIT
        CPI     '9'+1   ;HEX IS SUCH A PAIN.
        JM      Y2
        ADI     9
Y2:     ANI     0FH
        ORA     D       ;MAKE THE BYTE
FF2:    OUT     0FEH    ;PUT IT IN LIGHTS
        MOV     D,A     ;SAVE IT IN D REG
        ADD     C       ;ADD IT INTO CHECKSUM
        MOV     C,A     ;SAVE RUNNING CHECKSUM
        MOV     A,D     ;GET BYTE BACK
        CPI     0FDH    ;IS IT FELOCATABLE BYTE?
        JNZ     Y3      ;BRANCH IF NOT
FF1:    IN      0FEH    ;ELSE SUBSTITUE SWITCHS
Y3:     MOV     D,A     ;PUT BYTE BACK IN D
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
        ORA     A       ;  CHECKSUM. IS IT ZERO?
        JZ      LOOP1   ;YES, GO GET NEXT RECORD
        LXI     H,START ;ELSE, GET RESTART ADDR
STOP:   MVI     A,13H   ;GET 'XOFF' CHAR
        OUT     DATAPT  ;TURN OFF READER
STPL:   IN      CNTRPT  ;WAIT TILL XMTR BUFFER EMPTY
        ANI     4
        JZ      STPL
        PCHL            ;GO AWAY
            ;
            ; PUT A DATA BYTE INTO CORE
            ;
PUT:    MOV     M,D     ;STORE THE DATA
        INX     H       ;INCREMENT THE H REG
        MVI     E,85H   ;RESET FLAG FOR NEXT DATA BYTE
        DCR     B       ;DECR COUNT
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
        JNZ     C1      ;IF NOT EOF, CONTINUE
FF3:    IN      0FEH    ;GET HIGH BYTE OF LOADER
        MOV     H,A     ; ADDRESS INTO A
        MVI     L,0     ;AND LOW BYTE
        JMP     STOP    ;STOP TAPE, THEN GOTO LOADER.
C1:     MVI     E,82H   ;SET FLAG FOR ADDRESS BYTE
        JMP     LOOP2
CHKSM:  DB      0D0H    ;SELF-CHECKSUM FOR THIS LOADER
        END
