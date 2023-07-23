;GB-SCAN Virus Scanner
;(C) 1995 American Eagle Publications, Inc., All Rights Reserved.

.model tiny
.code

;Equates
DBUF_SIZE       EQU     16384           ;size of data buffer for scanning

;These are the flags used to identify the scan strings and what they are for.
BOOT_FLAG       EQU     00000001B       ;Flags a boot sector on the hard disk
MBR_FLAG        EQU     00000010B       ;Flags a master boot sector on hd, boot sec on floppy
EXE_FLAG        EQU     00000100B       ;Flags an EXE file
COM_FLAG        EQU     00001000B       ;Flags a COM file
RAM_FLAG        EQU     00010000B       ;Search RAM
END_OF_LIST     EQU     00100000B       ;Flags end of scan string list

        ORG     100H

GBSCAN:
        mov     ax,cs
        mov     ds,ax

        mov     ah,19H                  ;get current drive number
        int     21H
        mov     BYTE PTR [CURR_DR],al   ;and save it here

        mov     ah,47H                  ;get current directory
        mov     dl,0
        mov     si,OFFSET CURR_DIR
        int     21H

        mov     bx,5CH
        mov     al,es:[bx]              ;get drive letter from FCB
        or      al,al                   ;was one specified?
        jnz     GBS1                    ;yes, go adjust as necessary
        mov     ah,19H                  ;no, get current drive number
        int     21H
        inc     al
GBS1:   dec     al                      ;adjust so A=0, B=1, etc.
        mov     BYTE PTR [DISK_DR],al   ;save it here
        mov     dl,al
        mov     ah,0EH                  ;and make this drive current
        int     21H

        push    cs
        pop     es
        mov     di,OFFSET PATH          ;set up path with drive letter
        mov     al,[DISK_DR]
        add     al,'A'
        mov     ah,':'
        stosw
        mov     ax,'\'
        stosw

        mov     dx,OFFSET HELLO         ;say "hello"
        mov     ah,9
        int     21H

        call    SCAN_RAM                ;is a virus in RAM?
        jc      GBS4                    ;yes, exit now!
        cmp     BYTE PTR [DISK_DR],2    ;is it drive C:?
        jne     GBS2                    ;no, don't mess with master boot record
        call    SCAN_MASTER_BOOT
GBS2:   cmp     BYTE PTR [DISK_DR],2    ;is it drive D: or higher?
        jg      GBS3                    ;yes, don't mess with boot sector
        call    SCAN_BOOT
GBS3:   mov     dx,OFFSET ROOT          ;go to root directory
        mov     ah,3BH
        int     21H
        call    SCAN_ALL_FILES

GBS4:   mov     dl,[CURR_DR]            ;restore current drive
        mov     ah,0EH
        int     21H

        mov     dx,OFFSET CURR_DIR      ;restore current directory
        mov     ah,3BH
        int     21H

        mov     ax,4C00H                ;exit to DOS
        int     21H


;This routine scans the Master Boot Sector.
;The drive to scan is supplied in dl.
SCAN_MASTER_BOOT:
        mov     WORD PTR [FILE_NAME],OFFSET MBR_NAME
        push    ds                      ;first read the boot sector
        pop     es
        mov     bx,OFFSET DATA_BUF      ;into the DATA_BUF
        mov     ax,201H
        mov     cx,1
        mov     dh,0
        mov     dl,[DISK_DR]
        cmp     dl,2
        jc      SMB1
        add     dl,80H-2
SMB1:   int     13H
        mov     ax,201H                 ;duplicate read
        int     13H                     ;in case disk change
        jc      SMBR                    ;exit if error

        mov     cx,512                  ;size of data to scan
        mov     ah,MBR_FLAG and 255     ;scan for boot sector viruses
        call    SCAN_DATA               ;go scan the data

SMBR:   ret


;This routine scans the boot sector for both floppy disks and hard disks.
;For hard disks, the master boot sector must be in the data buffer when
;this is called, so it can find the boot sector.
SCAN_BOOT:
        mov     WORD PTR [FILE_NAME],OFFSET BOOT_NAME
        mov     cx,1                    ;assume floppy parameters
        mov     dh,0
        mov     dl,[DISK_DR]
        cmp     BYTE PTR [DISK_DR],2
        jc      SB2                     ;go handle floppies if so

        mov     si,OFFSET DATA_BUF + 1BEH
