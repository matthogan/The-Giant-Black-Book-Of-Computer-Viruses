program gen_10000; {Generate batch file to create 10000 hosts and infect them}

var
  s,n:string;
  bf:text;
  j:word;

begin
  assign(bf,'gen10000.bat');
  rewrite(bf);
  writeln(bf,'md 10000');
  writeln(bf,'cd 10000');
  for j:=1 to 10000 do
    begin
      str(j,n);
      while length(n)<5 do n:='0'+n;
      writeln(bf,'copy ..\test.com ',n,'.com');
    end;
  writeln(bf,'md inf');
  writeln(bf,'..\manyhoop');
  for j:=2 to 10000 do
    begin
      str(j-1,n);
      while length(n)<5 do n:='0'+n;
      writeln(bf,n);
      writeln(bf,'copy ',n,'.com inf');
      writeln(bf,'del ',n,'.com');
    end;
  writeln(bf,'copy 10000.com inf');
  writeln(bf,'del 10000.com');
  close(bf);
end.