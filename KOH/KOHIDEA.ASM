;XOR encryption routine for KOH. This is easy to crack, but fast.


;ROUNDS          EQU     8
;KEYLEN          EQU     6*ROUNDS+4
;IDEABLOCKSIZE   EQU     8

;_Z              DW      KEYLEN DUP (?)
CFB_DC_IDEA     DB      ?                               ;=0 FOR ENCRYPT, FF=DECRYPT
;_TEMP           DB      IDEABLOCKSIZE DUP (?)
;_USERKEY        DW      IDEABLOCKSIZE DUP (?)
IV              DW      4 DUP (?)

;PUBLIC PROCEDURE
;This procedure is irrelevant in an XOR based scheme.
INITKEY_IDEA    PROC    NEAR
        RET
INITKEY_IDEA    ENDP


;PUBLIC PROCEDURE
;VOID IDEASEC(BYTEPTR BUF); ENCRYPTS/DECRYPTS A 512 BYTE BUFFER
IDEASEC         PROC    NEAR
        PUSH    BP
        MOV     BP,SP                           ;bp+4 is the buffer
        push    si
        push    di
        push    ax
        push    cx

        mov     si,[bp+4]
        mov     di,si
        mov     cx,256
        mov     bx,0C9B3H                       ;starting XOR value for sector

ISLP:   lodsw
        xor     ax,bx                           ;xor a word and use it for
        add     bx,017FBH                       ;add this each time around
        add     bx,[IV]
        stosw
        loop    ISLP

ISEX:   pop     cx
        pop     ax
        pop     di
        pop     si
        POP     BP
        RETN    2

IDEASEC         ENDP

