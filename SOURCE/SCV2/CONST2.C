// This program adds the a784 constant to the virus.h source file, and
// names the file with the constant as virus.hhh

#include <stdio.h>
#include <fcntl.h>

int ccount;
FILE *f1,*f2,*ft;

void put_constant(FILE *f, char c)
{
  char n[5],u[26];
  int j;

  itoa((int)c,n,10);
  j=0;
  while (n[j]) fwrite(&n[j++],1,1,f);

  ccount++;
  if (ccount>20)
    {
      strcpy(&u[0],",\n                      ");
      fwrite(&u[0],strlen(u),1,f);
      ccount=0;
    }
  else
    {
      u[0]=',';
      fwrite(&u[0],1,1,f);
    }
}

/******************************************************************************/
void main()
{
  char l[255],p[255];
  int i,j;

  ccount=0;
  f1=fopen("virus2.hs","r");
  ft=fopen("v784.h","w");
  do
    {
      j=0; l[j]=0;
      while ((!feof(f1)) && ((j==0)||(l[j-1]!=0x0A)))
        {fread(&l[j],1,1,f1); j++;}
      l[j]=0;
      if (strcmp(l,"static char a784[]={0};\n")==0)
         {
           fwrite(&l[0],20,1,ft);
           f2=fopen("virus2.hs","r");
           do
             {
               j=0; p[j]=0;
               while ((!feof(f2)) && ((j==0)||(p[j-1]!=0x0A)))
                 {fread(&p[j],1,1,f2); j++;}
               p[j]=0;
               if (strcmp(p,"static char a784[]={0};\n")==0)
                 {
                   for (i=0;i<20;i++) put_constant(ft,p[i]);
                   p[0]='0'; p[1]=',';
                   fwrite(&p[0],2,1,ft);
                   ccount++;
                   for (i=23;p[i]!=0;i++) put_constant(ft,p[i]);
                 }
               else
                 {
                   for (i=0;i<j;i++) put_constant(ft,p[i]);
                 }
             }
           while (!feof(f2));
           strcpy(&p,"0};\n");
           fwrite(&p[0],strlen(p),1,ft);
         }
      else for (i=0;i<j;i++) fwrite(&l[i],1,1,ft);
    }
  while (!feof(f1));
  fclose(f1);
  fclose(f2);
  fclose(ft);
}

