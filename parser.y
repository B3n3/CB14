%{
        #include <stdlib.h>
        #include <stdio.h>
        #include <string.h>
        #include "symbol_table.h"
        #include "code_gen.h"
        #include "tree.h"
%}

%token STRUCT END FUNC RETURN WITH DO LET IN COND THEN NOT OR ID GENERICS NUM
%start Input

@autoinh symbols stack_offset all_pars if_in
@autosyn node defined_vars immediate if_out

@attributes { char *name; } ID
@attributes { long value; } NUM
@attributes { struct symbol_t* symbols; struct symbol_t* structs; int if_in; } Program
@attributes { struct symbol_t* structs; } Structdef
@attributes { struct symbol_t* fields; int offset; } StructIds
@attributes { struct symbol_t* pars; int num_pars; int all_pars; } IdRule
@attributes { struct symbol_t* symbols; int defined_vars; int if_in; int if_out; } Funcdef
@attributes { struct symbol_t* symbols; struct treenode* node; int defined_vars; int stack_offset; int if_in; int if_out; } Stats CondRule
@attributes { struct symbol_t* symbols; struct treenode* node; int immediate; } Expr Term PlusTerm MulTerm OrTerm
@attributes { struct symbol_t* symbols; struct treenode* node; } Lexpr FuncCallRule
@attributes { struct symbol_t* inSymbols; struct symbol_t* outSymbols; struct treenode* node; int defined_vars; int stack_offset; int if_in; int if_out; } Stat
@attributes { struct symbol_t* inSymbols; struct symbol_t* outSymbols; struct treenode* node; int defined_vars; int stack_offset; } ExprRule
@attributes { int toggleNot; int toggleMinus; } NotMinRule

@traversal @postorder check
@traversal @preorder reg
@traversal @postorder codegen


%%

Input   :       Program
                 @{
                        @i @Program.symbols@ = @Program.structs@;
                        @i @Program.if_in@ = 0;

                        @codegen @revorder(1) printf("\t.text\n");
                 @}
        ;


Program :
                 @{
                        @i @Program.structs@ = new_table();
                 @}
        |       Program Funcdef ';'
                 @{
                        @i @Program.0.structs@ = @Program.1.structs@;
                        @i @Program.1.if_in@ = @Funcdef.if_out@;
                 @}
        |       Program Structdef ';'
                 @{
                        @i @Program.0.structs@ = table_merge(@Program.1.structs@, @Structdef.structs@, 1);
                        @i @Program.1.symbols@ = @Program.0.symbols@;
                 @}
        ;

StructIds:      ID
                 @{
                        @i @StructIds.fields@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0, @StructIds.offset@);

                 @}
        |       ID StructIds
                 @{
                        @i @StructIds.0.fields@ = table_add_symbol(@StructIds.1.fields@, @ID.name@, SYMBOL_TYPE_VAR, 1, @StructIds.offset@);
                        @i @StructIds.1.offset@ = @StructIds.offset@ + 8;
                 @}
        ;

Structdef:      STRUCT ID ':' END
                 @{
                        @i @Structdef.structs@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_STRUCT, 0, 0);
                 @}
        |       STRUCT ID ':' StructIds END
                 @{
                        @i @Structdef.structs@ = table_add_struct_with_fields(new_table(), @StructIds.fields@, NULL, @ID.name@, SYMBOL_TYPE_STRUCT, 1, @StructIds.offset@);
                        @i @StructIds.offset@ = 0;
                 @}
        ;

IdRule  :       ID
                 @{
                        @i @IdRule.pars@ = table_add_param(new_table(), @ID.name@, 1, 0);
                        @i @IdRule.num_pars@ = 1;
                 @}
        |       IdRule ID
                 @{
                        @i @IdRule.pars@ = table_add_param(@IdRule.1.pars@, @ID.name@, @IdRule.num_pars@, 1);
                        @i @IdRule.num_pars@ = @IdRule.1.num_pars@ + 1;
                 @}
        ;

