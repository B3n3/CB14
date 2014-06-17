#ifndef _CODE_GEN_H_
#define _CODE_GEN_H_

void function_header(char *name, int vars, int has_call, int num_param);
char *get_next_reg(char *name, int skip_reg);
char *get_next_param_reg(char *reg);
char *get_param_reg(long number);
void ret(void);
void move(char *src, char *dest);
void do_call(char *function, char *reg_return);
void prepare_call(char *function, char *reg_return);

/* extern char *function_name; */
extern int call, variables;
/* extern char *reg_return; */

#endif /* _CODE_GEN_H_ */