SBL:    cmp     BYTE PTR [si],80H       ;check active flag
        je      SB1                     ;active, go get it
        add     si,10H                  ;else try next partition
        cmp     si,1FEH                 ;at the end of table?
        jne     SBL                     ;no, do another
        ret                             ;yes, no active partition, just exit

SB1:    mov     dx,[si]                 ;set up dx and cx for read
        mov     cx,[si+2]
SB2:    mov     bx,OFFSET DATA_BUF
        push    ds
        pop     es
        mov     ax,201H
        int     13H                     ;read boot sector

        mov     cx,512
        mov     ah,BOOT_FLAG
        call    SCAN_DATA               ;and scan it
        ret

;This routine systematically scans all RAM below 1 Meg for resident viruses.
;If a virus is found, it returns with c set. Otherwise c is reset.
SCAN_RAM:
        mov     WORD PTR [FILE_NAME],OFFSET RAM_NAME
        xor     ax,ax
        mov     es,ax
        mov     bx,ax                   ;set es:bx=0
SRL:    mov     ah,RAM_FLAG             ;prep for scan
        mov     cx,8010H                ;scan this much in a chunk
        call    SCAN_DATA               ;scan ram
        pushf
        mov     ax,es                   ;update es for next chunk
        add     ax,800H
        mov     es,ax
        popf
        jc      SREX                    ;exit if a virus was found
        or      ax,ax                   ;are we done?
        jnz     SRL                     ;nope, get another chunk
        clc                             ;no viruses, return nc
SREX:   ret

;This routine scans all EXEs and COMs on the current disk looking for viruses.
;This routine is fully recursive.
SCAN_ALL_FILES:
        push    bp                      ;build stack frame
        mov     bp,sp
        sub     bp,43                   ;space for file search record
        mov     sp,bp

        mov     dx,OFFSET SEARCH_REC    ;set up DTA
        mov     ah,1AH
        int     21H

        call    SCAN_COMS               ;scan COM files in current directory
        call    SCAN_EXES               ;scan EXE files in current directory

        mov     dx,bp                   ;move DTA for directory search
        mov     ah,1AH                  ;this part must be recursive
        int     21H

        mov     dx,OFFSET ANY_FILE
        mov     ah,4EH                  ;prepare for search first
        mov     cx,10H                  ;dir file attribute
        int     21H                     ;do it

SAFLP:  or      al,al                   ;done yet?
        jnz     SAFEX                   ;yes, quit
        cmp     BYTE PTR [bp+30],'.'
        je      SAF1                    ;don't mess with fake subdirectories
        test    BYTE PTR [bp+21],10H
        jz      SAF1                    ;don't mess with non-directories
        lea     dx,[bp+30]
        mov     ah,3BH                  ;go into subdirectory
        int     21H

        call    UPDATE_PATH             ;update the PATH viariable
        push    ax                      ;save end of original PATH

        call    SCAN_ALL_FILES          ;search all files in the subdirectory

        pop     bx
        mov     BYTE PTR [bx],0         ;truncate PATH variable to original

        mov     dx,bp                   ;restore DTA, continue dir search
        mov     ah,1AH
        int     21H

        mov     dx,OFFSET UP_ONE        ;go back to this directory
        mov     ah,3BH
        int     21H
SAF1:   mov     ah,4FH                  ;search next
        int     21H
        jmp     SAFLP                   ;and continue

SAFEX:  add     bp,43
        mov     sp,bp
        pop     bp                      ;restore stack frame and exit
        ret


;This routine scans all EXE files in the current directory looking for viruses.
SCAN_EXES:
        mov     BYTE PTR [FFLAGS],EXE_FLAG and 255
        mov     WORD PTR [FILE_NAME],OFFSET SEARCH_REC + 30 ;where file name ends up

        mov     dx,OFFSET EXE_FILE
        jmp     SCAN_FILES

;This routine scans all COM files in the current directory looking for viruses.
SCAN_COMS:
        mov     BYTE PTR [FFLAGS],COM_FLAG
        mov     WORD PTR [FILE_NAME],OFFSET SEARCH_REC + 30 ;where file name ends up

        mov     dx,OFFSET COM_FILE
