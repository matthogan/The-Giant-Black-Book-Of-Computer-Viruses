;A Basic Boot Sector for DOS 2.0 to 6.22. This is non-viral! 
; 
;(C) 1995 American Eagle Publications, Inc. All Rights Reserved!
 
 
;This segment is where the first operating system file (IO.SYS) will be
;loaded and executed from. We don't know (or care) what is there, as long as
;it will execute at 0070:0000H, but we do need the address to jump to defined
;in a separate segment so we can execute a far jump to it.
DOS_LOAD        SEGMENT AT 0070H 
                ASSUME  CS:DOS_LOAD 
 
                ORG     0 
 
LOAD:                               ;Start of the first operating system program
 
DOS_LOAD        ENDS 
 
 
MAIN            SEGMENT BYTE 
                ASSUME  CS:MAIN,DS:MAIN,SS:NOTHING 
 
 
;This is the loader for the boot sector. It writes the boot sector to
;the A: drive in the right place, after it has set up the basic disk
;parameters. The loader is what gets executed when this program is executed
;from DOS as a COM file. 
 
                ORG     100H 
 
LOADER: 
                mov     ax,201H         ;load the existing boot sector
                mov     bx,OFFSET DISK_BUF      ;into this buffer
                mov     cx,1            ;Drive 0, Track 0, Head 0, Sector 1
                mov     dx,0 
                int     13H 
                mov     ax,201H         ;try twice to compensate for disk
                int     13H             ;change errors 
 
                mov     si,OFFSET DISK_BUF + 11 
                mov     di,OFFSET BOOTSEC + 11 
                mov     cx,19 
                rep     movsb           ;move disk data to new boot sector
 
                mov     ax,301H         ;and write new boot sector to disk
                mov     bx,OFFSET BOOTSEC 
                mov     cx,1 
                mov     dx,0 
                int     13H 
 
                mov     ax,4C00H        ;now exit to DOS
                int     21H 
 
 
 
 
 
 
;This area is reserved for loading the boot sector from the disk which is going
;to be modified by the loader, as well as the first sector of the root dir,
;when checking for the existence of system files and loading the first system
;file. The location is fixed because this area is free at the time of the
;execution of the boot sector. 
 
                ORG     0500H 
 
DISK_BUF:       DB      ?                       ;Start of the buffer
 
;Here is the start of the boot sector code. This is the chunk we will take out
;of the compiled COM file and put it in the first sector on a floppy disk.
 
                ORG     7C00H 
 
BOOTSEC:        JMP     SHORT BOOT              ;Jump to start of boot code
                NOP                             ;always leave 3 bytes here
 
 
DOS_ID:         DB      'Am Eagle'              ;Name for boot sector (8 bytes)
SEC_SIZE:       DW      200H   ;Size of a sector, in bytes
SECS_PER_CLUST: DB      2      ;Number of sectors in a cluster
FAT_START:      DW      1      ;Starting sec for 1st File Allocation Table (FAT)
FAT_COUNT:      DB      2      ;Number of FATs on this disk
ROOT_ENTRIES:   DW      70H    ;Number of root directory entries
SEC_COUNT:      DW      2D0H   ;Total number of sectors on this disk
DISK_ID:        DB      0FDH   ;Disk type code (This is 360KB)
SECS_PER_FAT:   DW      2      ;Number of sectors per FAT
SECS_PER_TRK:   DW      9      ;Sectors per track for this drive
HEADS:          DW      2      ;Number of heads (sides) on this drive
HIDDEN_SECS:    DW      0      ;Number of hidden sectors on the disk
 
;Here is the start of the boot sector executable code 
 
BOOT:           CLI                                     ;interrupts off
                XOR     AX,AX                           ;prepare to set up segs
                MOV     ES,AX                           ;set DS=ES=SS=0
                MOV     DS,AX 
                MOV     SS,AX                           ;start stack @ 0000:7C00
                MOV     SP,OFFSET BOOTSEC 
                STI                                     ;now turn interrupts on
 