Funcdef :       FUNC ID '(' ')' Stats END
                 @{
                        @i @Stats.symbols@ = @Funcdef.symbols@;
                        @i @Stats.stack_offset@ = 0;

                        @codegen @revorder(1) function_header(@ID.name@, @Funcdef.defined_vars@);
                 @}
        |       FUNC ID '(' IdRule ')' Stats END
                 @{
                        @i @Stats.symbols@ = table_merge(@Funcdef.symbols@, @IdRule.pars@, 1);
                        @i @Stats.stack_offset@ = 0;
                        @i @IdRule.all_pars@ = @IdRule.num_pars@;

                        @codegen @revorder(1) function_header(@ID.name@, @Funcdef.defined_vars@);
                 @}
        ;

Stats   :       /* EPMTY */
                   @{
                        @i @Stats.node@ = new_leaf(OP_NopEmpty); /* TODO */
                        @i @Stats.defined_vars@ = 0;
                        @i @Stats.if_out@ = @Stats.if_in@;
                   @}
        |       Stats Stat ';'
                 @{
                        @i @Stat.inSymbols@ = @Stats.symbols@;
                        @i @Stats.1.symbols@ = @Stat.outSymbols@;
                        @i @Stats.defined_vars@ = @Stat.defined_vars@ + @Stats.1.defined_vars@;
                        @i @Stats.1.stack_offset@ = @Stats.stack_offset@ + @Stat.defined_vars@ * 8;
                        @i @Stats.node@ = new_node(OP_Stats, @Stat.node@, @Stats.1.node@);
                        @i @Stat.if_in@ = @Stats.if_in@;
                        @i @Stats.1.if_in@ = @Stat.if_out@;
                        @i @Stats.if_out@ = @Stats.1.if_out@;

                      /*  @codegen burm_label(@Stat.node@); burm_reduce(@Stat.node@, 1); */
                 @}
        ;

CondRule:       Expr THEN Stats END ';'
                 @{
                        @i @CondRule.defined_vars@ = 0; /* TODO */

                        @i @Expr.symbols@ = @CondRule.symbols@;
                        @i @Stats.symbols@ = @CondRule.symbols@;
                        @i @CondRule.node@ = new_node(OP_If, @Expr.node@, @Stats.node@);
                        @i @Stats.if_in@ = @CondRule.if_in@ + 1;
                        @i @CondRule.if_out@ = @Stats.if_out@;

                        @codegen @revorder(1) burm_label(@Expr.node@); burm_reduce(@Expr.node@, 1);
                        @codegen @revorder(1) printf("\tcmp $%d, %%%s \n\tjz .end%d\n", 0, @Expr.node@->reg, @CondRule.if_in@);
                        @reg @Expr.node@->reg = get_next_reg((char *)NULL, 0);
                        /*@codegen  printf("\tjmp .totalEnd%d\n.end%i:\n", 123, @CondRule.if_in@); */
                        @codegen printf(".end%i:\n", @CondRule.if_in@);
                 @}
        |       CondRule Expr THEN Stats END ';'
                 @{
                        @i @CondRule.defined_vars@ = 0; /* TODO */

                        @i @Expr.symbols@ = @CondRule.symbols@;
                        @i @Stats.symbols@ = @CondRule.symbols@;
                        @i @CondRule.node@ = new_node(OP_If, @Expr.node@, @Stats.node@);
                        @i @CondRule.0.if_out@ = @CondRule.1.if_out@;
                        @i @CondRule.1.symbols@ = @CondRule.0.symbols@;

                        @codegen @revorder(1) burm_label(@Expr.node@); burm_reduce(@Expr.node@, 1);
                        @codegen @revorder(1) printf("\tcmp $%d, %%%s \n\tjz .end%d\n", 0, @Expr.node@->reg, @Stats.if_out@);
                        @reg @Expr.node@->reg = get_next_reg((char *)NULL, 0);
                        @codegen @e CondRule.1.if_in : Stats.if_out ;
                            printf("\tjmp .totalEnd%d\n.end%i:\n", 123, @Stats.if_out@);
                            @CondRule.1.if_in@ = @Stats.if_out@ + 1;

                     /* @codegen burm_label(@Expr.node@); burm_reduce(@Expr.node@, 1);
                        @codegen printf("\tcmp $%d, %%%s \n\tjz .end%d\n", 0, @Expr.node@->reg, @CondRule.1.if_out@);
                        @reg @Expr.node@->reg = get_next_reg((char *)NULL, 0);
                        @codegen printf("\tjmp .totalEnd%d\n.end%i:\n", 123, @CondRule.1.if_out@); */
                 @}

        ;