SCAN_FILES:
        mov     ah,4EH                  ;prepare for search first
        mov     cx,3FH                  ;any file attribute
        int     21H                     ;do it

SCLP:   or      al,al                   ;an error?
        jnz     SCDONE                  ;if so, we're done
        call    SCAN_FILE               ;scan the file
        mov     ah,4FH                  ;search for next file
        int     21H
        jmp     SCLP                    ;and go check it

SCDONE: ret                             ;all done, exit

;This routine scans a single file for viruses. The @ of the file name is assumed
;to be at ds:[FILE_NAME]. The flags to use in the scan are at ds:[FFLAGS]
SCAN_FILE:
        mov     dx,WORD PTR [FILE_NAME]
        mov     ax,3D00H                ;open file
        int     21H
        jc      SFCLOSE                 ;exit if we can't open it
        mov     bx,ax
SF1:
        mov     ah,3FH                  ;read file
        mov     cx,DBUF_SIZE
        mov     dx,OFFSET DATA_BUF
        int     21H
        cmp     ax,16                   ;did we actually read anything?
        jle     SFCLOSE                 ;nope, done, go close file

        mov     cx,ax                   ;size of data read to cx
        push    bx                      ;save file handle
        mov     bx,OFFSET DATA_BUF
        push    ds
        pop     es
        mov     ah,[FFLAGS]
        call    SCAN_DATA
        pop     bx                      ;restore file handle
        jc      SFCL2                   ;if a virus found, exit with c set

        mov     ax,4201H                ;move file pointer relative to current
        mov     cx,-1                   ;back 16 bytes
        mov     dx,-16                  ;so we don't miss a virus at the
        int     21H                     ;buffer boundary
        jmp     SF1

SFCLOSE:clc                             ;exit when no virus found, c reset
SFCL2:  pushf                           ;save flags temporarily
        mov     ah,3EH                  ;close file
        int     21H
        popf

        ret

;This routine scans data at es:bx for viruses. The amount of data to
;scan is put in cx, and the flag mask to examine is put in ah. SCAN_DATA
;will return with c set if a scan string was found, and nc if not.
SCAN_DATA:
        mov     WORD PTR [DSIZE],cx
        mov     si,OFFSET SCAN_STRINGS  ;si is an index into the scan strings
SD1:    lodsb                           ;get flag byte
        push    ax
        and     al,END_OF_LIST          ;end of list?
        pop     ax
        jnz     SDR                     ;yes, exit now
        and     al,ah                   ;no, so is it a string of proper type?
        jz      SDNEXT                  ;no, go do next string

        mov     dx,bx
        add     dx,[DSIZE]              ;dx = end of search buffer
        mov     di,bx                   ;di = start of search buffer
SD2:    mov     al,[si]                 ;get 1st byte of string
        xor     al,0AAH
        cmp     di,dx                   ;end of buffer yet?
        je      SDNEXT                  ;yes, go do next string
        cmp     al,es:[di]              ;compare with byte of buffer
        je      SD3                     ;equal, go check rest of string
        inc     di                      ;else check next byte in buffer
        jmp     SD2

SD3:    push    si                      ;check for entire 16 byte string
        push    di                      ;at es:di
        mov     cx,16
SD4:    lodsb                           ;ok, do it
        xor     al,0AAH                 ;decrypt
        inc     di
        cmp     al,es:[di-1]
        loopz   SD4

        pop     di
        pop     si
        pushf
        inc     di
        popf
        jne     SD2                     ;not equal, go try next byte
        mov     di,si                   ;else calculate the index for this
        sub     di,OFFSET SCAN_STRINGS+1;virus to display its name on screen
        mov     ax,di
        mov     di,17
        xor     dx,dx
        div     di
        mov     di,ax
        call    DISP_VIR_NAME           ;go display its name
        stc                             ;set carry
        ret                             ;and exit

SDNEXT: add     si,16                   ;go to next scan string
        jmp     SD1

SDR:    clc                             ;clear carry, no virus found
        ret                             ;and exit

