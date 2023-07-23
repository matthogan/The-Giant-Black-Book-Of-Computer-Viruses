;CLEAN will clean up the "unused" data at the end of any file simply by
;calling it with "CLEAN FILENAME".

.model tiny
.code
        ORG     100H

CLEAN:
        mov     ah,9            ;welcome message
        mov     dx,OFFSET HIMSG
        int     21H
        xor     al,al           ;zero file buffer
        mov     di,OFFSET FBUF
        mov     cx,32768
        rep     stosb

        mov     bx,5CH
        mov     dl,[bx]         ;drive # in dl, get FAT info
        mov     ah,1CH
        push    ds              ;save ds as this call messes it up
        int     21H
        pop     ds              ;now al = sectors/cluster for this drive
        cmp     al,40H          ;make sure cluster isn't too large
        jnc     EX              ;for this program to handle it (<32K)
        xor     ah,ah
        mov     cl,9
        shl     ax,cl           ;ax = bytes/cluster now, up to 64K
        mov     [CSIZE],ax

        mov     ah,0FH          ;open the file in read/write mode
        mov     dx,5CH
        int     21H
        mov     bx,5CH
        mov     WORD PTR [bx+14],1   ;set record size
        mov     dx,[bx+18]      ;get current file size
        mov     ax,[bx+16]
        mov     [bx+35],dx      ;use it for random record number
        mov     [bx+33],ax
        push    dx              ;save it for later
        push    ax
        mov     cx,[CSIZE]      ;and divide it by cluster size
        div     cx              ;cluster count in ax, remainder in dx
        or      dx,dx
        jz      C3
        sub     cx,dx           ;bytes to write in cx
        mov     ah,1AH          ;set DTA
        mov     dx,OFFSET FBUF
        int     21H
        mov     dx,bx            ;write to the file
        mov     ah,28H
        mov     cx,[CSIZE]
        int     21H
C3:     pop     ax              ;get original file size in dx:ax
        pop     dx
        mov     [bx+18],dx      ;manually set file size to original value
        mov     [bx+16],ax
        mov     dx,bx
        mov     ah,10H          ;now close file
        int     21H
EX:     mov     ax,4C00H        ;then exit to DOS
        int     21H

HIMSG   DB      'File End CLEANer, Version 2.0 (C) 1995 American Eagle Publications',0DH,0AH,'$'
CSIZE   DW      ?               ;cluster size, in bytes
FBUF    DB      32768 dup (?)   ;zero buffer written to end of file

        END     CLEAN