ExprRule:       ID '=' Expr ';'
                 @{
                        @i @Expr.symbols@ = @ExprRule.inSymbols@;
                        @i @ExprRule.outSymbols@ = table_add_symbol(new_table(), @ID.name@, SYMBOL_TYPE_VAR, 0, @ExprRule.stack_offset@);
                        @i @ExprRule.defined_vars@ = 1;
                        @i @ExprRule.node@ = new_node(OP_Assign, new_named_leaf_value(OP_ID, @ID.name@, @ExprRule.stack_offset@, -1), @Expr.node@);
                        @reg @Expr.node@->reg = get_next_reg((char *)NULL, 0); @ExprRule.node@->reg = @Expr.node@->reg;
                        @codegen burm_label(@ExprRule.node@); burm_reduce(@ExprRule.node@, 1);
                 @}

        |       ID '=' Expr ';' ExprRule
                 @{
                        @i @Expr.symbols@ = @ExprRule.inSymbols@;
                        @i @ExprRule.1.inSymbols@ = @ExprRule.0.inSymbols@;
                        @i @ExprRule.0.outSymbols@ = table_add_symbol(@ExprRule.1.outSymbols@, @ID.name@, SYMBOL_TYPE_VAR, 1, @ExprRule.stack_offset@);
                        @i @ExprRule.0.defined_vars@ = @ExprRule.1.defined_vars@ + 1;
                        @i @ExprRule.1.stack_offset@ = @ExprRule.0.stack_offset@ + 8;
                        @i @ExprRule.0.node@ = new_node(OP_Assign, new_named_leaf_value(OP_ID, @ID.name@, @ExprRule.0.stack_offset@, -1), @Expr.node@);
                        @reg @Expr.node@->reg = get_next_reg((char *)NULL, 0); @ExprRule.0.node@->reg = @Expr.node@->reg;
                        @codegen burm_label(@ExprRule.node@); burm_reduce(@ExprRule.node@, 1);
                 @}

        ;

