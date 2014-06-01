#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#define SYMBOL_TYPE_FIELD 1
#define SYMBOL_TYPE_VAR 2
#define SYMBOL_TYPE_STRUCT 3
#define SYMBOL_TYPE_PARAM 4

struct symbol_t {
    char *identifier;
    struct symbol_t *next;
    struct symbol_t *sublist;
    short type;
    int stack_offset;
    int param_index; /* -1 if not a parameter */
};

struct symbol_t *clone_table(struct symbol_t *table);
struct symbol_t *new_table(void);
struct symbol_t *table_add_symbol(struct symbol_t *table, char *identifier, short type, short check, int stack_offset);
struct symbol_t *table_add_struct_with_fields(struct symbol_t *table, struct symbol_t* sublist, struct symbol_t* super_table, char *identifier, short type, short check, int stack_offset);
struct symbol_t *table_add_param(struct symbol_t *table, char *identifier, int param_index, short check);
struct symbol_t *table_lookup(struct symbol_t *table, char *identifier);
struct symbol_t *table_lookup_sublists(struct symbol_t *table, char *identifier);
struct symbol_t *table_check_lookup_struct_sublist(struct symbol_t *table, char *identifier);
struct symbol_t *table_remove_symbol(struct symbol_t *table, char *identifier);
struct symbol_t *table_merge(struct symbol_t *table, struct symbol_t *to_add, short check);
struct symbol_t *table_merge_as_type(struct symbol_t *table, struct symbol_t *to_add, short type, short check);
void check_variable(struct symbol_t *table, char *identifier);
void check_struct(struct symbol_t *table, char *identifier);
void check_field(struct symbol_t *table, char *identifier);
void print_table(struct symbol_t *table, char *init, short show_type);

#endif /* SYMBOL_TABLE_H */

