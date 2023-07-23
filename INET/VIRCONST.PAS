program vir_constant; {Builds constants for simple Java viruses}

var
  fin:file of byte;
  fout:text;
  s:string;
  b,i:byte;

begin
  assign(fin,ParamStr(1)+'.SRC'); reset(fin);
  assign(fout,ParamStr(1)+'.CON'); rewrite(fout);
  i:=0;
  repeat
    read(fin,b);
    if b<>26 then
      begin
        str(b,s);
        if not eof(fin) then s:=s+',';
        write(fout,s);
        i:=i+1;
        if i=20 then begin writeln(fout); i:=0; end;
      end;
  until (eof(fin)) or (b=26);
  close(fin);
  close(fout);
end.