Stat    :       RETURN Expr
                 @{
                        @i @Expr.symbols@ = @Stat.inSymbols@;
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Stat.node@ = new_node(OP_Return, @Expr.node@, (treenode *)NULL);
                        @i @Stat.defined_vars@ = 0;
                        @i @Stat.if_out@ = @Stat.if_in@;

                        @reg @Stat.node@->reg = get_next_reg((char *)NULL, 0); @Expr.node@->reg = @Stat.node@->reg;
                        @codegen burm_label(@Stat.node@); burm_reduce(@Stat.node@, 1);
                 @}

        |       COND END                /* COND { Expr THEN Stats END ’;’ } END */
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                        @i @Stat.if_out@ = @Stat.if_in@;
                 @}

        |       COND CondRule END                /* COND { Expr THEN Stats END ’;’ } END */
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @CondRule.symbols@ = @Stat.inSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                        @i @Stat.if_out@ = @Stat.if_in@;
                 @}

        |       LET IN Stats END        /* LET { ID ’=’ Expr ’;’ } IN Stats END */
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Stats.symbols@ = @Stat.inSymbols@;
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0;
                        @i @Stat.if_out@ = @Stat.if_in@;
                 @}

        |       LET ExprRule IN Stats END        /* LET { ID ’=’ Expr ’;’ } IN Stats END */
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @ExprRule.inSymbols@ = @Stat.inSymbols@;
                        @i @Stats.symbols@ = table_merge(@Stat.inSymbols@, @ExprRule.outSymbols@, 1);
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = @ExprRule.defined_vars@ + @Stats.defined_vars@;
                        @i @Stats.stack_offset@ = @Stat.stack_offset@ + @ExprRule.defined_vars@ * 8;
                        @i @Stat.if_out@ = @Stat.if_in@;
                 @}

        |       WITH Expr ':' ID DO Stats END
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Expr.symbols@ = @Stat.inSymbols@;
                        @i @Stats.symbols@ = table_merge_as_type(@Stat.inSymbols@, table_check_lookup_struct_sublist(@Stat.inSymbols@, @ID.name@), SYMBOL_TYPE_VAR, 1);
                        @i @Stat.node@ = NULL; /* TODO */
                        @i @Stat.defined_vars@ = 0; /* TODO */
                        @i @Stat.if_out@ = @Stat.if_in@;
                 @}
        |       Lexpr '=' Expr        /* Zuweisung */
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Lexpr.symbols@ = @Stat.inSymbols@;
                        @i @Expr.symbols@ = @Stat.inSymbols@;
                        @i @Stat.node@ = new_node(OP_Assign, @Lexpr.node@, @Expr.node@);
                        @i @Stat.defined_vars@ = 0;
                        @i @Stat.if_out@ = @Stat.if_in@;

                        @reg @Lexpr.node@->reg = get_next_reg((char *)NULL, 0); @Expr.node@->reg = get_next_reg(@Lexpr.node@->reg, 0); @Stat.node@->reg = @Expr.node@->reg;
                        @codegen burm_label(@Stat.node@); burm_reduce(@Stat.node@, 1);
                 @}

        |       Term
                 @{
                        @i @Stat.outSymbols@ = @Stat.inSymbols@;
                        @i @Term.symbols@ = @Stat.inSymbols@;
                        @i @Stat.defined_vars@ = 0; /* TODO */
                        /*@i @Stat.node@ = new_node(OP_Nop, (treenode*)NULL, (treenode*)NULL); */
                        @i @Stat.node@ = new_leaf(OP_NopEmpty);
                        @i @Stat.if_out@ = @Stat.if_in@;
                        @codegen burm_label(@Stat.node@); burm_reduce(@Stat.node@, 1);
                 @}

        ;

Lexpr   :       ID                /* Schreibender Variablenzugriff */
                 @{
                        @i @Lexpr.node@ = new_named_leaf_value(OP_ID, @ID.name@, (table_lookup(@Lexpr.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Lexpr.symbols@, @ID.name@)->stack_offset, (table_lookup(@Lexpr.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Lexpr.symbols@, @ID.name@)->param_index);
                        @check check_variable(@Lexpr.symbols@, @ID.name@);
                 @}
        |       Term '.' ID         /* Schreibender Feldzugriff */
                 @{
                        @i @Lexpr.node@ = new_node_value(OP_Field, @Term.node@, new_named_leaf(OP_ID, @ID.name@), table_lookup_sublists(@Lexpr.symbols@, @ID.name@)==(struct symbol_t *)NULL ? 0 : table_lookup_sublists(@Lexpr.symbols@, @ID.name@)->stack_offset, -1);
                        @check check_field(@Lexpr.symbols@, @ID.name@);
                        @reg @Term.node@->reg = @Lexpr.node@->reg; @Lexpr.node@->kids[1]->reg = get_next_reg(@Lexpr.node@->reg, 0);
                 @}
        ;

NotMinRule:     NotMinRule NOT
                 @{
                        @i @NotMinRule.toggleNot@ = @NotMinRule.1.toggleNot@ * (-1);
                        @i @NotMinRule.toggleMinus@ = @NotMinRule.1.toggleMinus@;
                 @}
        |       NotMinRule '-'
                 @{
                        @i @NotMinRule.toggleNot@ = @NotMinRule.1.toggleNot@;
                        @i @NotMinRule.toggleMinus@ = @NotMinRule.1.toggleMinus@ * (-1);
                 @}
        |       NOT
                 @{
                        @i @NotMinRule.toggleNot@ = 1;
                        @i @NotMinRule.toggleMinus@ = -1;
                 @}
        |       '-'
                 @{
                        @i @NotMinRule.toggleNot@ = -1;
                        @i @NotMinRule.toggleMinus@ = 1;
                 @}
        ;
PlusTerm:       '+' Term
                 @{
                        @reg @Term.node@->reg = @PlusTerm.node@->reg;
                 @}
        |       PlusTerm '+' Term
                 @{
                        @i @PlusTerm.0.node@ = new_node(OP_Addition, @PlusTerm.1.node@, @Term.node@);
                        @i @PlusTerm.0.immediate@ = @Term.immediate@ && @PlusTerm.1.immediate@;
                        @reg @PlusTerm.1.node@->reg = @PlusTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@PlusTerm.1.node@->reg, @PlusTerm.0.node@->skip_reg);
                 @}
        ;
MulTerm :       '*' Term
                 @{
                        @reg @Term.node@->reg = @MulTerm.node@->reg;
                 @}
        |       MulTerm '*' Term
                 @{
                        @i @MulTerm.0.node@ = new_node(OP_Multiplication, @MulTerm.1.node@, @Term.node@);
                        @i @MulTerm.0.immediate@ = @Term.immediate@ && @MulTerm.1.immediate@;
                        @reg @MulTerm.1.node@->reg = @MulTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@MulTerm.1.node@->reg, @MulTerm.0.node@->skip_reg);
                 @}
        ;
