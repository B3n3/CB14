#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "symbol_table.h"

struct symbol_t* new_table(void) {
    return (struct symbol_t *)NULL;
}

struct symbol_t *clone_table(struct symbol_t *table) {
    struct symbol_t *element;
    struct symbol_t *new_tablex;

    element=table;
    new_tablex=new_table();
    while(element!=(struct symbol_t *)NULL) {
        if(element->type==SYMBOL_TYPE_STRUCT) {
            new_tablex=table_add_struct_with_fields(new_tablex,clone_table(element->sublist), NULL, element->identifier, element->type, 0, NULL, element->stack_offset);
        } else {
           if(element->param_index!=-1) {
               new_tablex=table_add_param(new_tablex,element->identifier,element->param_index, 0);
           }
           else {
               new_tablex=table_add_symbol_with_startreg(new_tablex,element->identifier,element->type,0, element->start_reg,element->stack_offset);
           }
        }
        element=element->next;
    }

    return new_tablex;
}

struct symbol_t *table_add_symbol(struct symbol_t *table, char *identifier, short type, short check, int stack_offset) {
    return table_add_struct_with_fields(table, (struct symbol_t*) NULL, NULL, identifier, type, check, NULL, stack_offset);
}

struct symbol_t *table_add_symbol_with_startreg(struct symbol_t *table, char *identifier, short type, short check, char* start_reg, int stack_offset) {
    return table_add_struct_with_fields(table, (struct symbol_t*) NULL, NULL, identifier, type, check, start_reg, stack_offset);
}

struct symbol_t *table_add_struct_with_fields(struct symbol_t *table, struct symbol_t* sublist, struct symbol_t* super_table, char *identifier, short type, short check, char* start_reg, int stack_offset) {

    struct symbol_t *element;
    struct symbol_t *new_element;

    if(type==SYMBOL_TYPE_FIELD) {
        if(table_lookup_sublists(super_table,identifier)!=(struct symbol_t *)NULL) {
            if(check) {
                fprintf(stderr,"Duplicate field %s.\n",identifier);
                exit(3);
            }

            table=table_remove_symbol(table,identifier);
        }
    } else {
        if(table_lookup(table,identifier)!=(struct symbol_t *)NULL) {
            if(check) {
                fprintf(stderr,"Duplicate var %s.\n",identifier);
                exit(3);
            }

            table=table_remove_symbol(table,identifier);
        }
    }

    new_element=(struct symbol_t *)malloc(sizeof(struct symbol_t));
    new_element->next=(struct symbol_t *)NULL;
    new_element->identifier=strdup(identifier);
    new_element->type=type;
    new_element->type=type;
    new_element->start_reg=start_reg;
    new_element->stack_offset=stack_offset;
    new_element->param_index=-1;

    if(sublist != (struct symbol_t*)NULL) {
        struct symbol_t *sub_element;
        struct symbol_t *new_sublist=new_table();

        sub_element=sublist;
        while(sub_element!=(struct symbol_t *)NULL) {
            new_sublist=table_add_struct_with_fields(new_sublist, NULL, table, sub_element->identifier,SYMBOL_TYPE_FIELD,check, NULL, sub_element->stack_offset);
            sub_element=sub_element->next;
        }
        new_element->sublist = new_sublist;
        /*new_element->sublist = clone_table(sublist);*/
    }

    if((struct symbol_t *)NULL==table) {
        return new_element;
    }
    element=table;

    while((struct symbol_t *)NULL!=element->next) {
        element=element->next;
    }

    element->next=new_element;


    return table;
}

struct symbol_t *table_add_param(struct symbol_t *table, char *identifier, int param_index, short check) {
    struct symbol_t *element;
    struct symbol_t *new_element;

    if(table_lookup(table,identifier)!=(struct symbol_t *)NULL) {
        if(check) {
            fprintf(stderr,"Duplicate var %s.\n",identifier);
            exit(3);
        }
        table=table_remove_symbol(table,identifier);
    }

    new_element=(struct symbol_t *)malloc(sizeof(struct symbol_t));
    new_element->next=(struct symbol_t *)NULL;
    new_element->identifier=strdup(identifier);
    new_element->type=SYMBOL_TYPE_PARAM;
    new_element->param_index=param_index;

    if((struct symbol_t *)NULL==table) {
        return new_element;
    }
    element=table;

    while((struct symbol_t *)NULL!=element->next) {
        element=element->next;
    }

    element->next=new_element;

    return table;
}

struct symbol_t *table_lookup(struct symbol_t *table, char *identifier) {
    struct symbol_t *element;

    element=table;

    if((struct symbol_t *)NULL==table) {
        return (struct symbol_t *)NULL;
    }

    if(strcmp(element->identifier,identifier)==0) {
        return element;
    }

    while((struct symbol_t *)NULL!=element->next) {
        element=element->next;
        if(strcmp(element->identifier,identifier)==0) {
            return element;
        }
    }

    return (struct symbol_t *)NULL;
}

