program find_tpe;    {Finds TPE 1.3 infected COM files}

uses dos;

const
  DEBUG            :boolean=FALSE;
type
  code_seg         =array[$100..$FFFF] of byte;

var
  SR               :SearchRec;
  out_file         :text;        {Output text file}
  r                :registers;
  buf              :^code_seg;
  ip,sp            :word;
  infcnt           :word;
  modified         :^code_seg;

{This is the giant case statement}
function analyze_instruction:boolean;
var
  ai               :boolean;
  l                :longint;
  w,w2             :word;
  i                :integer;
  c                :byte;
begin
  if DEBUG then writeln(out_file,ip,' ',r.flags,' ',buf^[ip]);
  ai:=true;
  case buf^[ip] of
    $09 : case buf^[ip+1] of
            $C0 : ip:=ip+2;           {or ax,ax}
            $C9 : ip:=ip+2;           {or cx,cx}
            $D2 : ip:=ip+2;           {or dx,dx}
            $DB : ip:=ip+2;           {or bx,bx}
            $E4 : ip:=ip+2;           {or sp,sp}
            $ED : ip:=ip+2;           {or bp,bp}
            $F6 : ip:=ip+2;           {or si,si}
            $FF : ip:=ip+2;           {or di,di}
            else  ai:=false;
            end;
    $21 : case buf^[ip+1] of
            $C0 : ip:=ip+2;           {and ax,ax}
            $C9 : ip:=ip+2;           {and cx,cx}
            $D2 : ip:=ip+2;           {and dx,dx}
            $DB : ip:=ip+2;           {and bx,bx}
            $E4 : ip:=ip+2;           {and sp,sp}
            $ED : ip:=ip+2;           {and bp,bp}
            $F6 : ip:=ip+2;           {and si,si}
            $FF : ip:=ip+2;           {and di,di}
            else  ai:=false;
            end;
    $30 : case buf^[ip+1] of
            $04 : ip:=ip+2;           {xor [si],al}
            $05 : ip:=ip+2;           {xor [di],al}
            $07 : ip:=ip+2;           {xor [bx],al}
            $14 : ip:=ip+2;           {xor [si],dl}
            $15 : ip:=ip+2;           {xor [di],dl}
            $17 : ip:=ip+2;           {xor [bx],dl}
            $1C : ip:=ip+2;           {xor [si],bl}
            $24 : ip:=ip+2;           {xor [si],ah}
            $25 : ip:=ip+2;           {xor [di],ah}
            $34 : ip:=ip+2;           {xor [si],dh}
            $37 : ip:=ip+2;           {xor [bx],dh}
            $3D : ip:=ip+2;           {xor [di],bh}
            $C4 : begin               {xor ah,al}
                    r.ah:=r.ah xor r.al;
                    if r.ah=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+2;
                  end;
            $D6 : begin               {xor dh,dl}
                    r.dh:=r.dh xor r.dl;
                    if r.dh=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+2;
                  end;

            $DF : begin               {xor bh,bl}
                    r.bh:=r.bh xor r.bl;
                    ip:=ip+2;
                  end;

            $E0 : ip:=ip+2;           {xor al,al}
            $F2 : begin               {xor dl,dh}
                    r.dl:=r.dl xor r.dh;
                    ip:=ip+2;
                  end;
            $FB : begin               {xor bl,bh}
                    r.bl:=r.bl xor r.bh;
                    ip:=ip+2;
                  end;
            else  ai:=false;
            end;
    $35 : begin                       {xor ax,IMM}
            r.ax:=r.ax xor (buf^[ip+1]+256*buf^[ip+2]);
            ip:=ip+3;
          end;
    $40 : begin                       {inc ax}
            r.ax:=r.ax+1;
            if r.ax=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $41 : begin                       {inc cx}
            r.cx:=r.cx+1;
            if r.cx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $42 : begin                       {inc dx}
            r.dx:=r.dx+1;
            if r.dx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $43 : begin                       {inc bx}
            r.bx:=r.bx+1;
            if r.bx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $45 : begin                       {inc bp}
            r.bp:=r.bp+1;
            if r.bp=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $46 : begin                       {inc si}
            r.si:=r.si+1;
            if r.si=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $47 : begin                       {inc di}
            r.di:=r.di+1;
            if r.di=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $48 : begin                       {dec ax}
            r.ax:=r.ax-1;
            if r.ax=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $49 : begin                       {dec cx}
            r.cx:=r.cx-1;
            if r.cx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $4A : begin                       {dec dx}
            r.dx:=r.dx-1;
            if r.dx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $4B : begin                       {dec bx}
            r.bx:=r.bx-1;
            if r.bx=0 then r.flags:=r.flags or 1
            else r.flags:=r.flags and $FFFE;
            ip:=ip+1;
          end;
    $4D : begin                       {dec bp}
            r.bp:=r.bp-1;
            if r.bp=0 then r.flags:=r.flags or 5
            else r.flags:=r.flags and $FFFA;
            ip:=ip+1;
          end;
    $4E : begin                       {dec si}
            r.si:=r.si-1;
            if r.si=0 then r.flags:=r.flags or 5
            else r.flags:=r.flags and $FFFA;
            ip:=ip+1;
          end;
    $4F : begin                       {dec di}
            r.di:=r.di-1;
            if r.di=0 then r.flags:=r.flags or 5
            else r.flags:=r.flags and $FFFA;
            ip:=ip+1;
          end;
    $50 : begin                       {push ax}
            buf^[sp-1]:=r.ah;
            buf^[sp-2]:=r.al;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $51 : begin                       {push cx}
            buf^[sp-1]:=r.ch;
            buf^[sp-2]:=r.cl;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $52 : begin                       {push dx}
            buf^[sp-1]:=r.dh;
            buf^[sp-2]:=r.dl;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $53 : begin                       {push bx}
            buf^[sp-1]:=r.bh;
            buf^[sp-2]:=r.bl;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $54 : begin                       {push sp}
            sp:=sp-2;
            ip:=ip+1;
          end;
    $55 : begin                       {push bp}
            buf^[sp-1]:=r.bp and 255;
            buf^[sp-2]:=r.bp shr 8;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $56 : begin                       {push si}
            buf^[sp-1]:=r.si and 255;
            buf^[sp-2]:=r.si shr 8;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $57 : begin                       {push di}
            buf^[sp-1]:=r.di and 255;
            buf^[sp-2]:=r.di shr 8;
            sp:=sp-2;
            ip:=ip+1;
          end;
    $58 : begin                       {pop ax}
            r.al:=buf^[sp];
            r.ah:=buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $59 : begin                       {pop cx}
            r.cl:=buf^[sp];
            r.ch:=buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5A : begin                       {pop dx}
            r.dl:=buf^[sp];
            r.dh:=buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5B : begin                       {pop bx}
            r.bl:=buf^[sp];
            r.bh:=buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5C : begin                       {pop sp}
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5D : begin                       {pop bp}
            r.bp:=buf^[sp]+256*buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5E : begin                       {pop si}
            r.si:=buf^[sp]+256*buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $5F : begin                       {pop di}
            r.di:=buf^[sp]+256*buf^[sp+1];
            sp:=sp+2;
            ip:=ip+1;
          end;
    $75 : begin                       {jnz XX}
            if (r.flags and 1) = 0 then
              begin
                if buf^[ip+1]<=$80 then ip:=ip+2+buf^[ip+1]
                else ip:=ip+2+buf^[ip+1]-$100;
              end
            else ip:=ip+2;
          end;
    $80 : case buf^[ip+1] of
            $C0 : begin               {add al,imm}
                    if r.al+buf^[ip+2]>255 then
                      begin
                        r.al:=r.al+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.al:=r.al+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            $C2 : begin               {add dl,imm}
                    if r.dl+buf^[ip+2]>255 then
                      begin
                        r.dl:=r.dl+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.dl:=r.dl+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            $C3 : begin               {add bl,imm}
                    if r.bl+buf^[ip+2]>255 then
                      begin
                        r.bl:=r.bl+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.bl:=r.bl+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            $C4 : begin               {add ah,imm}
                    if r.ah+buf^[ip+2]>255 then
                      begin
                        r.ah:=r.ah+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.ah:=r.ah+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            $C6 : begin               {add dh,imm}
                    if r.dh+buf^[ip+2]>255 then
                      begin
                        r.dh:=r.dh+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.dh:=r.dh+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            $C7 : begin               {add bh,imm}
                    if r.bh+buf^[ip+2]>255 then
                      begin
                        r.bh:=r.bh+buf^[ip+2]-$100;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        r.bh:=r.bh+buf^[ip+2];
                        r.flags:=r.flags and $FFFD;
                      end;
                    ip:=ip+3;
                  end;
            else  ai:=false;
            end;
    $81 : case buf^[ip+1] of
            $C8 : begin               {or AX,imm}
                    r.ax:=r.ax or (buf^[ip+1]+256*buf^[ip+2]);
                    if r.ax=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $CA : begin               {or DX,imm}
                    r.dx:=r.dx or (buf^[ip+1]+256*buf^[ip+2]);
                    if r.dx=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $CD : begin               {or bp,imm}
                    r.bp:=r.bp or (buf^[ip+1]+256*buf^[ip+2]);
                    if r.si=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $CE : begin               {or SI,imm}
                    r.si:=r.si or (buf^[ip+1]+256*buf^[ip+2]);
                    if r.si=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $CF : begin               {or DI,imm}
                    r.di:=r.di or (buf^[ip+1]+256*buf^[ip+2]);
                    if r.di=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $E2 : begin               {and dx,imm}
                    r.dx:=r.dx and (buf^[ip+1]+256*buf^[ip+2]);
                    if r.dx=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $E3 : begin               {and bx,imm}
                    r.bx:=r.bx and (buf^[ip+1]+256*buf^[ip+2]);
                    if r.bx=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $E5 : begin               {and bp,imm}
                    r.bp:=r.bp and (buf^[ip+1]+256*buf^[ip+2]);
                    if r.bp=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $E6 : begin               {and si,imm}
                    r.si:=r.si and (buf^[ip+1]+256*buf^[ip+2]);
                    if r.si=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            $E7 : begin               {and di,imm}
                    r.di:=r.di and (buf^[ip+1]+256*buf^[ip+2]);
                    if r.di=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+4;
                  end;
            else  ai:=false;
            end;
    $83 : case buf^[ip+1] of
            $C6 : begin               {add si,imm}
                    if buf^[ip+2]<$80 then i:=buf^[ip+2]
                    else i:=buf^[ip+2]-$100;
                    if r.si+i>=$10000 then
                      begin
                        r.si:=r.si+i-$10000;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        if r.si<-i then
                          begin
                            r.si:=r.si+i+$10000;
                            r.flags:=r.flags or 2;
                          end
                        else
                          begin
                            r.si:=r.si+i;
                            r.flags:=r.flags and $FFFD;
                          end;
                      end;
                    if r.si=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+3;
                  end;
            $C7 : begin               {add di,imm}
                    if buf^[ip+2]<$80 then i:=buf^[ip+2]
                    else i:=buf^[ip+2]-$100;
                    if r.di+i>=$10000 then
                      begin
                        r.di:=r.di+i-$10000;
                        r.flags:=r.flags or 2;
                      end
                    else
                      begin
                        if r.di<-i then
                          begin
                            r.di:=r.di+i+$10000;
                            r.flags:=r.flags or 2;
                          end
                        else
                          begin
                            r.di:=r.di+i;
                            r.flags:=r.flags and $FFFD;
                          end;
                      end;
                    if r.di=0 then r.flags:=r.flags or 1
                    else r.flags:=r.flags and $FFFE;
                    ip:=ip+3;
                  end;
            else  ai:=false;
            end;
    $88 : case buf^[ip+1] of
            $04 : begin               {mov al,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $05 : begin               {mov al,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            $07 : begin               {mov al,[bx]}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+1;
                  end;
            $14 : begin               {mov dl,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $15 : begin               {mov dl,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            $17 : begin               {mov dl,[bx]}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+1;
                  end;
            $1C : begin               {mov bl,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $1D : begin               {mov bl,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            $24 : begin               {mov ah,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $25 : begin               {mov ah,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            $27 : begin               {mov ah,[bx]}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+1;
                  end;
            $34 : begin               {mov dh,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $35 : begin               {mov dh,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            $37 : begin               {mov dh,[bx]}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+1;
                  end;
            $3C : begin               {mov bh,[si]}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+1;
                  end;
            $3D : begin               {mov bh,[di]}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+1;
                  end;
            else  ai:=false;
            end;
    $89 : case buf^[ip+1] of
            $05 : ip:=ip+2;           {mov [di],ax}
            $C0 : ip:=ip+2;           {mov ax,ax}
            $C2 : ip:=ip+2;           {mov dx,ax}
            $C6 : ip:=ip+2;           {mov bp,bp}
            $C9 : ip:=ip+2;           {mov cx,cx}
            $CE : ip:=ip+2;           {mov si,cx}
            $CF : ip:=ip+2;           {mov di,cx}
            $D0 : ip:=ip+2;           {mov ax,dx}
            $D2 : ip:=ip+2;           {mov dx,dx}
            $D3 : ip:=ip+2;           {mov bx,dx}
            $D5 : ip:=ip+2;           {mov bp,dx}
            $D7 : ip:=ip+2;           {mov di,dx}
            $D8 : ip:=ip+2;           {mov ax,bx}
            $DB : ip:=ip+2;           {mov bx,bx}
            $DD : ip:=ip+2;           {mov bp,bx}
            $DE : ip:=ip+2;           {mov si,bx}
            $E2 : ip:=ip+2;           {mov dx,sp}
            $E6 : ip:=ip+2;           {mov si,sp}
            $E7 : ip:=ip+2;           {mov di,sp}
            $E8 : ip:=ip+2;           {mov ax,bp}
            $EB : ip:=ip+2;           {mov bx,bp}
            $ED : ip:=ip+2;           {mov si,ax}
            $EE : ip:=ip+2;           {mov si,bp}
            $F0 : ip:=ip+2;           {mov ax,si}
            $F1 : ip:=ip+2;           {mov cx,si}
            $F3 : ip:=ip+2;           {mov bx,si}
            $F6 : ip:=ip+2;           {mov si,si}
            $F7 : ip:=ip+2;           {mov di,si}
            $F9 : ip:=ip+2;           {mov cx,di}
            $FA : ip:=ip+2;           {mov dx,di}
            $FD : ip:=ip+2;           {mov bp,di}
            $FF : ip:=ip+2;           {mov di,di}
            else  ai:=false;
            end;
    $8A : case buf^[ip+1] of
            $04 : begin               {mov [si],al}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $05 : begin               {mov [di],al}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            $07 : begin               {mov [bx],al}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+$10;
                  end;
            $14 : begin               {mov [si],dl}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $15 : begin               {mov [di],dl}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            $17 : begin               {mov [bx],dl}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+$10;
                  end;
            $1C : begin               {mov [si],bl}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $1D : begin               {mov [di],bl}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            $24 : begin               {mov [si],ah}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $25 : begin               {mov [di],ah}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            $27 : begin               {mov [bx],ah}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+$10;
                  end;
            $34 : begin               {mov [si],dh}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $35 : begin               {mov [di],dh}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            $37 : begin               {mov [bx],dh}
                    ip:=ip+2;
                    modified^[r.bx]:=modified^[r.bx]+$10;
                  end;
            $3C : begin               {mov [si],bh}
                    ip:=ip+2;
                    modified^[r.si]:=modified^[r.si]+$10;
                  end;
            $3D : begin               {mov [di],bh}
                    ip:=ip+2;
                    modified^[r.di]:=modified^[r.di]+$10;
                  end;
            else  ai:=false;
            end;
    $8B : case buf^[ip+1] of           {mov ax,[si]}
            $04 : begin
                    r.ax:=buf^[r.si];
                    ip:=ip+2;
                  end;
            else  ai:=false;
            end;
    $90 : ip:=ip+1;                   {nop}
    $B0 : begin                       {mov al,imm}
            r.al:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B2 : begin                       {mov dl,imm}
            r.dl:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B3 : begin                       {mov bl,imm}
            r.bl:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B4 : begin                       {mov ah,imm}
            r.ah:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B6 : begin                       {mov dh,imm}
            r.dh:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B7 : begin                       {mov bh,imm}
            r.bh:=buf^[ip+1];
            ip:=ip+2;
          end;
    $B8 : begin                       {mov ax,imm}
            r.ax:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $B9 : begin                       {mov cx,imm}
            r.cx:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $BA : begin                       {mov dx,imm}
            r.dx:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $BB : begin                       {mov bx,imm}
            r.bx:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $BD : begin                       {mov bp,imm}
            r.bp:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $BE : begin                       {mov si,imm}
            r.si:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $BF : begin                       {mov di,imm}
            r.di:=buf^[ip+1]+256*buf^[ip+2];
            ip:=ip+3;
          end;
    $E2 : begin                       {loop XXX}
            r.cx:=r.cx-1;
            if r.cx<>0 then
              begin
                if buf^[ip+1]<=$80 then ip:=ip+2+buf^[ip+1]
                else ip:=ip+2+buf^[ip+1]-$100;
              end
            else ip:=ip+2;
          end;
    $F5 : begin                       {cmc}
            r.flags:=r.flags xor 2;
            ip:=ip+1;
          end;
    $F8 : begin                       {clc}
            r.flags:=r.flags and $FFFD;
            ip:=ip+1;
          end;
    $F9 : begin                       {stc}
            r.flags:=r.flags or 2;
            ip:=ip+1;
          end;
    else ai:=false;
    end;
  analyze_instruction:=ai;
end;

procedure analyze(fn:string);
var
  comfile          :file;
  size,j           :word;
  cnt              :word;
  legal            :boolean;
  modcnt           :word;
begin
  assign(comfile,fn);
  reset(comfile,1);
  blockread(comfile,buf^,$1000,size);
  legal:=true;
  cnt:=150;                             {Max # of instructions to simulate}
  ip:=$100;
  sp:=$FFFE;
  fillchar(r,sizeof(r),#0);
  fillchar(modified^,sizeof(modified^),#0);
  repeat
    legal:=analyze_instruction;
    cnt:=cnt-1;
  until (not legal) or (cnt=0);
  if legal then
    begin
      writeln(out_file,fn,' may be infected with a VME virus!');
      infcnt:=infcnt+1;
    end
  else if DEBUG then writeln(out_file,fn,' IP=',ip,' ',buf^[ip],' ',buf^[ip+1]);
  modcnt:=0;
  for j:=$100 to $FFFF do if modified^[j]=$11 then modcnt:=modcnt+1;
  if modcnt>0 then writeln(out_file,'Self modifying code present: ',modcnt);
  close(comfile);
end;

begin
  new(buf);
  new(modified);
  assign(out_file,'FINDVME.OUT');
  rewrite(out_file);
  writeln('Find-VME Version 1.0 (C) 1995 American Eagle Publications Inc.');
  writeln(out_file,'Find-VME Version 1.0 (C) 1995 American Eagle Publications Inc.');
  FindFirst('*.COM',AnyFile,SR);
  infcnt:=0;
  while DosError=0 do
    begin
      write(sr.name,#13);
      analyze(SR.Name);
      FindNext(SR);
    end;
  writeln(out_file,'Total suspected infections: ',infcnt);
  writeln('Total suspected infections: ',infcnt);
  close(out_file);
end.
