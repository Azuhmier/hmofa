//#!gcc %.c -o %.out_
#include <stdio.h>
#include <stdlib.h>

int main()
{
     {
         FILE *fp;
         char buff[255];

         fp = fopen("../test/masterbin.txt", "r");
         fscanf(fp, "%s", buff);
         printf("1 : %s\n", buff );

         fgets(buff, 255, (FILE*)fp);
         printf("2: %s\n", buff );
         fgets(buff, 255, (FILE*)fp);
         printf("3: %s\n", buff );
         fclose(fp);
     }
     {
         FILE *f = fopen("../test/masterbin.txt", "rb");
         fseek(f, 0, SEEK_END);
         long fsize = ftell(f);
         printf("\nfsize: %ld\n", fsize);

         fseek(f, 0, SEEK_SET);  /* same as rewind(f); */
         char *string = malloc(fsize);
         fread(string, 1, fsize, f);
         fclose(f);
         int max = (int)sizeof string;
         printf("MAX: %d\n", max);
         int i; for (i=0; i<=fsize; i++) printf("%c", string[i]);
     }


   return 0;
}



