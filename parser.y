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

@autoinh symbols stack_offset all_pars
@autosyn node defined_vars immediate

@attributes { char *name; } ID
@attributes { long value; } NUM
@attributes { struct symbol_t* symbols; struct symbol_t* structs; } Program
@attributes { struct symbol_t* structs; } Structdef
@attributes { struct symbol_t* fields; int offset; } StructIds
@attributes { struct symbol_t* pars; int num_pars; int all_pars; } ids
@attributes { struct symbol_t* symbols; int defined_vars; } Funcdef
@attributes { struct symbol_t* symbols; int defined_vars; int stack_offset; } Stats exprThenStaEnd
@attributes { struct symbol_t* symbols; struct treenode* node; int immediate; } Expr Term plusTerm multTerm orTerm
@attributes { struct symbol_t* symbols; struct treenode* node; } Lexpr Bterm exprs
@attributes { struct symbol_t* iSymbols; struct symbol_t* sSymbols; struct treenode* node; int defined_vars; int stack_offset; } Stat
@attributes { struct symbol_t* iSymbols; struct symbol_t* sSymbols; } idIsExpr
@attributes { int toggleNot; int toggleMinus; } notTerm

@traversal @postorder check
@traversal @preorder reg
@traversal @postorder codegen

%%

Input:            Program
                   @{
                        @i @Program.symbols@ = @Program.structs@;
                        @codegen @revorder(1) printf("\t.text\n");
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
                        @i @Structdef.structs@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_STRUCT, 0, 0);
                   @}

                | STRUCT ID ':' StructIds END
                   @{
                        @i @Structdef.structs@ = table_add_struct_with_fields(new_table(), @StructIds.fields@, NULL, @ID.name@, SYMBOL_TYPE_STRUCT, 1, @StructIds.offset@);
                        @i @StructIds.offset@ = 0;
                   @}

                ;
StructIds:        ID
                   @{
                        @i @StructIds.fields@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0, @StructIds.offset@);
                   @}

                | ID StructIds
                   @{
                        @i @StructIds.0.fields@ = table_add_symbol(@StructIds.1.fields@, @ID.name@, SYMBOL_TYPE_VAR, 1, @StructIds.offset@);
                        @i @StructIds.1.offset@ = @StructIds.offset@ + 1;
                   @}
                ;


Funcdef:          FUNC ID '(' ')' Stats END
                   @{
                        @i @Stats.symbols@ = @Funcdef.symbols@;
                        @i @Stats.stack_offset@ = 0;

                        @codegen @revorder(1) function_header(@ID.name@);
                   @}

                | FUNC ID '(' ids ')' Stats END
                   @{
                        @i @Stats.symbols@ = table_merge(@Funcdef.symbols@, @ids.pars@, 0);
                        @i @Stats.stack_offset@ = 0;
                        @i @ids.all_pars@ = @ids.num_pars@;

                        @codegen @revorder(1) function_header(@ID.name@);
                   @}

                ;


ids:              ID
                   @{
                        @i @ids.pars@ = table_add_param(new_table(), @ID.name@, 1, 0);
                        @i @ids.num_pars@ = 1;
                   @}

                | ids ID
                   @{
                        @i @ids.pars@ = table_add_param(@ids.1.pars@, @ID.name@, @ids.num_pars@, 1);
                        @i @ids.num_pars@ = @ids.1.num_pars@ + 1;
                   @}
                ;

Stats:            Stats Stat ';'
                   @{
                        @i @Stat.iSymbols@ = @Stats.symbols@;
                        @i @Stats.1.symbols@ = @Stat.sSymbols@;
                        @i @Stats.defined_vars@ = @Stat.defined_vars@ + @Stats.1.defined_vars@;
                        @i @Stats.1.stack_offset@ = @Stats.stack_offset@ + @Stat.defined_vars@ * 8;

                        @codegen /* write_tree(@Stat.node@, 0); */ burm_label(@Stat.node@); burm_reduce(@Stat.node@, 1);
                   @}

                |
                  @{ @i @Stats.defined_vars@ = 0; @}
                ;

