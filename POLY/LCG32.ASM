;32 bit Linear Congruential Pseudo-Random Number Generator

.model tiny
.code
.386

        PUBLIC  RANDOM_SEED
        PUBLIC  GET_RANDOM


;The generator is defined by the equation
;
;              X(N+1) = (A*X(N) + C) mod M
;
;where the constants are defined as
;
M               DD      134217729
A               DD      44739244
C               DD      134217727
RAND_SEED       DD      0               ;X0, initialized by RANDOM_SEED

;Set RAND_SEED up with a random number to seed the pseudo-random number
;generator. This routine should preserve all registers! it must be totally
;relocatable!
RANDOM_SEED     PROC    NEAR
                push    si
                push    ds
                push    dx
                push    cx
                push    bx
                push    ax
                call    RS1
RS1:            pop     bx
                sub     bx,OFFSET RS1
                xor     ax,ax
                mov     ds,ax
                mov     si,46CH
                lodsd
                xor     edx,edx
                mov     ecx,M
                div     ecx
                mov     cs:[bx][RAND_SEED],edx
                pop     ax
                pop     bx
                pop     cx
                pop     dx
                pop     ds
                pop     si
                retn

RANDOM_SEED     ENDP

;Create a pseudo-random number and put it in ax.
GET_RANDOM      PROC    NEAR
                push    bx
                push    cx
                push    dx
                call    GR1
GR1:            pop     bx
                sub     bx,OFFSET GR1
                mov     eax,[bx][RAND_SEED]
                mov     ecx,[bx][A]                         ;multiply
                mul     ecx
                add     eax,[bx][C]                         ;add
                adc     edx,0
                mov     ecx,[bx][M]
                div     ecx                                 ;divide
                mov     eax,edx                             ;remainder in ax
                mov     [bx][RAND_SEED],eax                 ;and save for next round
                pop     dx
                pop     cx
                pop     bx
                retn

GET_RANDOM      ENDP

                END