struct symbol_t *table_lookup_sublists(struct symbol_t *table, char *identifier) {
    struct symbol_t *element;
    struct symbol_t *sub_list_element;

    element=table;

    if((struct symbol_t *)NULL==table) {
        return (struct symbol_t *)NULL;
    }

    do {
        if(element->type == SYMBOL_TYPE_STRUCT) {
            sub_list_element=table_lookup(element->sublist, identifier);

            if (sub_list_element != (struct symbol_t *)NULL) {
                return sub_list_element;
            }
        }
    } while((element=element->next) != (struct symbol_t *)NULL);

    return (struct symbol_t *)NULL;
}

struct symbol_t *table_check_lookup_struct_sublist(struct symbol_t *table, char *identifier) {
    check_struct(table, identifier);
    return table_lookup(table, identifier)->sublist;
}

struct symbol_t *table_merge(struct symbol_t *table, struct symbol_t *to_add, short check) {
    struct symbol_t *element;
    struct symbol_t *new_table=clone_table(table);

    element=to_add;
    while(element!=(struct symbol_t *)NULL) {
        if(element->type==SYMBOL_TYPE_STRUCT) {
            new_table=table_add_struct_with_fields(new_table,element->sublist, NULL, element->identifier,element->type,check, NULL, element->stack_offset);
        } else if(element->param_index!=-1) {
			new_table=table_add_param(new_table,element->identifier,element->param_index, check);
		} else {
            new_table=table_add_symbol_with_startreg(new_table,element->identifier,element->type,check, element->start_reg, element->stack_offset);
        }
        element=element->next;
    }

    return new_table;
}

struct symbol_t *table_merge_as_type(struct symbol_t *table, struct symbol_t *to_add, char* start_reg, short type, short check) {
    struct symbol_t *element;
    struct symbol_t *new_table=clone_table(table);

    element=to_add;
    while(element!=(struct symbol_t *)NULL) {
        new_table=table_add_symbol_with_startreg(new_table,element->identifier,type,check, start_reg, element->stack_offset);
        element=element->next;
    }

    return new_table;
}

struct symbol_t *table_remove_symbol(struct symbol_t *table, char *identifier) {
    struct symbol_t *element;
    struct symbol_t *previous_element;
    struct symbol_t *new_element;

    if((struct symbol_t *)NULL==table) {
        return table;
    }

    previous_element=(struct symbol_t *)NULL;
    element=table;

    while((struct symbol_t *)NULL!=element) {
        if(strcmp(element->identifier,identifier)==0) {
            if((struct symbol_t *)NULL==previous_element) {
                new_element=element->next;
            }
            else {
                previous_element->next=element->next;
                new_element=table;
            }
            (void)free(element->identifier);
            (void)free(element);
            return new_element;
        }
        previous_element=element;
        element=element->next;
    }

    return table;
}

void check_variable(struct symbol_t *table, char *identifier) {
    struct symbol_t *element=table_lookup(table,identifier);
    if(element!=(struct symbol_t *)NULL) {
        if(element->type!=SYMBOL_TYPE_VAR && element->type!=SYMBOL_TYPE_PARAM) {
            fprintf(stderr,"Identifier %s not a variable or parameter.\n",identifier);
            exit(3);
        }
    }
    else {
        fprintf(stderr,"Unknown identifier %s.\n",identifier);
        exit(3);
    }
}

void check_struct(struct symbol_t *table, char *identifier) {
    struct symbol_t *element=table_lookup(table,identifier);
    if(element!=(struct symbol_t *)NULL) {
        if(element->type!=SYMBOL_TYPE_STRUCT) {
            fprintf(stderr,"Identifier %s not a struct.\n",identifier);
            exit(3);
        }
    }
    else {
        fprintf(stderr,"Unknown identifier %s.\n",identifier);
        exit(3);
    }
}

void check_field(struct symbol_t *table, char *identifier) {
    struct symbol_t *element=table_lookup_sublists(table,identifier);
    if(element!=(struct symbol_t *)NULL) {
        if(element->type!=SYMBOL_TYPE_FIELD) {
            fprintf(stderr,"Identifier %s not a field.\n",identifier);
            exit(3);
        }
    }
    else {
        fprintf(stderr,"Unknown identifier %s.\n",identifier);
        exit(3);
    }
}


void print_table(struct symbol_t *table, char *init, short show_type) {
    struct symbol_t *element;
    struct symbol_t *sub_element;

    printf("%s\n", init);

    element=table;
    while(element!=(struct symbol_t *)NULL) {

        if (show_type) {
            printf("%i_", element->type);
        }

        if(element->type==SYMBOL_TYPE_STRUCT) {

            printf("%s: ", element->identifier);

            sub_element=element->sublist;

            while(sub_element!=(struct symbol_t *)NULL) {

                if (show_type) {
                    printf("%i_", sub_element->type);
                }

                printf("%s - ", sub_element->identifier);

                sub_element = sub_element->next;

            }

        } else {

            printf("%s", element->identifier);

        }
        printf("\n");

        element=element->next;

    }
    printf("\n");

}