OrTerm  :       OR Term
                 @{
                        @reg @Term.node@->reg = @OrTerm.node@->reg;
                 @}
        |       OrTerm OR Term
                 @{
                        @i @OrTerm.0.node@ = new_node(OP_Disjunction, @OrTerm.1.node@, @Term.node@);
                        @i @OrTerm.0.immediate@ = @Term.immediate@ && @OrTerm.1.immediate@;
                        @reg @OrTerm.1.node@->reg = @OrTerm.0.node@->reg; @Term.node@->reg = get_next_reg(@OrTerm.1.node@->reg, @OrTerm.0.node@->skip_reg);
                 @}
        ;

Expr    :       Term
                 @{
                        @reg @Term.node@->reg = @Expr.node@->reg;
                 @}
        |       NotMinRule Term        /* { NOT } Term */
                 @{
                        @e Expr.node : NotMinRule.toggleNot NotMinRule.toggleMinus Term.node;
                           if(@NotMinRule.toggleNot@ > 0 && @NotMinRule.toggleMinus@ > 0) { @Expr.node@ = new_node(OP_MinusNot, @Term.node@, (treenode*)NULL); }
                           else if(@NotMinRule.toggleNot@ < 0 && @NotMinRule.toggleMinus@ > 0) { @Expr.node@ = new_node(OP_Negation, @Term.node@, (treenode*)NULL); }
                           else if(@NotMinRule.toggleNot@ > 0 && @NotMinRule.toggleMinus@ < 0) { @Expr.node@ = new_node(OP_Not, @Term.node@, (treenode*)NULL); }
                           else { @Expr.node@ = new_node(OP_Nop, @Term.node@, (treenode*)NULL); }

                        @reg @Term.node@->reg = @Expr.node@->reg;
                 @}
        |       Term PlusTerm        /* { '+' Term } */
                 @{
                        @i @Expr.node@ = new_node(OP_Addition, @PlusTerm.node@, @Term.node@);
                        @i @Expr.immediate@ = @Term.immediate@ && @PlusTerm.immediate@;
                        @reg if(!@PlusTerm.immediate@) { @PlusTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@PlusTerm.node@->reg, @Expr.node@->skip_reg); @PlusTerm.node@->skip_reg = 1; } else { @Term.node@->reg = @Expr.node@->reg; @PlusTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                 @}
        |       Term MulTerm         /* { '*' Term } */
                 @{
                        @i @Expr.node@ = new_node(OP_Multiplication, @MulTerm.node@, @Term.node@);
                        @i @Expr.immediate@ = @Term.immediate@ && @MulTerm.immediate@;
                        @reg if(!@MulTerm.immediate@) { @MulTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@MulTerm.node@->reg, @Expr.node@->skip_reg); @MulTerm.node@->skip_reg = 1; } else { @Term.node@-> reg = @Expr.node@->reg; @MulTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                 @}
        |       Term OrTerm         /* { OR Term } */
                 @{
                        @i @Expr.node@ = new_node(OP_Disjunction, @Term.node@, @OrTerm.node@);
                        @i @Expr.immediate@ = 0;
                        @reg if(!@OrTerm.immediate@) { @OrTerm.node@->reg = @Expr.node@->reg; @Term.node@->reg = get_next_reg(@OrTerm.node@->reg, @Expr.node@->skip_reg); @OrTerm.node@->skip_reg = 1; } else { @Term.node@->reg = @Expr.node@->reg; @OrTerm.node@->reg = get_next_reg(@Term.node@->reg, @Expr.node@->skip_reg); }
                 @}
        |       Term '>' Term
                 @{
                        @i @Expr.node@ = new_node(OP_Greater, @Term.node@, @Term.1.node@);
                        @i @Expr.immediate@ = 0;
                        @reg @Term.node@->reg = get_next_reg(@Expr.node@->reg, 0);
                        @reg @Term.1.node@->reg = get_next_reg(@Term.node@->reg, 0);
                 @}
        |       Term GENERICS Term
                 @{
                        @i @Expr.node@ = new_node(OP_NotEqual, @Term.node@, @Term.1.node@);
                        @i @Expr.immediate@ = 0;
                        @reg @Term.node@->reg = get_next_reg(@Expr.node@->reg, 0);
                        @reg @Term.1.node@->reg = get_next_reg(@Term.node@->reg, 0);
                 @}
        ;

