;DEVICE.ASM is a simple device driver to illustrate the structure of
;a device driver. All it does is announce its presence when loaded.

;(C) 1995 American Eagle Publications, Inc., All rights reserved.

.model tiny
.code

        ORG     0

HEADER:
        dd      -1              ;Link to next device driver
        dw      0C840H          ;Device attribute word
        dw      OFFSET STRAT    ;Pointer to strategy routine
        dw      OFFSET INTR     ;Pointer to interrupt routine
        db      'DEVICE'        ;Device name

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
        retn

HELLO_MSG       DB      'DEVICE 1.00 Says "Hello!"',0DH,0AH,0

;This routine is used for all non-implemented functions.
NOT_IMPLEMENTED:
        xor     ax,ax           ;zero ax to indicate success and exit
        retn

END_DRIVER:                     ;label to identify end of device driver

        END     STRAT
