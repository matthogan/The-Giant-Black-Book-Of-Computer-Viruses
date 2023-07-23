.model tiny
.code

        ORG     100H
START:
        mov     ax,3D02H
        mov     dx,OFFSET FNAME
        int     21H                     ;just open file FNAME

        mov     bx,ax                   ;and close it
        mov     ah,3EH
        int     21H

        ret                             ;then exit

FNAME   DB      'TEST.COM',0

        END     START
