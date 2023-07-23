;*****************************************************************************
;Define the needed external functions and constants.

;include win32.inc           ; some 32-bit constants and structures
UCHAR   EQU <db>
UINT    EQU <dd>  ; 32 bits for WIN32
ULONG   EQU <dd>
COLOR_WINDOW    = 5
SW_SHOWNORMAL   = 1
WS_OVERLAPPED   = 000000000h
WS_THICKFRAME   = 000040000h
WS_CAPTION      = 000C00000h     ; WS_BORDER | WS_DLGFRAME
WS_SYSMENU      = 000080000h
WS_MINIMIZEBOX  = 000020000h
WS_MAXIMIZEBOX  = 000010000h

WS_OVERLAPPEDWINDOW = WS_OVERLAPPED OR WS_CAPTION OR WS_SYSMENU OR WS_THICKFRAME OR WS_MINIMIZEBOX OR WS_MAXIMIZEBOX
IDI_APPLICATION = 32512
IDC_ARROW       = 32512
CW_USEDEFAULT   EQU    8000h
CS_HREDRAW      = 0002h
CS_VREDRAW      = 0001h
CS_GLOBALCLASS  = 4000h    ; Global window class
WM_GETMINMAXINFO= 0024h
WM_CREATE       = 0001h
WM_SIZE         = 0005h
WM_PAINT        = 000Fh
WM_DESTROY      = 0002h

MINMAXINFO struc
  res_x               dd ?
  res_y               dd ?
  maxsize_x           dd ?
  maxsize_y           dd ?
  maxposition_x       dd ?
  maxposition_y       dd ?
  mintrackposition_x  dd ?
  mintrackposition_y  dd ?
  maxtrackposition_x  dd ?
  maxtrackposition_y  dd ?
MINMAXINFO ends

WNDCLASS struc
        clsStyle          UINT     ?   ; class style
        clsLpfnWndProc    ULONG    ?
        clsCbClsExtra     UINT     ?
        clsCbWndExtra     UINT     ?
        clsHInstance      UINT     ?   ; instance handle
        clsHIcon          UINT     ?   ; class icon handle
        clsHCursor        UINT     ?   ; class cursor handle
        clsHbrBackground  UINT     ?   ; class background brush
        clsLpszMenuName   ULONG    ?   ; menu name
        clsLpszClassName  ULONG    ?   ; far ptr to class name
WNDCLASS ends

RECT    struc
        rcLeft          UINT ?
        rcTop           UINT ?
        rcRight         UINT ?
        rcBottom        UINT ?
RECT    ends

MSGSTRUCT struc
    msHWND          UINT    ?
    msMESSAGE       UINT    ?
    msWPARAM        UINT    ?
    msLPARAM        ULONG   ?
    msTIME          ULONG   ?
    msPT            ULONG   ?
MSGSTRUCT ends

PAINTSTRUCT STRUC
    PShdc         UINT             ?
    PSfErase      UINT             ?
    PSrcPaint     UCHAR            size RECT dup(?)
    PSfRestore    UINT             ?
    PSfIncUpdate  UINT             ?
    PSrgbReserved UCHAR            16 dup(?)
PAINTSTRUCT ENDS

extrn            BeginPaint:PROC
extrn            CreateWindowExA:PROC
extrn            DefWindowProcA:PROC
extrn            DispatchMessageA:PROC
extrn            EndPaint:PROC
extrn            ExitProcess:PROC
extrn            GetMessageA:PROC
extrn            GetModuleHandleA:PROC
extrn            LoadCursorA:PROC
extrn            LoadIconA:PROC
extrn            MessageBeep:PROC
extrn            PostQuitMessage:PROC
extrn            RegisterClassA:PROC
extrn            ShowWindow:PROC
extrn            TextOutA:PROC
extrn            TranslateMessage:PROC
extrn            UpdateWindow:PROC
extrn            GetProcAddress:PROC

