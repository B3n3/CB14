#include <stdio.h>
#include <string.h>
#include "code_gen.h"

int variables, call;
/* char *function_name; */
/* char *reg_return; */
extern char *saved_reg;

char *reg_names[]={"rax", "r10", "r11", "r9", "r8", "rcx", "rdx", "rsi", "rdi"};

void function_header(char *name, int vars, int has_call, int num_pars) {
	int a;

	variables = vars+(has_call ? num_pars : 0);
	printf("# setting call to %i\n", has_call);
	call = has_call;

	printf("\t.globl %s\n\t.type %s, @function\n%s:\n", name, name, name);
	printf("# %i %i %i %i\n",vars,has_call,num_pars,(has_call ? num_pars : 0));
	if(vars+(has_call ? num_pars : 0)>0) {
		printf("\tpushq %%rbp\n\tmovq %%rsp, %%rbp\n\tsubq $%i, %%rsp\n", 8*(vars+num_pars));
		if(num_pars>0 && has_call) {
			for(a=0;a<num_pars;a++) {
				printf("\tmovq %%%s, %i(%%rsp)\n",get_param_reg(a+1),8*(vars+num_pars-a-1));
			}
		}
	}
}

void prepare_call(char *function, char *reg_return) {
	int a;
	/* TODO don't save all registers */
	for(a=0;a<9;a++) {
		printf("\tpushq %%%s\n",reg_names[a]);
	}
}

void do_call(char *function, char *reg_return) {
	int a;
	/* TODO don't restore all registers */
	printf("\tcall %s\n", function);
	move("rax",reg_return);
	/* TODO return value? */
	for(a=8;a>=0;a--) {
		if(strcmp(reg_return,reg_names[a])) {
			printf("\tpopq %%%s\n",reg_names[a]);
		}
		else {
			printf("\taddq $8, %%rsp\n");
		}
	}
}

char *get_next_reg(char *name, int skip_reg) {
	int index, a;
	if(name==(char *)NULL) {
		index=0;
	}
	else {
		for(a=0;a<9;a++) {
			if(!strcmp(name,reg_names[a])) {
				index=a+1;
				break;
			}
		}
	}
	if(skip_reg) {
		index++;
	}
	if(index>8) {
		return saved_reg;
	}
	return reg_names[index];
}

char *get_next_param_reg(char *reg) {
	int a=1;
	while(1) {
		if(strcmp(get_param_reg(a),reg)==0) {
			return get_param_reg(a+1);
		}
		a++;
	}
}

char *get_param_reg(long number) {
	char *reg_names[]={"rdi", "rsi", "rdx", "rcx", "r8", "r9"};
	return reg_names[number-1];
}

void ret(void) {
	if(variables>0) {
		printf("\tleave\n");
	}
	printf("\tret\n");
}

void move(char *src, char *dst) {
	if(strcmp(src,dst)) {
		printf("\tmovq %%%s, %%%s\n",src,dst);
	}
}

