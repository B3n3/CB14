%{
        #include <stdlib.h>
        #include <stdio.h>
        #include <string.h>
        #include "symbol_table.h"
        #include "code_gen.h"
        #include "tree.h"
%}

%start          Input
%token          STRUCT END FUNC RETURN WITH DO LET IN COND THEN NOT OR ID NUM GENERICS

@autoinh symbols

@attributes { char *name; } ID
@attributes { long value; } NUM
@attributes { struct symbol_t* symbols; struct symbol_t* structs; } Program
@attributes { struct symbol_t* structs; } Structdef
@attributes { struct symbol_t* fields; } StructIds
@attributes { struct symbol_t* pars; } ids
@attributes { struct symbol_t* symbols; } Term Lexpr Funcdef Stats Expr exprThenStaEnd orTerm multTerm plusTerm exprs
@attributes { struct symbol_t* iSymbols; struct symbol_t* sSymbols; } Stat idIsExpr

@traversal @postorder t
@traversal @postorder check
@traversal @preorder reg
@traversal @postorder codegen

%%

Input:            Program
                   @{
                        @i @Program.symbols@ = @Program.structs@;
                   @}

Program:          Program Funcdef ';'
                   @{
                        @i @Program.0.structs@ = @Program.1.structs@;
                   @}

                | Program Structdef ';'
                   @{
                        @i @Program.0.structs@ = table_merge(@Structdef.structs@, @Program.1.structs@, 1);
                        @i @Program.1.symbols@ = @Program.0.symbols@;
                   @}

                |
                   @{
                        @i @Program.0.structs@ = new_table();
                   @}

                ;


Structdef:        STRUCT ID ':' END
                   @{
                        @i @Structdef.structs@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_STRUCT, 0);
                   @}

                | STRUCT ID ':' StructIds END
                   @{
                        @i @Structdef.structs@ = table_add_struct_with_fields(new_table(), @StructIds.fields@, NULL, @ID.name@, SYMBOL_TYPE_STRUCT, 1);
                   @}

                ;
StructIds:        ID
                   @{
                        @i @StructIds.fields@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0);
                   @}

                | StructIds ID
                   @{
                        @i @StructIds.0.fields@ = table_add_symbol(@StructIds.1.fields@, @ID.name@, SYMBOL_TYPE_VAR, 1);
                   @}
                ;


Funcdef:          FUNC ID '(' ')' Stats END
                   @{
                        @i @Stats.symbols@ = @Funcdef.symbols@;
                   @}

                | FUNC ID '(' ids ')' Stats END
                   @{
                        @i @Stats.symbols@ = table_merge(@Funcdef.symbols@, @ids.pars@, 0);
                   @}

                ;


ids:              ID
                   @{
                        @i @ids.pars@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0);
                   @}

                | ids ID
                   @{
                        @i @ids.pars@ = table_add_symbol(@ids.1.pars@, @ID.name@, SYMBOL_TYPE_VAR, 1);
                   @}
                ;

Stats:            Stats Stat ';'
                   @{
                        @i @Stat.iSymbols@ = @Stats.symbols@;
                        @i @Stats.1.symbols@ = @Stat.sSymbols@;
                   @}

                |
                ;

Stat:             RETURN Expr
                   @{
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                   @}

                | COND END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                   @}

                | COND exprThenStaEnd END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @exprThenStaEnd.symbols@ = @Stat.iSymbols@;
                   @}

                | LET IN Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = @Stat.iSymbols@;
                   @}

                | LET idIsExpr IN Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @idIsExpr.iSymbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = table_merge(@Stat.iSymbols@, @idIsExpr.sSymbols@, 1);
                   @}

                | WITH Expr ':' ID DO Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = table_merge_as_type(@Stat.iSymbols@, table_check_lookup_struct_sublist(@Stat.iSymbols@, @ID.name@), SYMBOL_TYPE_VAR, 1);
                   @}

                | Lexpr '=' Expr
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Lexpr.symbols@ = @Stat.iSymbols@;
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                   @}

                | Term
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Term.symbols@ = @Stat.iSymbols@;
                   @}

                ;

idIsExpr:         ID '=' Expr ';'
                 @{
                        @i @Expr.symbols@ = @idIsExpr.iSymbols@;
                        @i @idIsExpr.sSymbols@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0);
                 @}
                | idIsExpr ID '=' Expr ';'
                 @{
                        @i @Expr.symbols@ = @idIsExpr.iSymbols@;
                        @i @idIsExpr.1.iSymbols@ = @idIsExpr.0.iSymbols@;
                        @i @idIsExpr.0.sSymbols@ = table_add_symbol(@idIsExpr.1.sSymbols@, @ID.name@, SYMBOL_TYPE_VAR, 1);
                 @}
                ;

exprThenStaEnd:   Expr THEN Stats END ';'
                | exprThenStaEnd Expr THEN Stats END ';'
                ;

