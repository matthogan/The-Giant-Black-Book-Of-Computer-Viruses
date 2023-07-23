program encode;
{This makes an encoded pascal constant out of a file of text}

var
  fin              :file of byte;
  fout             :text;
  s                :string;
  b                :byte;
  bcnt             :byte;

function ef:boolean;                                   {End of file function}
begin
  ef:=eof(fin) or (b=$1A);
end;

begin
  if ParamCount<>2 then exit;            {Expects input and output file name}
  assign(fin,ParamStr(1)); reset(fin);              {Open input file to read}
  assign(fout,ParamStr(2)); rewrite(fout);        {Open output file to write}
  writeln(fout,'const');                               {"Constant" statement}
  write(fout,' tconst:array[1..',filesize(fin),'] of byte=(');
  bcnt:=11;                                      {Define the constant tconst}
  repeat
    read(fin,b);                                {Read each byte individually}
    bcnt:=bcnt+1;
    if b<>$1A then                                          {b <> eof marker}
      begin
        write(fout,(b shl 1) xor $AA);                      {Encode the byte}
        if (not ef) then write(fout,',');
        if (bcnt=18) and (not ef) then            {Put 16 bytes on each line}
          begin
            writeln(fout);
            write(fout,'    ');
            bcnt:=0;
          end;
      end
    else write(fout,($20 shl 1) xor $AA);
  until ef;                                       {Go to the end of the file}
  writeln(fout,');');
  close(fout);                                            {Close up and exit}
  close(fin);
end.
