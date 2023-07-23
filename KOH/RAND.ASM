;RAND.ASM for use with KOH.ASM Version 1.03
;Linear Congruential Pseudo-Random Number Generator
;(C) 1994 by American Eagle Publications, Inc. All rights reserved.

;The generator is defined by the equation
;
;              X(N+1) = (A*X(N) + C) mod M
;
;where the constants are defined as
;
M               EQU     43691           ;large prime
A               EQU     M+1
C               EQU     14449           ;large prime
RAND_SEED       DW      0               ;X0, initialized by caller

;Create a pseudo-random number and put it in ax. This routine must preserve
;all registers except ax!
GET_RANDOM:
                push    bx
                push    cx
                push    dx
                mov     ax,[RAND_SEED]
                mov     cx,A            ;multiply
                mul     cx
                add     ax,C            ;add
                adc     dx,0
                mov     cx,M
                div     cx              ;divide
                mov     ax,dx           ;remainder in ax
                mov     [RAND_SEED],ax  ;and save for next round
                pop     dx
                pop     cx
                pop     bx
                retn