;For Unicode support, Win32 remaps some functions to either the Ansi or
;Wide char versions. We assume Ansi.
CreateWindowEx   equ <CreateWindowExA>
DefWindowProc    equ <DefWindowProcA>
DispatchMessage  equ <DispatchMessageA>
GetMessage       equ <GetMessageA>
GetModuleHandle  equ <GetModuleHandleA>
LoadCursor       equ <LoadCursorA>
LoadIcon         equ <LoadIconA>
MessageBox       equ <MessageBoxA>
RegisterClass    equ <RegisterClassA>
TextOut          equ <TextOutA>

;*****************************************************************************
.data                                   ;the data area

newhwnd          dd 0
lppaint          PAINTSTRUCT <?>
msg              MSGSTRUCT   <?>
wc               WNDCLASS    <?>

hInst            dd 0

szTitleName      db 'Function Address Locator',0
szClassName      db 'VHOST32',0
szPaint          db 'Function Addresses:',0
MSG_L            EQU ($-offset szPaint)-1
szAddr           db '000000000H',0
MSG_L2           EQU ($-offset szAddr)-1
YPOS             dd 0
MOD1             dd ?

INCLUDE FAL_LIST.INC

;*****************************************************************************
.code

;This is the startup code for the host. It is essentially the same as a
;16-bit Windows program, except that, of course, it calls the 32-bit functions.
;Note that control DOES NOT pass here to start with in this program. It is
;passed to the label VIRUS first, the virus executes, and then control is
;passed here from the virus.

HOST:
        push    LARGE 0
        call    GetModuleHandle         ;get hmod (in eax)
        mov     [hInst], eax            ;and save it here

                                        ;initialize the WndClass structure
        mov     [wc.clsStyle],CS_HREDRAW+CS_VREDRAW+CS_GLOBALCLASS
        mov     [wc.clsLpfnWndProc],OFFSET WndProc
        mov     [wc.clsCbClsExtra],0
        mov     [wc.clsCbWndExtra],0

        mov     eax, [hInst]
        mov     [wc.clsHInstance],eax

        push    LARGE IDI_APPLICATION
        push    LARGE 0
        call    LoadIcon
        mov     [wc.clsHIcon],eax

        push    LARGE IDC_ARROW
        push    LARGE 0
        call    LoadCursor
        mov     [wc.clsHCursor],eax
        xor     eax,eax
        mov     [YPOS],eax

        mov     [wc.clsHbrBackground],COLOR_WINDOW+1
        mov     dword ptr [wc.clsLpszMenuName],0
        mov     dword ptr [wc.clsLpszClassName],OFFSET szClassName

        push    offset wc
        call    RegisterClass

        push    LARGE 0                  ;lpParam
        push    [hInst]                  ;hInstance
        push    LARGE 0                  ;menu
        push    LARGE 0                  ;parent hwnd
        push    LARGE CW_USEDEFAULT      ;height
        push    LARGE CW_USEDEFAULT      ;width
        push    LARGE CW_USEDEFAULT      ;y
        push    LARGE CW_USEDEFAULT      ;x
        push    LARGE WS_OVERLAPPEDWINDOW;Style
        push    offset szTitleName       ;Title string
        push    offset szClassName       ;Class name
        push    LARGE 0                  ;extra style
        call    CreateWindowEx

        mov     [newhwnd],eax
        push    LARGE SW_SHOWNORMAL
        push    [newhwnd]
        call    ShowWindow

        push    [newhwnd]
        call    UpdateWindow

msg_loop:
        push    LARGE 0
        push    LARGE 0
        push    LARGE 0
        push    offset msg
        call    GetMessage
        cmp     ax,0
        jz      end_loop
        push    offset msg
        call    TranslateMessage
        push    offset msg
        call    DispatchMessage
        jmp     msg_loop

end_loop:
        push    [msg.msWPARAM]
        call    ExitProcess             ;this terminates the program

;*****************************************************************************
;Windows 32 requires that ebx, edi and esi be preserved by WndProc. This is
;handled automatically by the assembler using the "uses" statement.
WndProc          proc uses ebx edi esi, hwnd:DWORD, wmsg:DWORD, wparam:DWORD, lparam:DWORD

        LOCAL   theDC:DWORD

        cmp     [wmsg],WM_DESTROY
        je      wmdestroy
        cmp     [wmsg],WM_SIZE
        je      WndProcExitZ
        cmp     [wmsg],WM_CREATE
        je      WndProcExitZ
        cmp     [wmsg],WM_PAINT
        je      wmpaint
        cmp     [wmsg],WM_GETMINMAXINFO
        je      wmgetminmaxinfo
        jmp     defwndproc

