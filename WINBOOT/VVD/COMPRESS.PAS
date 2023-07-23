 program compress_file;

var
  fin,fout:file of byte;
  b,l,wh,wl:byte;
  i,j:word;
  ff,first:boolean;
  repchr:byte;
  spectrum:array[0..256] of boolean;
begin
  repchr:=17;
  for i:=0 to 256 do spectrum[i]:=false;
  assign(fin,'vvd.386');
  reset(fin);
  assign(fout,'vvd.333');
  rewrite(fout);
  i:=0;
  l:=0;
  first:=true;
  ff:=true;
  repeat
    read(fin,b);
    spectrum[b]:=true;
    if (not first) and (b=l) then  {in repeat string}
      begin
        i:=i+1;
      end
    else
      begin
        if (not first) then        {end of repeat string}
          begin
            if i>3 then
              begin
                i:=i+1;
                wl:=i and 255;
                wh:=i div 256;
                write(fout,repchr,wl,wh,l);
                first:=true;
                i:=0;
                l:=b;
              end
            else
              begin
                for j:=1 to i+1 do write(fout,l);
                first:=true;
                i:=0;
                l:=b;
              end;
          end
        else                       {b<>l: ordinary non-repeating characters}
          begin
            if b<>l then
              begin
                if not ff then write(fout,l);
                l:=b;
                ff:=false;
              end
            else
              begin
                first:=false;
                i:=i+1;
              end;
          end;
      end;
  until eof(fin);
  if first then write(fout,l)
  else
    begin
      i:=i+1;
      wl:=i and 255;
      wh:=i div 256;
      write(fout,repchr,wl,wh,l);
    end;
  close(fin);
  close(fout);
  if spectrum[repchr]=true then
    begin
      i:=0;
      while spectrum[i] do i:=i+1;
      writeln(repchr,' in use. Try ',i,' instead.');
    end;
end.
