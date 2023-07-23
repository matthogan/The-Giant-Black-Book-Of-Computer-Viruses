{This simple program calcuates the frequency of each byte occuring in
a file specified on the command line, and reports the values in freq.rpt}

program freq;

var
  frequency        :array[0..255] of longint;
  fin              :file of byte;
  b                :byte;
  rpt              :text;
  j                :word;
  sz               :real;

begin
  fillchar(frequency,sizeof(frequency),#0);
  assign(fin,ParamStr(1));
  reset(fin);
  sz:=FileSize(fin);
  repeat
    read(fin,b);
    frequency[b]:=frequency[b]+1;
  until eof(fin);
  close(fin);
  assign(rpt,'freq.rpt');
  rewrite(rpt);
  for j:=0 to 255 do writeln(rpt,j,',',frequency[j]/sz);
  close(rpt);
end.