;Here we look at the first file on the disk to see if it is the first MS-DOS
;system file, IO.SYS. 
LOOK_SYS: 
                MOV     AL,BYTE PTR [FAT_COUNT]         ;get fats per disk
                XOR     AH,AH 
                MUL     WORD PTR [SECS_PER_FAT]         ;mult by secs per fat
                ADD     AX,WORD PTR [HIDDEN_SECS]       ;add hidden sectors
                ADD     AX,WORD PTR [FAT_START]         ;add starting fat sector
                PUSH    AX                              ;start of root dir in ax
                MOV     BP,AX                           ;save it here
 
                MOV     AX,20H                          ;dir entry size
                MUL     WORD PTR [ROOT_ENTRIES]         ;dir size in ax
                MOV     BX,WORD PTR [SEC_SIZE]          ;sector size
                ADD     AX,BX                           ;add one sector
                DEC     AX                              ;decrement by 1
                DIV     BX                              ;ax=# secs in root dir
                ADD     BP,AX                           ;now bp is start of data
                MOV     BX,OFFSET DISK_BUF              ;disk buf at 0000:0500
                POP     AX                              ;ax=start of root dir
                CALL    CONVERT                         ;and get bios sec @
                INT     13H                             ;read 1st root sector
                JC      $ 
 
                MOV     DI,BX                           ;compare 1st file with
                MOV     CX,11                           ;required file name
                MOV     SI,OFFSET SYSFILE_1             ;of first system file
                REPZ    CMPSB 
                JNZ     $                               ;not same, hang machine
 
;Ok, system file is there, so load it 
LOAD_SYSTEM: 
                MOV     AX,WORD PTR [DISK_BUF+1CH]      ;get file size of IO.SYS
                XOR     DX,DX 
                DIV     WORD PTR [SEC_SIZE]             ;and divide by sec size
                INC     AX                              ;ax=no of secs to read
                CMP     AX,39H                          ;don't load too much!!
                JLE     LOAD1                           ;(<< 7C00H-700H)
                MOV     AX,39H                          ;plus room for stack!
LOAD1:          MOV     DI,AX                           ;store that number in BP
                PUSH    BP                              ;save start of IO.SYS
                MOV     BX,700H                         ;disk buffer = 0000:0700
RD_IOSYS:       MOV     AX,BP                           ;and get sector to read
                CALL    CONVERT                         ;get bios Trk/Cyl/Sec
                INT     13H                             ;and read a sector
                JC      $                               ;halt on error
                INC     BP                              ;increment sec to read
                ADD     BX,WORD PTR [SEC_SIZE]          ;and update buf address
                DEC     DI                              ;dec no of secs to read
                JNZ     RD_IOSYS                        ;get another if needed
 
;Ok, IO.SYS has been read in, now transfer control to it
DO_BOOT: 
                MOV     CH,BYTE PTR [DISK_ID]           ;Put drive type in ch
                MOV     DL,0                            ;Drive number in dl
                POP     BX                              ;Start of data in bx
                JMP     FAR PTR LOAD                    ;far jump to IO.SYS
 
;Convert sequential sector number in ax to BIOS Track, Head, Sector information.
;Save track number in CH, head in DH, sector number in CH, set AX to 201H. Since
;this is for floppies only, we don't have to worry about track numbers greater
;than 255. 
CONVERT: 
                XOR     DX,DX 
                DIV     WORD PTR [SECS_PER_TRK]         ;divide ax by secs/trk
                INC     DL                              ;dl=sec # to start read
                                                        ;al=track/head count
                MOV     CL,DL                           ;save sector here
                XOR     DX,DX 
                DIV     WORD PTR [HEADS]                ;divide ax by head count
                MOV     DH,DL                           ;head to dh
                XOR     DL,DL                           ;drive in dl (0)
                MOV     CH,AL                           ;track to ch
                MOV     AX,201H                         ;ax="read 1 sector"
                RET 
 
SYSFILE_1       DB      'IO      SYS'                   ;MS DOS System file
 
                ORG     7DFEH 
 
BOOT_ID         DW      0AA55H                          ;Boot sector ID word
 
MAIN            ENDS 
 
                END     LOADER 
