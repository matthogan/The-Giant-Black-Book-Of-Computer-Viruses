;GB-Behavior Checker
;(C) 1995 American Eagle Publications, Inc. All Rights Reserved.

.model tiny
.code

        ORG     100H

START:  jmp     GO_RESIDENT             ;jump to startup code

;***************************************************************************
;Resident part starts here

;Data area
FIRST           DB      0             ;Flag to indicate first Int 21H, Fctn 31H
VIDSEG          DW      ?             ;Video segment to use
CURSOR          DW      ?             ;Cursor position
VIDEO_BUF       DW      80*4 dup (?)  ;Buffer for video memory

;***************************************************************************
;Interrupt 13H Handler
OLD_13H         DD      ?               ;Original INT 13H vector

;The Interrupt 13H hook flags attemtps to write to the boot sector or master
;boot sector.
INT_13H:
        cmp     ah,3                    ;flag writes
        jne     DO_OLD
        cmp     cx,1                    ;to cylinder 0, sector 1
        jne     DO_OLD
        cmp     dh,0                    ;head 0
        jne     DO_OLD
        call    BS_WRITE_FLAG           ;writing to boot sector, flag it
        jz      DO_OLD                  ;ok'ed by user, go do it
        stc                             ;else return with c set
        retf    2                       ;and don't allow a write
DO_OLD: jmp     cs:[OLD_13H]            ;go execute old Int 13H handler

;This routine flags the user to tell him that an attempt is being made to
;write to the boot sector, and it asks him what he wants to do. If he wants
;the write to be stopped, it returns with Z set.
BS_WRITE_FLAG:
        push    ds
        push    si
        push    ax
        call    SAVE_VIDEO              ;save a block of video for our use
        push    cs
        pop     ds
        mov     si,OFFSET BS_FLAG
        call    ASK
        pushf
        call    RESTORE_VIDEO           ;restore saved video
        popf
        pop     ax
        pop     si
        pop     ds
        ret

BS_FLAG         DB      'An attempt is being made to write to the boot sector. Allow it? ',7,7,7,7,0


;***************************************************************************
;Interrupt 21H Handler

OLD_21H         DD      ?               ;Original INT 21H handler

;This is the interrupt 21H hook. It flags attempts to open COM or EXE files
;in read/write mode using Function 3DH. It also flags attempts to go memory
;resident using Function 31H.
INT_21H:
        cmp     ah,31H                  ;something going resident?
        jnz     TRY_3D                  ;nope, check next condition to flag
        cmp     BYTE PTR cs:[FIRST],0   ;first time this is called?
        jz      I21RF                   ;yes, must allow GBC to go resident itself
        call    RESIDENT_FLAG           ;yes, ask user if he wants it
        jz      I21R                    ;he wanted it, go ahead and do it
        mov     ah,4CH                  ;else change to non-TSR terminate
        jmp     SHORT I21R              ;and pass that to DOS
TRY_3D: push    ax
        and     al,2                    ;mask possible r/w flag
        cmp     ax,3D02H                ;is it an open r/w?
        pop     ax
        jnz     I21R                    ;no, pass control to DOS

        push    si
        push    ax
        mov     si,dx                   ;ds:si points to ASCIIZ file name
T3D1:   lodsb                           ;get a byte of string
        or      al,al                   ;end of string?
        jz      T3D5                    ;yes, couldnt be COM or EXE, so go to DOS
        cmp     al,'.'                  ;is it a period?
        jnz     T3D1                    ;nope, go get another
        lodsw                           ;get 2 bytes
        or      ax,2020H                ;make it lower case
        cmp     ax,'oc'                 ;are they "co"?
        jz      T3D2                    ;yes, continue
        cmp     ax,'xe'                 ;no, are they "ex"?
        jnz     T3D5                    ;no, not COM or EXE, so go to DOS
        jmp     SHORT T3D3
T3D2:   lodsb                           ;get 3rd byte (COM file)
        or      al,20H                  ;make it lower case
        cmp     al,'m'                  ;is it "m"
        jz      T3D4                    ;yes, it is COM
T3D3:   lodsb                           ;get 3rd byte (EXE file)
        or      al,20H                  ;make lower case
        cmp     al,'e'                  ;is it "e"
        jnz     T3D5                    ;nope, go to original int 21H
T3D4:   pop     ax                      ;if we get here, it's a COM or EXE
        pop     si

        call    RDWRITE_FLAG            ;ok, COM or EXE, ask user if he wants it
        jz      I21R                    ;yes, he did, go let DOS do it
        stc                             ;else set carry to indicate failure
        retf    2                       ;and return control to caller

T3D5:   pop     ax                      ;not COM or EXE, so clean up stack
        pop     si
        jmp     SHORT I21R              ;and go to old INT 21H handler

I21RF:  inc     BYTE PTR cs:[FIRST]     ;update FIRST flag
I21R:   jmp     cs:[OLD_21H]            ;pass control to original handler

