//#!gcc %.c -o %.out_
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <float.h>

int main(int argc, char** argv)
{

   // Enumeration
   enum Days_of_week {Sun, Mon, Tue, Wed = 4, Thur, Fri, Sat};
   enum Days_of_week day = Wed;
   printf("day is %d.\n", day);
   int i; for (i=Sun; i<=Sat; i++) printf("%d ", i);
   printf("\n\n");

   // Strings and Chars
   char name[]  = "sam";
   char name2[] = {'a','n','o','n','\0'};
   char letter  = 'a';
   printf("my name is %s also known as %s\n", name, name);
   printf("my name is %s also known as %s\n", name2, name2);
   printf("my name is %c also known as %c\n", letter, letter);
   printf("itoddler BTFO\n\n");

   //type casting
   float a = 1.2;
   //int b  = a; //Compiler will throw an error for this
   int b = (int)a + 1;
   float c = a + (float)1;
   printf("Value of a is %f\n",a);
   printf("Value of b is %d\n",b);
   printf("Value of b is %f\n",c);



   return 0;
}



