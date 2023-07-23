program codevir;

const
  RAND_INIT        =10237989;                   {Must be same as BOMB.PAS}

var
  fin              :file of byte;
  input_file       :string;
  output_file      :string;
  fout             :text;
  i,header_size    :word;
  b                :byte;
  s,n              :string;

begin
  write('Input file name : '); readln(input_file);
  write('Output file name: '); readln(output_file);
  write('Header size in bytes: '); readln(header_size);
  RandSeed:=RAND_INIT;
  assign(fin,input_file); reset(fin); seek(fin,header_size);
  assign(fout,output_file); rewrite(fout);
  i:=0;
  s:='  (';
  repeat
    read(fin,b);
    b:=b xor Random(256);
    str(b,n);
    if i<>0 then s:=s+',';
    s:=s+n;
    i:=i+1;
    if length(s)>70 then
      begin
        if not eof(fin) then s:=s+',' else s:=s+');';
        writeln(fout,s);
        s:='   ';
        i:=0;
      end;
  until eof(fin);
  if i>0 then
    begin
      s:=s+');';
      writeln(fout,s);
    end;
  close(fout);
  close(fin);
end.
