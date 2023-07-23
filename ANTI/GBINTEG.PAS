program giant_black_book_integ_checker;

uses dos,crt;

const
  MAX_ENTRIES      =2000;               {Max number of files this can handle}
type
  LogRec_Type      =record
    Name           :string[80];
    Time           :longint;
    Size           :longint;
    Checksum       :longint;
    Found          :boolean;
    end;
var
  LstFile          :text;                                      {listing file}
  LogFile          :file of LogRec_Type;                           {log file}
  LogEntries       :longint;                          {# entries in log file}
  Log              :array[1..MAX_ENTRIES] of ^LogRec_Type;      {log entries}
  j                :word;
  SearchDir        :string;                              {directory to check}
  CurrDir          :string;                   {directory program called from}

{This routine just makes a string upper case}
function UpString(s:string):string;
var
  i                :word;
begin
  for i:=1 to length(s) do s[j]:=UpCase(s[j]);
  UpString:=s;
end;

{This function searches the log in memory for a match on the file name.
 To use it, pass the name of the file in fname. If a match is found, the
 function returns true, and FN is set to the index in Log[] which is the
 proper record. If no match is found, the function returns false.}
function SearchLog(fname:string;var FN:word):boolean;
var
  j                :word;
begin
  fname:=UpString(fname);
  if LogEntries>0 then for j:=1 to LogEntries do
    begin
      if fname=Log[j]^.Name then
        begin
          SearchLog:=true;
          FN:=j;
          exit;
        end;
    end;
  SearchLog:=false;
end;

{This function calcuates the checksum of the file whose name is passed to
 it. The return value is the checksum.}
function Get_Checksum(FName:string):longint;
var
  F                :file;
  cs               :longint;
  j,x              :integer;
  buf              :array[0..511] of byte;
begin
  cs:=0;
  assign(F,FName);
  reset(F,1);
  repeat
    blockread(F,buf,512,x);
    if x>0 then for j:=0 to x-1 do cs:=cs+buf[j];
  until eof(F);
  close(F);
  Get_Checksum:=cs;
end;

{This routine checks the integrity of one complete subdirectory and all its
 subdirectories. The directory name (with a final \) is passed to it. It is
 called recursively. This checks all COM and EXE files.}
procedure check_dir(dir:string);
var
  SR               :SearchRec;                  {Record used by FindFirst}
  Checksum         :Longint;                    {temporary variables}
  FN               :word;
  cmd              :char;
begin
  dir:=UpString(dir);
  FindFirst(dir+'*.com',AnyFile,SR);            {first check COM files}
  while DosError=0 do
    begin
      if SearchLog(dir+SR.Name,FN) then
        begin
          Checksum:=Get_Checksum(dir+SR.Name);
          if (Log[FN]^.Time<>SR.Time) or (Log[FN]^.Size<>SR.Size)
           or (Log[FN]^.Checksum<>Checksum) then
            begin
              write(dir+SR.Name,' has changed!',#7,#7,#7,' Do you want to update its record? ');
              write(LstFile,dir+SR.Name,' has changed! Do you want to update its record? ');
              repeat cmd:=UpCase(ReadKey) until cmd in ['Y','N'];
              if cmd='Y' then
                begin
                  Log[FN]^.Time:=SR.Time;
                  Log[FN]^.Size:=SR.Size;
                  Log[FN]^.Checksum:=Checksum;
                  Log[FN]^.Found:=True;
                end;
              writeln(cmd);
              writeln(LstFile,cmd);
            end
          else
            begin
              writeln(dir+SR.Name,' validated.');
              Log[FN]^.Found:=True;
            end;
        end
      else
        begin
          if LogEntries<MAX_ENTRIES then
            begin
              writeln('New file: ',dir+SR.Name,'. ADDED to log.');
              writeln(LstFile,'New file: ',dir+SR.Name,'. ADDED to log.');
              LogEntries:=LogEntries+1;
              new(Log[LogEntries]);
              Log[LogEntries]^.Name:=dir+SR.Name;
              Log[LogEntries]^.Time:=SR.Time;
              Log[LogEntries]^.Size:=SR.Size;
              Log[LogEntries]^.Checksum:=Get_Checksum(dir+SR.Name);
              Log[LogEntries]^.Found:=True;
            end
          else
            begin
              writeln('TOO MANY ENTRIES. COULD NOT ADD ',dir+SR.Name,'.');
              writeln(LstFile,'TOO MANY ENTRIES. COULD NOT ADD ',dir+SR.Name,'.');
            end;
        end;
      FindNext(SR);
    end;

  FindFirst(dir+'*.exe',AnyFile,SR);            {now check EXE files}
  while DosError=0 do
    begin
      if SearchLog(dir+SR.Name,FN) then
        begin
          Checksum:=Get_Checksum(dir+SR.Name);
          if (Log[FN]^.Time<>SR.Time) or (Log[FN]^.Size<>SR.Size)
           or (Log[FN]^.Checksum<>Checksum) then
            begin
              write(dir+SR.Name,' has changed!',#7,#7,#7,' Do you want to update its record? ');
              write(LstFile,dir+SR.Name,' has changed! Do you want to update its record? ');
              repeat cmd:=UpCase(ReadKey) until cmd in ['Y','N'];
              if cmd='Y' then
                begin
                  Log[FN]^.Time:=SR.Time;
                  Log[FN]^.Size:=SR.Size;
                  Log[FN]^.Checksum:=Checksum;
                  Log[FN]^.Found:=True;
                end;
              writeln(cmd);
              writeln(LstFile,cmd);
            end
          else
            begin
              writeln(dir+SR.Name,' validated.');
              Log[FN]^.Found:=true;
            end;
        end
      else
        begin
          if LogEntries<MAX_ENTRIES then
            begin
              writeln('New file: ',dir+SR.Name,'. ADDED to log.');
              writeln(LstFile,'New file: ',dir+SR.Name,'. ADDED to log.');
              LogEntries:=LogEntries+1;
              new(Log[LogEntries]);
              Log[LogEntries]^.Name:=dir+SR.Name;
              Log[LogEntries]^.Time:=SR.Time;
              Log[LogEntries]^.Size:=SR.Size;
              Log[LogEntries]^.Checksum:=Get_Checksum(dir+SR.Name);
              Log[LogEntries]^.Found:=True;
            end
          else
            begin
              writeln('TOO MANY ENTRIES. COULD NOT ADD ',dir+SR.Name,'.');
              writeln(LstFile,'TOO MANY ENTRIES. COULD NOT ADD ',dir+SR.Name,'.');
            end;
        end;
      FindNext(SR);
    end;

  FindFirst('*.*',Directory,SR);            {finally, check subdirectories}
  while DosError=0 do
    begin
      if (SR.Attr and Directory <> 0) and (SR.Name[1]<>'.') then
        begin
          ChDir(SR.Name);
          check_dir(dir+SR.Name+'\');
          ChDir('..');
        end;
      FindNext(SR);
    end;
end;

{This procedure checks the master boot sector and the boot sector's integrity}
procedure check_boot;
var
  FN,j             :word;
  cs               :longint;
  buf              :array[0..511] of byte;
  r                :registers;
  cmd              :char;
  currdrv          :byte;
begin
  r.ah:=$19;
  intr($21,r);
  currdrv:=r.al;
  if currdrv>=2 then currdrv:=currdrv+$80-2;

  if currdrv=$80 then
    begin
      r.ax:=$201;                   {read boot sector/master boot sector}
      r.bx:=ofs(buf);
      r.es:=sseg;
      r.cx:=1;
      r.dx:=$80;
      intr($13,r);
      r.ax:=$201;
      intr($13,r);
      cs:=0;
      for j:=0 to 511 do cs:=cs+buf[j];

      if SearchLog('**MBS',FN) then
        begin
          Log[FN]^.Found:=True;
          if Log[FN]^.Checksum=cs then writeln('Master Boot Sector verified.')
          else
            begin
              write('Master Boot Sector has changed! Update log file? ');
              write(LstFile,'Master Boot Sector has changed! Update log file? ');
              repeat cmd:=UpCase(ReadKey) until cmd in ['Y','N'];
              if cmd='Y' then Log[FN]^.Checksum:=cs;
              writeln(cmd);
              writeln(LstFile,cmd);
            end;
        end
      else
        begin
          writeln('Master Boot Sector data ADDED to log.');
          writeln(LstFile,'Master Boot Sector data ADDED to log.');
          LogEntries:=LogEntries+1;
          new(Log[LogEntries]);
          Log[LogEntries]^.Name:='**MBS';
          Log[LogEntries]^.Checksum:=cs;
          Log[LogEntries]^.Found:=True;
        end;
      j:=$1BE;
      while (j<$1FE) and (buf[j]<>$80) do j:=j+$10;
      if buf[j]=$80 then
        begin
          r.dx:=buf[j]+256*buf[j+1];
          r.cx:=buf[j+2]+256*buf[j+3];
        end
      else exit;
    end
  else
    begin
      r.cx:=1;
      r.dx:=currdrv;
    end;
  if CurrDrv<$81 then
    begin
      r.ax:=$201;
      r.bx:=ofs(buf);
      r.es:=sseg;
      intr($13,r);
      r.ax:=$201;
      intr($13,r);
      cs:=0;
      for j:=0 to 511 do cs:=cs+buf[j];

      if SearchLog('**BOOT',FN) then
        begin
          Log[FN]^.Found:=True;
          if Log[FN]^.Checksum=cs then writeln('Boot Sector verified.')
          else
            begin
              write('Boot Sector has changed! Update log file? ');
              write(LstFile,'Boot Sector has changed! Update log file? ');
              repeat cmd:=UpCase(ReadKey) until cmd in ['Y','N'];
              if cmd='Y' then Log[FN]^.Checksum:=cs;
              writeln(cmd);
              writeln(LstFile,cmd);
            end;
        end
      else
        begin
          writeln('Boot Sector data ADDED to log.');
          writeln(LstFile,'Boot Sector data ADDED to log.');
          LogEntries:=LogEntries+1;
          new(Log[LogEntries]);
          Log[LogEntries]^.Name:='**BOOT';
          Log[LogEntries]^.Checksum:=cs;
          Log[LogEntries]^.Found:=True;
        end;
    end;
end;

{This procedure removes files from the log that have been deleted on the
 system. Of course, it allows the user to decide whether to remove them or
 not.}
procedure PurgeFile(j:word);
var
  cmd              :char;
  i                :word;
begin
  write(Log[j]^.Name,' was not found. Delete from log file? ',#7,#7,#7);
  write(LstFile,Log[j]^.Name,' was not found. Delete from log file? ');
  repeat cmd:=UpCase(ReadKey) until cmd in ['Y','N'];
  if cmd='Y' then
    begin
      for i:=j to LogEntries-1 do
        Log[i]^:=Log[i+1]^;
      LogEntries:=LogEntries-1;
    end;
  writeln(cmd);
  writeln(LstFile,cmd);
end;

begin
  writeln('GB-INTEG Ver 1.00, (C) 1995 American Eagle Publications, Inc.');

  assign(LogFile,'\GBINTEG.DAT');             {Load the log file into memory}
{$I-}
  reset(LogFile);
{$I+}
  if IOResult<>0 then
    LogEntries:=0
  else
    begin
      for LogEntries:=1 to FileSize(LogFile) do
        begin
          new(Log[LogEntries]);
          read(LogFile,Log[LogEntries]^);
        end;
      close(LogFile);
    end;

  assign(LstFile,'GBINTEG.LST');                    {Create the listing file}
  rewrite(LstFile);

  {Take care of directory maintenance}
  if ParamCount=1 then SearchDir:=ParamStr(1) else SearchDir:='\';
  GetDir(0,CurrDir);


  ChDir(SearchDir);
  if SearchDir[length(SearchDir)]<>'\' then SearchDir:=SearchDir+'\';
  check_boot;                                        {check the boot sectors}
  check_dir(SearchDir);                                     {check integrity}

  j:=1;
  while j<=LogEntries do                               {handle missing files}
    begin
      if Log[j]^.Found then j:=j+1
      else PurgeFile(j);
    end;

  ChDir(CurrDir);
  rewrite(LogFile);                                         {update log file}
  for j:=1 to LogEntries do
    begin
      Log[j]^.Found:=False;        {reset these flags before writing to disk}
      write(LogFile,Log[j]^);
    end;
  close(LogFile);

  writeln(LogEntries,' files in current log file.');
  writeln(LstFile,LogEntries,' files in current log file.');
  close(LstFile);
end.
