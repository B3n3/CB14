%{
        #include <stdio.h>
        #include <string.h>
        #include <stdlib.h>
        #include "parser.h"
%}

comment                 "/*"([^\*]|\*[^/])*"*/"
decimalnum              [0-9]+
hexnum                  [0-9][0-9a-fA-F]*H
whitespace              [\n\t ]
identifier              [a-zA-Z]([a-zA-Z0-9]|_)*


%%

struct                  return STRUCT;
end                     return END;
func                    return FUNC;
return                  return RETURN;
with                    return WITH;
do                      return DO;
let                     return LET;
in                      return IN;
cond                    return COND;
then                    return THEN;
not                     return NOT;
or                      return OR;

{identifier}            return ID; @{ @ID.name@ = strdup(yytext); @}

(<>)                    return GENERICS;
\:                      return(':');
\(                      return('(');
\)                      return(')');
\;                      return(';');
=                       return('=');
\.                      return('.');
\-                      return('-');
\+                      return('+');
\*                      return('*');
\>                      return('>');
\,                      return(',');


{decimalnum}            return(NUM); @{ @NUM.value@=strtol(yytext,(char **)NULL,10); @}
{hexnum}                return(NUM); @{ yytext[strlen(yytext)-1]='\0'; @NUM.value@=strtol(yytext,(char **)NULL,16); @}
{comment}               ;
{whitespace}            ;
.                       {fprintf(stderr, "lexical error in line %i", yylineno); exit(1);}

%%


int yywrap() { return 1; }