;This routine updates the variable PATH to reflect a new directory. It also
;returns a pointer to the end of the old path in ax. It is used only in
;conjunction with SCAN_ALL_FILES.
UPDATE_PATH:
        lea     di,[bp+30]              ;update PATH variable
        mov     si,OFFSET PATH
SAF01:  lodsb                           ;find end of existing PATH
        or      al,al
        jnz     SAF01
        dec     si
        mov     dx,si                   ;save end here
        push    cs
        pop     es
        xchg    si,di
SAF02:  lodsb                           ;move new directory to PATH
        stosb
        or      al,al
        jnz     SAF02
        dec     di
        mov     ax,'\'                  ;terminate path with backslash
        stosw
        mov     ax,dx
        ret

;This routine displays the virus name indexed by di. If di=0 then this
;displays the first ASCIIZ string at NAME_STRINGS, if di=1 then it displays
;the second, etc.
DISP_VIR_NAME:
        mov     si,OFFSET PATH
FV00:   lodsb
        or      al,al
        jz      FV01
        mov     ah,0EH
        int     10H
        jmp     FV00

FV01:   mov     si,[FILE_NAME]
FV02:   lodsb
        or      al,al
        jz      FV05
        mov     ah,0EH
        int     10H
        jmp     FV02

FV05:   mov     si,OFFSET NAME_STRINGS
FV1:    or      di,di
        jz      DISP_NAME
        push    di
FV2:    lodsb
        cmp     al,'$'
        jnz     FV2
        pop     di
        dec     di
        jmp     FV1

DISP_NAME:
        push    si
        mov     dx,OFFSET INFECTED
        mov     ah,9
        int     21H
        pop     dx
        mov     ah,9
        int     21H
        mov     dx,OFFSET VIRUS_ST
        mov     ah,9
        int     21H
        ret

HELLO           DB      'GB-SCAN Virus Scanner Ver. 1.00 (C) 1995 American Eagle Publications Inc.',0DH,0AH,24H
INFECTED        DB      ' is infected by the $'
VIRUS_ST        DB      ' virus.',0DH,0AH,24H
MBR_NAME        DB      'The Master Boot Record',0
BOOT_NAME       DB      'The Boot Sector',0
RAM_NAME        DB      7,7,7,7,7,'ACTIVE MEMORY',0
EXE_FILE        DB      '*.EXE',0
COM_FILE        DB      '*.COM',0
ANY_FILE        DB      '*.*',0
ROOT            DB      '\',0
UP_ONE          DB      '..',0

SCAN_STRINGS    DB      (COM_FLAG or EXE_FLAG) and 255    ;MINI-44 virus
                DB      1EH,0E4H,10H,8CH,0ABH,67H,8BH,0D8H,0B6H,12H,0ABH,97H,10H,34H,0AAH,67H
                DB      BOOT_FLAG               ;Kilroy-B virus (live)
                DB      12H,0ABH,0A8H,11H,0AAH,0AFH,13H,0ABH,0AAH,10H,0ABH,0AAH,67H,0B9H,12H,0ABH
                DB      COM_FLAG                ;Kilroy-B virus (dropper)
                DB      12H,0ABH,0A8H,11H,0AAH,0AFH,13H,0ABH,0AAH,10H,0ABH,0AAH,67H,0B9H,12H,0ABH
                DB      (EXE_FLAG or RAM_FLAG) and 255    ;The Yellow Worm
                DB      0FAH,0A4H,0B5H,26H,0ACH,86H,0AAH,12H,0AAH,0BCH,67H,85H,8EH,0D5H,96H,0AAH
                DB      END_OF_LIST             ;end of scan string list

NAME_STRINGS    DB      'MINI-44$'
                DB      'Kilroy-B$'
                DB      'Kilroy-B dropper$'
                DB      'Yellow Worm$'

PATH            DB      80 dup (?)
CURR_DIR        DB      64 dup (?)
DSIZE           DW      ?
SEARCH_REC      DB      43 dup (?)
CURR_DR         DB      ?                               ;current disk drive
DISK_DR         DB      ?                               ;drive to scan
FFLAGS          DB      ?                               ;flags to use in scan
FILE_NAME       DW      ?                               ;address of file name in memory
DATA_BUF        DB      DBUF_SIZE dup (?)

        END     GBSCAN
