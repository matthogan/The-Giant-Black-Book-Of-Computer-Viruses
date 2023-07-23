program windows_95_header_display;

type
  DataDirType      =record
    location       :longint;
    size           :longint;
    end;
  Image_file_header=record  {20 bytes}
    Machine        :word;
    Sections       :word;
    TimeStamp      :longint;
    SymTable       :longint;
    Symbols        :longint;
    SizeOptHdr     :word;
    Characteristics:word;
    end;
  Image_optional_header=record
    Magic          :word;
    LinkVer        :array[0..1] of byte;
    SizeOfCode     :longint;
    SizeInitData   :longint;
    SizeUninData   :longint;
    EntryPt        :longint;
    CodeBase       :longint;
    DataBase       :longint;
    ImageBase      :longint;
    SectAlign      :longint;
    FileAlign      :longint;
    OpSysVer       :array[0..1] of word;
    ImageVer       :array[0..1] of word;
    SubsysVer      :array[0..1] of word;
    Reserved1      :longint;
    ImgSize        :longint;
    HdrSize        :longint;
    Checksum       :longint;
    Subsystem      :word;
    DllChar        :word;
    StackReserve   :longint;
    StackCommit    :longint;
    HeapReserve    :longint;
    HeapCommit     :longint;
    LoaderFlags    :longint;
    NumRvaSizes    :longint;
    ImgDataDir     :array[0..15] of DataDirType;
    end;
  pe_header_type   =record
    signature      :array[0..3] of char;
    FileHdr        :Image_file_header;
    OptHdr         :Image_optional_header;
    end;
  SecTableType     =record
    Name           :array[0..7] of char;
    VirtualSize    :longint;
    VirtualAddr    :longint;
    SizeRawData    :longint;
    PtrRawData     :longint;
    PtrRelocs      :longint;
    PtrLineNos     :longint;
    NumRelocs      :word;
    NumLineNos     :word;
    Flags          :longint;
    end;

var
  fin              :file;
  buf              :array[0..511] of byte;
  pe_header        :pe_header_type;
  new_header       :word;
  j,k              :word;
  SecTable         :array[1..50] of SecTableType;

procedure error(s:string);
begin
  writeln(s);
  halt(1);
end;

begin
  assign(fin,ParamStr(1));
  reset(fin,1);
  blockread(fin,buf,$3F);
  if (buf[0]<>ord('M')) or (buf[1]<>ord('Z')) then
    error('This file is not an EXE file!');
  if buf[$18]<$40 then
    error('This file is a DOS EXE file!');
  new_header:=buf[$3D];
  writeln(new_header);
  new_header:=buf[$3C]+256*new_header;
  writeln(new_header);
  seek(fin,new_header);
  blockread(fin,pe_header,sizeof(pe_header));
  if (pe_header.signature[0]<>'P') or (pe_header.signature[1]<>'E') then
    begin
      write(pe_header.signature[0],pe_header.signature[1]);
      error('This is not a Portable Executable file!');
    end;

  writeln('Sections:      ',pe_header.FileHdr.Sections);
  writeln('Code base:     ',pe_header.OptHdr.CodeBase);
  writeln('Entry point:   ',pe_header.OptHdr.EntryPt);
  writeln('Data base:     ',pe_header.OptHdr.DataBase);
  writeln('Image base:    ',pe_header.OptHdr.ImageBase);
  writeln('Size of code:  ',pe_header.OptHdr.SizeOfCode);
  writeln('Size of image: ',pe_header.OptHdr.ImgSize);
  writeln('Stack reserve: ',pe_header.OptHdr.StackReserve);
  writeln('Stack commit:  ',pe_header.OptHdr.StackCommit);
  writeln;

  for j:=1 to pe_header.FileHdr.Sections do
    begin
      Blockread(fin,SecTable[j],Sizeof(SecTable[j]));
{      if SecTable[j].Name[1]in ['t','O'] then   {single out text section}
        begin
          write('Section ',j,': '); for k:=0 to 7 do write(SecTable[j].Name[k]);
          writeln;
          writeln('Virtual size: ',SecTable[j].VirtualSize:10,' Raw data size: ',SecTable[j].SizeRawData:10);
          writeln('Raw data offset: ',SecTable[j].PtrRawData:10,' Virtual address: ',SecTable[j].VirtualAddr);
          write('Characteristics: ');
          if SecTable[j].Flags and $20 = $20 then write('CODE ');
          if SecTable[j].Flags and $40 = $40 then write('INIT_DATA ');
          if SecTable[j].Flags and $80 = $80 then write('UNINIT_DATA ');
          if SecTable[j].Flags and $2000000 = $2000000 then write('DISCARDABLE ');
          if SecTable[j].Flags and $20000000 = $20000000 then write('EXECUTABLE ');
          if SecTable[j].Flags and $40000000 = $40000000 then write('READABLE ');
          if SecTable[j].Flags and $80000000 = $80000000 then write('WRITEABLE ');
          writeln;
          writeln;
        end;
    end;

  close(fin);
end.