;This routine asks the user if he wants a program that is attempting to go
;memory resident to do it or not. If the user wants it to go resident, this
;routine returns with Z set.
RESIDENT_FLAG:
        push    ds
        push    si
        push    ax
        call    SAVE_VIDEO              ;save a block of video for our use
        push    cs
        pop     ds
        mov     si,OFFSET RES_FLAG
        call    ASK
        pushf
        call    RESTORE_VIDEO           ;restore saved video
        popf
        pop     ax
        pop     si
        pop     ds
        ret

RES_FLAG        DB      7,7,7,'A program is attempting to go resident. Allow it? ',0

;RDWRITE_FLAG asks the user if he wants a COM or EXE file to be opened in read/
;write mode or not. If he does, it returns with Z set.
RDWRITE_FLAG:
        push    ds
        push    si
        push    ax
        call    SAVE_VIDEO              ;save a block of video for our use
        mov     si,dx
        call    DISP_STRING             ;display file name being opened
        push    cs
        pop     ds
        mov     si,OFFSET RW_FLAG       ;and query user
        call    ASK
        pushf
        call    RESTORE_VIDEO           ;restore saved video
        popf
        pop     ax
        pop     si
        pop     ds
        ret

RW_FLAG         DB      7,7,7,' is being opened in read/write mode. Allow it? ',0

;***************************************************************************
;Resident utility functions

;Ask a question. Display string at ds:si and get a character. If the character
;is 'y' or 'Y' then return with z set, otherwise return nz.
ASK:
        call    DISP_STRING
        mov     ah,0
        int     16H
        or      al,20H
        cmp     al,'y'
        ret

;This displays a null terminated string on the console.
DISP_STRING:
        lodsb
        or      al,al
        jz      DSR
        mov     ah,0EH
        int     10H
        jmp     DISP_STRING
DSR:    ret

;Save 1st 4 lines of video memory to internal buffer. Fill it with spaces and
;a line.
SAVE_VIDEO:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        mov     ds,cs:[VIDSEG]          ;ds:si set to video memory
        push    cs
        pop     es                      ;es:di set to internal storage buffer
        xor     si,si
        mov     di,OFFSET VIDEO_BUF
        mov     cx,80*4
        rep     movsw                   ;save 1st 4 lines of video memory
        mov     ah,3                    ;now get cursor position
        mov     bh,0
        int     10H
        mov     cs:[CURSOR],dx          ;and save it here

        push    ds
        pop     es
        xor     di,di
        mov     ax,0720H                ;fill 3 lines with spaces
        mov     cx,80*3
        rep     stosw
        mov     ax,0700H+'_'            ;and 1 with a line
        mov     cx,80
        rep     stosw
        mov     ah,2                    ;set cursor position to 0,0
        mov     bh,0
        xor     dx,dx
        int     10H
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

;Restore 1st 4 lines of video memory from internal buffer.
RESTORE_VIDEO:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        mov     es,cs:[VIDSEG]
        xor     di,di                   ;es:di = video memory
        push    cs
        pop     ds
        mov     si,OFFSET VIDEO_BUF     ;ds:si = internal storage buffer
        mov     cx,80*4
        rep     movsw                   ;restore video memory
        mov     ah,2                    ;restore cursor position
        mov     bh,0
        mov     dx,[CURSOR]
        int     10H
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

;***************************************************************************
;Startup code begins here. This part does not stay resident.

GO_RESIDENT:
        mov     ah,9                    ;say hello
        mov     dx,OFFSET HELLO
        int     21H

        mov     [VIDSEG],0B000H         ;determine video segment to use
        mov     ah,0FH                  ;assume b&w monitor
        int     10H                     ;but ask what mode we're in
        cmp     al,7                    ;is it mode 7
        jz      GR1                     ;yes, it's b&w/hercules
        mov     [VIDSEG],0B800H         ;else assume cga/ega/vga

GR1:    mov     ax,3513H                ;hook interrupt 13H
        int     21H                     ;get old vector
        mov     WORD PTR [OLD_13H],bx
        mov     WORD PTR [OLD_13H+2],es
        mov     ax,2513H                ;and set new vector
        mov     dx,OFFSET INT_13H
        int     21H

        mov     ax,3521H                ;hook interrupt 21H
        int     21H                     ;get old vector
        mov     WORD PTR [OLD_21H],bx
        mov     WORD PTR [OLD_21H+2],es
        mov     ax,2521H                ;and set new vector
        mov     dx,OFFSET INT_21H
        int     21H

        mov     dx,OFFSET GO_RESIDENT   ;now go resident
        mov     cl,4
        shr     dx,cl
        inc     dx
        mov     ax,3100H                ;using Int 21H, Function 31H
        int     21H

HELLO   DB      'GB-Behavior Checker v 1.00 (C) 1995 American Eagle Publications, Inc.$'

        end     START