Lexpr:            ID
                  @{
                        @i @Lexpr.node@ = (treenode *)NULL;
                        @check check_variable(@Lexpr.symbols@, @ID.name@);
                  @}

                | Term '.' ID
                     @{ @t check_field(@Lexpr.symbols@, @ID.name@); @}
                ;

Expr:             Term
                  @{ @reg @Term.node@->reg = @Expr.node@->reg; @}

                | notTerm Term
                  @{ @i @Expr.node@ = new_node(OP_Not, @Term.node@, (treenode *)NULL); @}

                | minusTerm Term
                  @{
                        @i @Expr.node@ = new_node(OP_Negation, @Term.node@, (treenode *)NULL);
                        @reg @Term.node@->reg = @Expr.node@->reg;
                  @}

                | Term plusTerm
                | Term multTerm
                | Term orTerm
                  @{ @i @Expr.node@ = new_node(OP_Disjunction, @Term.node@, @orTerm.node@); @}

                | Term '>' Term
                  @{ @i @Expr.node@ = new_node(OP_Greater, @Term.0.node@, @Term.1.node@); @}

                | Term GENERICS Term
                ;

orTerm:           OR Term
                | orTerm OR Term
                  @{ @i @orTerm.0.node@ = new_node(OP_Disjunction, @Term.node@, @orTerm.1.node@); @}

                ;

multTerm:        '*' Term
		          @{ @reg @Term.node@->reg = @multTerm.node@->reg; @}

                | multTerm '*' Term
                  @{
                        @i @multTerm.0.node@ = new_node(OP_Multiplication, @multTerm.1.node@, @Term.node@);
                        @i @multTerm.0.immediate@ = @Term.immediate@ && @multTerm.1.immediate@;
                        @reg @multTerm.1.node@->reg = @multTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@multTerm.1.node@->reg, @multTerm.0.node@->skip_reg);
                  @}

                ;

plusTerm:         '+' Term
                  @{ @reg @Term.node@->reg = @plusTerm.node@->reg; @}

                | plusTerm '+' Term
                  @{
                        @i @plusTerm.0.node@ = new_node(OP_Addition, @plusTerm.1.node@, @Term.node@);
                        @i @plusTerm.0.immediate@ = @Term.immediate@ && @plusTerm.1.immediate@;
                        @reg @plusTerm.1.node@->reg = @plusTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@plusTerm.1.node@->reg, @plusTerm.0.node@->skip_reg);
                  @}

                ;

notTerm:          notTerm NOT
                | NOT
                ;

minusTerm:        minusTerm '-'
                | '-'
                ;

Term:             '(' Expr ')'
		          @{ @reg @Expr.node@->reg = @Term.node@->reg; @}

                | NUM
                  @{
                        @i @Term.node@ = new_number_leaf(@NUM.value@);
                        @i @Term.immediate@ = 1;
                  @}

                | Term '.' ID
                  @{
                        @t check_field(@Term.symbols@, @ID.name@);
                        @i @Term.0.node@ = new_node_value(OP_Field, @Term.1.node@, new_named_leaf(OP_ID, @ID.name@), table_lookup(@Term.0.symbols@, @ID.name@)==(struct symbol_t *)NULL ? 0 : table_lookup(@Term.0.symbols@, @ID.name@)->stack_offset, -1);
                        @t check_field(@Term.symbols@, @ID.name@);
                        @reg @Term.1.node@->reg = @Term.0.node@->reg; @Term.0.node@->kids[1]->reg = get_next_reg(@Term.0.node@->reg, 0);
                        @i @Term.0.immediate@ = 0;
                  @}

                | ID
                  @{
                        @check check_variable(@Term.symbols@, @ID.name@);
                        @i @Term.node@ = new_named_leaf_value(OP_ID, @ID.name@, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->stack_offset, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->param_index);
                        @i @Term.immediate@ = 0;
                  @}

                | ID '(' ')'
                  @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), NULL);
                        @i @Term.0.immediate@ = 0;
                  @}

                | ID '(' Expr ')'
                  @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), @Expr.node@);
                        @i @Term.0.immediate@ = 0;
                  @}

                | ID '(' exprs ')'
                  @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), @exprs.node@);
                        @i @Term.0.immediate@ = 0;
                  @}

                | ID '(' exprs Expr ')'
                  @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), new_node(OP_Exprs, @exprs.node@, @Expr.node@));
                        @i @Term.0.immediate@ = 0;
                  @}

                ;

exprs:            Expr ','
                | exprs Expr ','
                  @{ @i @exprs.node@ = new_node(OP_Exprs, @exprs.1.node@, @Expr.node@); @}
                ;
%%

extern int yylex();
extern int yylineno;

int yyerror(char *error_text) {
    fprintf(stderr,"Line %i: %s\n",yylineno, error_text);
    exit(2);
}

int main(int argc, char **argv) {
/*    yydebug=1; */
    yyparse();
    return 0;
}

