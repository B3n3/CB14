#ifndef _CODE_GEN_H_
#define _CODE_GEN_H_

void function_header(char *name);
char *get_next_reg(char *name, int skip_reg);
char *get_param_reg(long number);
void ret(void);
void move(char *src, char *dest);

#endif /* _CODE_GEN_H_ */

