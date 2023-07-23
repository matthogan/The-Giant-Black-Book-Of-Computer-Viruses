{This program can be used to clean up the RETALIATOR virus and see what it
has written to Cyl 0, Hd 0, Sec 2 on disk. It allows you to clean that
sector up if you so desire}

program secread;
uses dos,crt;

var
  r:registers;
  buf:array[0..511] of byte;
  c:char;
  j:word;

begin
  r.ax:=$0201;                         {Read Cyl 0, Hd 0, Sec 2}
  r.cx:=2;
  r.dx:=$80;
  r.bx:=ofs(buf);
  r.es:=seg(buf);
  intr($13,r);
  write(buf[0],' ',buf[1],':');        {display it}
  j:=2;
  while buf[j]<>0 do
    begin
      write(char(buf[j]));
      j:=j+1;
    end;
  writeln;
  write('Do you want to erase the sector? ');
  if UpCase(ReadKey)='Y' then
    begin
      fillchar(buf,512,#0);            {erase it}
      r.ax:=$0301;
      r.cx:=2;
      r.dx:=$80;
      r.bx:=ofs(buf);
      r.es:=seg(buf);
      intr($13,r);
    end;
end.