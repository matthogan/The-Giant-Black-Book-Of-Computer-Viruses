;This is  a host COM file for attaching viruses to.

.model  small

.code

        ORG     100H

START:
        mov     dx,OFFSET MESSAGE       ;display copyright notice
        mov     ah,9
        int     21H
        mov     ax,4C00H                ;and terminate
        int     21H

MESSAGE DB      '(C) 1993 American Eagle Publications Inc., All Rights Reserved. Unauthorized ',0DH,0AH
        DB      'use will be prosecuted under applicable copyright and software piracy laws.',0DH,0AH
        DB      'HOST #1 - You have just released a virus!$'

        END     START