FuncCallRule:   Expr ','
        |       FuncCallRule Expr ','
                 @{
                        @i @FuncCallRule.node@ = new_node(OP_Exprs, @FuncCallRule.1.node@, @Expr.node@);
                 @}
        ;

Term    :       '(' Expr ')'
                 @{
                        @reg @Expr.node@->reg = @Term.node@->reg;
                 @}
        |       NUM
                 @{
                        @i @Term.node@ = new_number_leaf(@NUM.value@);
                        @i @Term.immediate@ = 1;
                 @}
        |       Term '.' ID                        /* Lesender Feldzugriff */
                 @{
                        @i @Term.0.node@ = new_node_value(OP_Field, @Term.1.node@, new_named_leaf(OP_ID, @ID.name@), table_lookup_sublists(@Term.0.symbols@, @ID.name@)==(struct symbol_t *)NULL ? 0 : table_lookup_sublists(@Term.0.symbols@, @ID.name@)->stack_offset, -1);
                        @check check_field(@Term.symbols@, @ID.name@);
                        @reg @Term.1.node@->reg = @Term.0.node@->reg; @Term.0.node@->kids[1]->reg = get_next_reg(@Term.0.node@->reg, 0);
                        @i @Term.0.immediate@ = 0;
                 @}

        |       ID                                /* Lesender Variablenzugriff */
                 @{
                        @i @Term.node@ = new_named_leaf_value(OP_ID, @ID.name@, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->stack_offset, (table_lookup(@Term.symbols@, @ID.name@)==NULL) ? 0 : table_lookup(@Term.symbols@, @ID.name@)->param_index);
                        @i @Term.immediate@ = 0;

                        @check check_variable(@Term.symbols@, @ID.name@);
                 @}

        |       ID '(' ')'                        /* Leerer Funktionsaufruf */
                 @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), NULL);
                        @i @Term.0.immediate@ = 0;
                 @}
        |       ID '(' Expr ')'                        /* Leerer Funktionsaufruf */
                 @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), @Expr.node@);
                        @i @Term.0.immediate@ = 0;
                 @}
        |       ID '(' FuncCallRule Expr ')'        /* Funktionsaufruf */
                 @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), new_node(OP_Exprs, @FuncCallRule.node@, @Expr.node@));
                        @i @Term.0.immediate@ = 0;
                 @}
        |       ID '(' FuncCallRule ')'                /* Funktionsaufruf */
                 @{
                        @i @Term.node@ = new_node(OP_Call, new_named_leaf(OP_ID, @ID.name@), @FuncCallRule.node@);
                        @i @Term.0.immediate@ = 0;
                 @}
        ;

%%



extern int yylex();
extern int yylineno;

int yyerror(char *error_text) {
    fprintf(stderr,"Line %i: %s\n",yylineno, error_text);
    exit(2);
}

int main(int argc, char **argv) {
    yyparse();
    return 0;
}