wmpaint:
        push    offset lppaint
        push    [hwnd]
        call    BeginPaint
        mov     [theDC],eax

        mov     esi,OFFSET Module1
        mov     [YPOS],0
        call    MAKE_LIST

        push    offset lppaint
        push    [hwnd]
        call    EndPaint
                                  ;fall through
;Default Windows procedure
defwndproc:
        push    [lparam]
        push    [wparam]
        push    [wmsg]
        push    [hwnd]
        call    DefWindowProc
        jmp     WndProcExit

wmdestroy:
        push    LARGE 0
        call    PostQuitMessage
        jmp     WndProcExitZ

wmgetminmaxinfo:
        mov     ebx,[lparam]    ;ptr to minmaxinfo struct
        mov     [(MINMAXINFO ptr ebx).mintrackposition_x],350
        mov     [(MINMAXINFO ptr ebx).mintrackposition_y],60

WndProcExitZ:
        xor     eax,eax         ;set eax=0, z, and exit
WndProcExit:                    ;all done
        ret                     ;exit with a ret (stuff added by assembler)


MAKE_LIST:
        cmp     BYTE PTR [esi],0
        jz      MLX

        push    esi               ;get handle for specified DLL
        call    GetModuleHandle
        mov     [MOD1],eax

        call    DISP_STRING

        push    LARGE MSG_L       ;length of string
        push    offset szPaint    ;string
        mov     eax,[YPOS]
        push    eax               ;y
        push    LARGE 150         ;x
        push    [theDC]           ;the Device Context
        call    TextOut

        add     [YPOS],15         ;new line

FCTN_LOOP:                        ;now display all the functions
        cmp     BYTE PTR [esi],0  ;is there a function?
        jnz     FLP1              ;yes, go handle it
        inc     esi               ;else look for new module
        jmp     MAKE_LIST
FLP1:
        push    esi               ;get function address
        mov     eax,[MOD1]
        push    eax
        call    GetProcAddress
        call    EAX_TO_HEX        ;build address

        call    DISP_STRING       ;display function name

        push    LARGE MSG_L2      ;length of address
        push    offset szAddr     ;string
        mov     eax,[YPOS]
        push    eax               ;y
        push    LARGE 200         ;x
        push    [theDC]           ;the Device Context
        call    TextOut           ;display function address

        add     [YPOS],15         ;new line
        jmp     FCTN_LOOP

MLX:    retn

;Display string at esi, update esi to point to next.
DISP_STRING:
        mov     ecx,esi
DS1:    lodsb
        or      al,al
        jnz     DS1
        mov     eax,esi
        sub     eax,ecx
        dec     eax
        push    eax               ;length of module name
        push    ecx               ;address of module name
        mov     eax,[YPOS]
        push    eax               ;y
        push    LARGE 5           ;x
        push    [theDC]           ;the Device Context
        call    TextOut
        retn

EAX_TO_HEX:
        mov     ebx,OFFSET szAddr+7
        call    AL_TO_HEX
        shr     eax,8
        sub     ebx,2
        call    AL_TO_HEX
        shr     eax,8
        sub     ebx,2
        call    AL_TO_HEX
        shr     eax,8
        sub     ebx,2
        call    AL_TO_HEX
        retn

AL_TO_HEX:
        push    eax
        mov     cl,al
        and     cl,0FH
        mov     ch,al
        shr     ch,4
        mov     al,cl
        call    MAKE_HEX
        mov     ah,al
        mov     al,ch
        call    MAKE_HEX
        mov     [ebx],ax
        pop     eax
        retn

MAKE_HEX:
        add     al,30H
        cmp     al,3AH
        jc      MHX
        add     al,7
MHX:    retn


WndProc          endp

public WndProc
