program build_1000;

var
  j:integer;
  fout:text;
begin
  assign(fout,'1000.bat');
  rewrite(fout);
  for j:=1 to 1000 do
    begin
      writeln(fout,'copy ..\host1.com');
      writeln(fout,'copy ..\genmini.com');
      writeln(fout,'genmini');
      writeln(fout,'copy ..\host1.com host2.com');
      writeln(fout,'host1');
      writeln(fout,'copy host2.com samples\',j,'.COM');
    end;
  close(fout);
end.