Stat:             RETURN Expr
                   @{
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Stat.node@ = new_node(OP_Return, @Expr.node@, (treenode *)NULL);

                        @reg @Stat.node@->reg = get_next_reg((char *)NULL, 0); @Expr.node@->reg = @Stat.node@->reg;
                        @i @Stat.defined_vars@ = 0;
                   @}

                | COND END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                   @}

                | COND exprThenStaEnd END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @exprThenStaEnd.symbols@ = @Stat.iSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                   @}

                | LET IN Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = @Stat.iSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                   @}

                | LET idIsExpr IN Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @idIsExpr.iSymbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = table_merge(@Stat.iSymbols@, @idIsExpr.sSymbols@, 1);
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                   @}

                | WITH Expr ':' ID DO Stats END
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                        @i @Stats.symbols@ = table_merge_as_type(@Stat.iSymbols@, table_check_lookup_struct_sublist(@Stat.iSymbols@, @ID.name@), SYMBOL_TYPE_VAR, 1);
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                   @}

                | Lexpr '=' Expr
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Lexpr.symbols@ = @Stat.iSymbols@;
                        @i @Expr.symbols@ = @Stat.iSymbols@;
                        @i @Stat.node@ = (treenode *)NULL;
                        @i @Stat.defined_vars@ = 0;
                   @}

                | Term
                   @{
                        @i @Stat.sSymbols@ = @Stat.iSymbols@;
                        @i @Term.symbols@ = @Stat.iSymbols@;
                        @i @Stat.defined_vars@ = 0; /* TODO */
                        @i @Stat.node@ = NULL; /* TODO */
                   @}

                ;

idIsExpr:         ID '=' Expr ';'
                 @{
                        @i @Expr.symbols@ = @idIsExpr.iSymbols@;
                        @i @idIsExpr.sSymbols@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0, 0);
                 @}

                | idIsExpr ID '=' Expr ';'
                 @{
                        @i @Expr.symbols@ = @idIsExpr.iSymbols@;
                        @i @idIsExpr.1.iSymbols@ = @idIsExpr.0.iSymbols@;
                        @i @idIsExpr.0.sSymbols@ = table_add_symbol(@idIsExpr.1.sSymbols@, @ID.name@, SYMBOL_TYPE_VAR, 1, 0);
                 @}
                ;

exprThenStaEnd:   Expr THEN Stats END ';'
                 @{
                        @i @exprThenStaEnd.defined_vars@ = 0; /* TODO */
                 @}

                | exprThenStaEnd Expr THEN Stats END ';'
                 @{
                        @i @exprThenStaEnd.defined_vars@ = 0; /* TODO */
                 @}

                ;

Lexpr:            ID
                  @{
                        @i @Lexpr.node@ = (treenode *)NULL;
                        @check check_variable(@Lexpr.symbols@, @ID.name@);
                  @}

                | Term '.' ID
                     @{ @check check_field(@Lexpr.symbols@, @ID.name@); @}
                ;

