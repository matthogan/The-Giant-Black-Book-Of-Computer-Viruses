program nextgen; {Generate batch file to create 10000 hosts and infect them}

uses crt;

var
  s,n,m:string;
  bf:text;
  j:word;
  FileCnt:word;

begin
  Randomize;
  if ParamCount=1 then
    begin
      val(Paramstr(1),FileCnt,j);
    end
  else
    begin
      writeln('Please specify previous generation file count.');
      halt(1);
    end;
  assign(bf,'next.bat');
  rewrite(bf);
  writeln(bf,'cd 1000');
  for j:=1 to 2000 do
    begin
      str(j,n);
      while length(n)<5 do n:='0'+n;
      writeln(bf,'copy ..\test.com ',n,'.com');
    end;
  for j:=2 to 2001 do
    begin
      str(j-1,n);
      str(random(FileCnt)+1,m);
      while length(n)<5 do n:='0'+n;
      while length(m)<8 do m:='0'+m;
      writeln(bf,'prevgen\',m);
      writeln(bf,'copy ',n,'.com inf');
      writeln(bf,'del ',n,'.com');
    end;
  writeln(bf,'copy 02000.com inf');
  writeln(bf,'del 02000.com');
  close(bf);
end.