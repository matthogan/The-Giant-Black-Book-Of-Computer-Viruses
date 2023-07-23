program vprotect;  {Protects KOH-based systems from virus damage}

uses crt,dos;

const
  copyrt           :string='(C) 1994 American Eagle Publications, Inc. All rights reserved.';
  VIR_SIZE         =9;                        {VIR_SIZE variable from KOH.ASM}

var
  buf              :array[0..20000] of byte;
  f                :file;
  bsdx,bscx        :word;

function UpString(s:string):string;
var j:word;
begin
  for j:=1 to length(s) do s[j]:=upcase(s[j]);
  UpString:=s;
end;

procedure read_hd(cx,dx,count:word);
var r:registers;
begin
  r.ah:=2;
  r.al:=count;
  r.bx:=ofs(buf);
  r.es:=DSeg;
  r.cx:=cx;
  r.dx:=dx;
  intr($13,r);
end;

function get_boot_sec:boolean;
var k:word;
begin
  get_boot_sec:=false;
  k:=$1BE;
  while k<$1FE do
    begin
      if buf[k]=$80 then
        begin
          bsdx:=buf[k+1]*256+buf[k];
          bscx:=buf[k+3]*256+buf[k+2];
          get_boot_sec:=true;
          exit;
        end;
      k:=k+$10;
    end;

end;

procedure write_hd(cx,dx,count:word);
var r:registers;
begin
  r.ah:=3;
  r.al:=count;
  r.bx:=ofs(buf);
  r.es:=DSeg;
  r.cx:=cx;
  r.dx:=dx;
  intr($13,r);
end;

begin
  writeln('VPROTECT Version 1.01 (C) 1994 American Eagle Publications Inc.');
  if not (((ParamCount=1) and (UpString(ParamStr(1))='/WRITE'))
          or (ParamCount=0)) then
    begin
      writeln('Call this program as "VPROTECT [/WRITE]"!');
      halt(1);
    end;
  if (ParamCount=1) and (UpString(ParamStr(1))='/WRITE') then
    begin
      write('Are you sure you want to update the system areas? ');
      if UpCase(ReadKey)='Y' then
        begin
          assign(f,'vprotect.dat');
          reset(f,512);
          blockread(f,buf,VIR_SIZE+3);
          write_hd(1,$80,VIR_SIZE+3);
          if get_boot_sec then
            begin
              blockread(f,buf,1);
              write_hd(bscx,bsdx,1);
            end;
          close(f);
        end;
    end
  else if ParamCount=0 then
    begin
      write('Create new VPROTECT.DAT file? ');
      if UpCase(ReadKey)='Y' then
        begin
          assign(f,'vprotect.dat');
          rewrite(f,512);
          read_hd(1,$80,VIR_SIZE+3);          {Read main body of KOH}
          blockwrite(f,buf,VIR_SIZE+3);
          if get_boot_sec then
            begin
              read_hd(bscx,bsdx,1);
              blockwrite(f,buf,1);
            end;
          close(f);
        end;
    end;
end.