Expr:             Term
                  @{ @reg @Term.node@->reg = @Expr.node@->reg; @}

                | notTerm Term
                  @{
                        @e Expr.node : notTerm.toggleNot notTerm.toggleMinus Term.node;
                           if(@notTerm.toggleNot@ > 0 && @notTerm.toggleMinus@ > 0) { @Expr.node@ = new_node(OP_MinusNot, @Term.node@, (treenode*)NULL); }
                           else if(@notTerm.toggleNot@ < 0 && @notTerm.toggleMinus@ > 0) { @Expr.node@ = new_node(OP_Negation, @Term.node@, (treenode*)NULL); }
                           else if(@notTerm.toggleNot@ > 0 && @notTerm.toggleMinus@ < 0) { @Expr.node@ = new_node(OP_Not, @Term.node@, (treenode*)NULL); }
                           else { @Expr.node@ = new_node(OP_Nop, @Term.node@, (treenode*)NULL); }

                        @reg @Term.node@->reg = @Expr.node@->reg;
                  @}

                | Term plusTerm
                  @{
                        @i @Expr.node@ = new_node(OP_Addition, @plusTerm.node@, @Term.node@);
                        @i @Expr.immediate@ = @Term.immediate@ && @plusTerm.immediate@;
                        @reg if(!@plusTerm.immediate@) { @plusTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@plusTerm.node@->reg, @Expr.node@->skip_reg); @plusTerm.node@->skip_reg = 1; } else { @Term.node@->reg = @Expr.node@->reg; @plusTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                  @}

                | Term multTerm
                  @{
                        @i @Expr.node@ = new_node(OP_Multiplication, @multTerm.node@, @Term.node@);
                        @i @Expr.immediate@ = @Term.immediate@ && @multTerm.immediate@;
                        @reg if(!@multTerm.immediate@) { @multTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@multTerm.node@->reg, @Expr.node@->skip_reg); @multTerm.node@->skip_reg = 1; } else { @Term.node@-> reg = @Expr.node@->reg; @multTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                  @}

                | Term orTerm
                  @{
                        @i @Expr.node@ = new_node(OP_Disjunction, @Term.node@, @orTerm.node@);
                        @i @Expr.immediate@ = 0;
                        @reg if(!@orTerm.immediate@) { @orTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@orTerm.node@->reg, @Expr.node@->skip_reg); @orTerm.node@->skip_reg = 1; } else { @Term.node@->reg = @Expr.node@->reg; @orTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                  @}

                | Term '>' Term
                  @{
                        @i @Expr.node@ = new_node(OP_Greater, @Term.node@, @Term.1.node@);
                        @i @Expr.immediate@ = 0;
                        @reg @Term.node@->reg = get_next_reg(@Expr.node@->reg, 0);
                        @reg @Term.1.node@->reg = get_next_reg(@Term.node@->reg, 0);
                  @}

                | Term GENERICS Term
                  @{
                        @i @Expr.node@ = new_node(OP_NotEqual, @Term.node@, @Term.1.node@);
                        @i @Expr.immediate@ = 0;
                        @reg @Term.node@->reg = get_next_reg(@Expr.node@->reg, 0);
                        @reg @Term.1.node@->reg = get_next_reg(@Term.node@->reg, 0);
                  @}
                ;

orTerm:           OR Term
                  @{ @reg @Term.node@->reg = @orTerm.node@->reg; @}

                | orTerm OR Term
                  @{
                        @i @orTerm.0.node@ = new_node(OP_Disjunction, @orTerm.1.node@, @Term.node@);
                        @i @orTerm.0.immediate@ = @Term.immediate@ && @orTerm.1.immediate@;
                        @reg @orTerm.1.node@->reg = @orTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@orTerm.1.node@->reg, @orTerm.0.node@->skip_reg);
                  @}

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
                  @{
                        @i @notTerm.toggleNot@ = @notTerm.1.toggleNot@ * (-1);
                        @i @notTerm.toggleMinus@ = @notTerm.1.toggleMinus@;
                  @}

                | notTerm '-'
                  @{
                        @i @notTerm.toggleNot@ = @notTerm.1.toggleNot@;
                        @i @notTerm.toggleMinus@ = @notTerm.1.toggleMinus@ * (-1);
                  @}

                | NOT
                  @{
                        @i @notTerm.toggleNot@ = 1;
                        @i @notTerm.toggleMinus@ = -1;
                  @}

                | '-'
                  @{
                        @i @notTerm.toggleNot@ = -1;
                        @i @notTerm.toggleMinus@ = 1;
                  @}

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
                        @i @Term.0.node@ = new_node_value(OP_Field, @Term.1.node@, new_named_leaf(OP_ID, @ID.name@), table_lookup_sublists(@Term.0.symbols@, @ID.name@)==(struct symbol_t *)NULL ? 0 : table_lookup_sublists(@Term.0.symbols@, @ID.name@)->stack_offset, -1);
                        @check check_field(@Term.symbols@, @ID.name@);
                        @reg @Term.1.node@->reg = @Term.0.node@->reg; @Term.0.node@->kids[1]->reg = get_next_reg(@Term.0.node@->reg, 0);
                        @i @Term.0.immediate@ = 0;
                  @}

                | ID
                  @{
                        @i @Term.node@ = new_named_leaf_value(OP_ID, @ID.name@, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->stack_offset, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->param_index);
                        @i @Term.immediate@ = 0;

                        @check check_variable(@Term.symbols@, @ID.name@);
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

