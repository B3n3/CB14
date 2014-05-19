        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>
        #include "parser.h"

KEYWORD            struct|end|func|return|with|do|let|in|cond|then|not|or
SPEC_LEXEM         \:|\(|\)|\;|\=|\.|\-|\+|\*|\>|\<>|\,
IDENTIFIER         [[:alpha:]][[:alnum:]_]*
HEX_NUM            [0-9][0-9A-Fa-f]*H
DEC_NUM            [0-9]+
WHITESPACE         [\t\n\r ]
COMMENT_BEG        \/\*
COMMENT_END        \*\/

%option yylineno
%x comment

%%

{COMMENT_BEG}                   BEGIN(comment);
<comment>{COMMENT_END}          BEGIN(INITIAL);
<comment>{COMMENT_BEG}          fprintf(stderr, "Nested comment in line %i .\n", yylineno);
<comment><<EOF>>                { fprintf(stderr, "The comment is not ended - line: %i\n", yylineno); exit(1); }
<comment>{WHITESPACE}           /* whitespace can be ignored */
<comment>.                      /* no matter what's in a comment - ignore it */

struct                          return(STRUCT);
end                             return(END);
func                            return(FUNC);
return                          return(RETURN);
with                            return(WITH);
do                              return(DO);
let                             return(LET);
in                              return(IN);
cond                            return(COND);
then                            return(THEN);
not                             return(NOT);
or                              return(OR);


{IDENTIFIER}                    return(ID); @{ @ID.name@=strdup(yytext); @}

{DEC_NUM}                       return(NUM); @{ @NUM.value@=strtol(yytext,(char **)NULL,10); @}
{HEX_NUM}                       return(NUM); @{ yytext[strlen(yytext)-1]='\0'; @NUM.value@=strtol(yytext,(char **)NULL,16); @}

\<>                             return(GENERICS);
\:                              return(':');
\(                              return('(');
\)                              return(')');
\;                              return(';');
=                               return('=');
\.                              return('.');
\-                              return('-');
\+                              return('+');
\*                              return('*');
\>                              return('>');
\,                              return(',');

{WHITESPACE}                    /* ignore whitespace */

.                               { fprintf(stderr, "Lexical error on line %i\n", yylineno); exit(1); }

%%
