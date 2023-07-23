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
  IBR_Type         =record
    VirtualAddress :longint;
    Size           :longint;
    end;
  Image_Import_Desc=record
    Characteristics:longint;
    TimeDate       :longint;
    Forwarder      :longint;
    Name           :longint;
    IIBN           :longint;
    end;
var
  fin              :file;
  buf              :array[0..511] of byte;
  pe_header        :pe_header_type;
  IBR              :IBR_Type;
  new_header       :word;
  j,k,w            :word;
  SecTable         :array[1..50] of SecTableType;
  IID              :Image_Import_Desc;
  fp,d             :longint;

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

  writeln('Sections: ',pe_header.FileHdr.Sections);
  writeln('Code base: ',pe_header.OptHdr.CodeBase);
  writeln('Entry point: ',pe_header.OptHdr.EntryPt);
  writeln('Data base: ',pe_header.OptHdr.DataBase);
  writeln('Image base: ',pe_header.OptHdr.ImageBase);
  writeln('Size of code: ',pe_header.OptHdr.SizeOfCode);
  writeln;

  for j:=1 to pe_header.FileHdr.Sections do
    begin
      Blockread(fin,SecTable[j],Sizeof(SecTable[j]));
      if (SecTable[j].Name[1]='i') and (SecTable[j].Name[2]='d') then
        begin
          seek(fin,SecTable[j].PtrRawData);
          fp:=FilePos(fin);
          repeat
            seek(fin,fp);
            Blockread(fin,IID,SizeOf(IID));
            fp:=FilePos(fin);
            if IID.Characteristics<>0 then
              begin
                writeln('Characteristics = ',IID.Characteristics);
                write('Name            = ',IID.Name,'  (');
                seek(fin,SecTable[j].PtrRawData+IID.Name-SecTable[j].VirtualAddr);
                Blockread(fin,buf,20);
                k:=0;
                while buf[k]<>0 do begin write(char(buf[k])); k:=k+1; end;
                writeln(')');
                writeln('Forwarder       = ',IID.Forwarder);
                writeln('IIBN@           = ',IID.IIBN);
                seek(fin,SecTable[j].PtrRawData+IID.Characteristics-SecTable[j].VirtualAddr);
                repeat
                  blockread(fin,d,4);
                  writeln('>',d);
                until d=0;
                seek(fin,SecTable[j].PtrRawData+IID.IIBN-SecTable[j].VirtualAddr);
                repeat
                  blockread(fin,d,4);
                  writeln('#',d);
                until d=0;
              end;
            writeln;
          until IID.Characteristics=0;
          halt(0);
        end;
    end;

  close(fin);
end.
