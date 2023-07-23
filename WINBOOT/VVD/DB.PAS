program define_byte;

var
  fin:file of byte;
  fout:text;
  s,n:string;
  b:byte;
  i,j:integer;

begin
  if ParamCount<>2 then
    begin
      writeln('Call this program as "DB FILEIN FILEOUT"');
      halt(1);
    end;
  assign(fin,ParamStr(1));
  reset(fin);
  assign(fout,ParamStr(2));
  rewrite(fout);
  j:=0;
  i:=0;
  repeat
    i:=i+1;
    read(fin,b);
    if j=0 then
      begin
        s:='        DB      ';
        str(b,n);
        s:=s+n;
      end
    else
      begin
        str(b,n);
        s:=s+','+n
      end;
    j:=j+1;
    if (j=32) or (length(s)>77) then
      begin
        writeln(fout,s);
        j:=0;
      end;
  until eof(fin);
  if j<>0 then writeln(fout,s);
  writeln(fout);
  writeln(fout,'FSIZE   EQU     ',i);
  close(fout);
  close(fin);
end.