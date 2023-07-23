;A Master Boot Record
;(C) 1995 American Eagle Publications, Inc., All Rights Reserved.

.model tiny
.code

;The loader is executed when this program is run from the DOS prompt. It
;reads the partition table and installs the Master Boot Sector to the C: drive.

        ORG     100H

LOADER:
        mov     ax,201H         ;read existing master boot sector
        mov     bx,OFFSET BUF
        mov     cx,1
        mov     dx,80H
        int     13H

        mov     si,OFFSET BUF + 1BEH
        mov     di,OFFSET PTABLE
        mov     cx,40H
        rep     movsb           ;move partition table to new sector

        mov     ax,301H         ;and write it to disk
        mov     bx,OFFSET BOOT
        mov     cx,1
        int     13H

        mov     ax,4C00H        ;then exit to DOS
        int     21H

BUF:                            ;area for reading disk



;The Master Boot Sector starts here.

        ORG     7C00H

BOOT:
        cli
        xor     ax,ax           ;set up segments and stack
        mov     ds,ax
        mov     es,ax
        mov     ss,ax
        mov     sp,OFFSET BOOT
        sti

        mov     si,OFFSET PTABLE;find active partition
        mov     cx,4
SRCH:   lodsb
        cmp     al,80H
        je      ACT_FOUND
        add     si,0FH
        loop    SRCH
        mov     si,OFFSET NO_OP ;no operating system found
ERROR:  call    DISP_STRING     ;display error message
        int     18H             ;and try "basic loader"

ACT_FOUND:
        mov     dl,al           ;operating system found
        lodsb                   ;set up registers to read its boot sector
        mov     dh,al
        lodsw
        mov     cx,ax
        mov     bx,OFFSET BOOT
        mov     ax,201H

        push    cx              ;move the mbr to offset 600H first!
        mov     si,bx
        mov     di,600H
        mov     cx,100H
        rep     movsw
        pop     cx
        mov     si,OFFSET MOVED - 7C00H + 600H
        push    si
        ret                     ;and jump there

MOVED:  int     13H             ;load the boot sector
        mov     si,OFFSET NO_RD
        jc      ERROR           ;display message if it can't be read
        mov     ax,OFFSET BOOT
        push    ax
        ret                     ;jump to operating system boot sector


;This displays the asciiz string at ds:si.
DISP_STRING:
        lodsb
        or      al,al
        jz      DSR
        mov     ah,0EH
        int     10H
DSR:    ret

NO_OP   DB      'No operating system.',0
NO_RD   DB      'Cannot load operating system.',0

        ORG     7DBEH

PTABLE  DB      40H dup (?)     ;Here is the partition table

        DB      55H,0AAH

        END     LOADER
