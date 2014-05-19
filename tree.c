#include <stdlib.h>
#include <stdio.h>

#include "tree.h"
#include "code_gen.h"

/* new_node: create "standard node" with one or two children and
 * given operation
 */
treenode *new_node(int op, treenode *left, treenode *right) {
	treenode *new=(treenode *)malloc(sizeof(treenode));

#ifdef DEBUG
	printf("new_node: %i (%s)\n",op,rule_names[op]);
#endif

	new->kids[0]=left;
	new->kids[1]=right;
	new->op=op;
	new->name=(char *)NULL;

	return new;
}

/* new_node_value: create "standard node" with one or two children and
 * given operation and the given value
 */
treenode *new_node_value(int op, treenode *left, treenode *right, long value, int param) {
	treenode *new=(treenode *)malloc(sizeof(treenode));

#ifdef DEBUG
	printf("new_node: %i (%s)\n",op,rule_names[op]);
#endif

	new->kids[0]=left;
	new->kids[1]=right;
	new->op=op;
	new->name=(char *)NULL;
	new->value=value;
	new->param_index=param;

	return new;
}

/* new_leaf: create leaf - node with no children */
treenode *new_leaf(int op) {
	treenode *new=(treenode *)malloc(sizeof(treenode));
	
#ifdef DEBUG
	printf("new_leaf: %i (%s)\n",op,rule_names[op]);
#endif

	new->kids[0]=(treenode *)NULL;
	new->kids[1]=(treenode *)NULL;
	new->op=op;
	new->name=(char *)NULL;

	return new;
}

/* new_named_leaf: create leaf with name (used for identifier or
 * value of number)
 */
treenode *new_named_leaf(int op, char *name) {
	treenode *new=(treenode *)malloc(sizeof(treenode));
	
#ifdef DEBUG
	printf("new_named_leaf: %i (%s), %s\n",op,rule_names[op],name);
#endif

	new->kids[0]=(treenode *)NULL;
	new->kids[1]=(treenode *)NULL;
	new->op=op;
	new->name=name;

	return new;
}

/* new_named_leaf_value: create leaf with name (used for identifier or
 * value of number)
 */
treenode *new_named_leaf_value(int op, char *name, long value, int param) {
	treenode *new=(treenode *)malloc(sizeof(treenode));
	
#ifdef DEBUG
	printf("new_named_leaf_value: %i (%s), %s, %li\n",op,rule_names[op],name,value);
#endif

	new->kids[0]=(treenode *)NULL;
	new->kids[1]=(treenode *)NULL;
	new->op=op;
	new->name=name;
	new->value=value;
	new->param_index=param;

	return new;
}

/* new_named_node: create node with one or two children and a name (can be
 * used for storing a procedure's name)
 */
treenode *new_named_node(int op, treenode *left, treenode *right, char *name) {
	treenode *new=(treenode *)malloc(sizeof(treenode));
	
#ifdef DEBUG
	printf("new_named_node: %i (%s), %s\n",op,rule_names[op],name);
#endif
	
	new->kids[0]=left;
	new->kids[1]=right;
	new->op=op;
	new->name=name;

	return new;
}

void write_indent(int indent) {
	int a;
	for(a=0;a<indent;a++) {
		printf("|");
	}
}

/* write_tree: display the tree generated by the attributed grammar; this tree willk
 * be traversed by iburg
 */
void write_tree(treenode *node, int indent) {
	write_indent(indent);
	printf("%s, %s, %s\n",rule_names[node->op],node->name,node->reg);
	if(node->kids[0]!=(treenode *)NULL || node->kids[1]!=(treenode *)NULL) {
		if(node->kids[0]!=(treenode *)NULL) {
			write_tree(node->kids[0], indent+1);
		}
		if(node->kids[1]!=(treenode *)NULL) {
			write_tree(node->kids[1], indent+1);
		}
	}
}

treenode *new_number_leaf(long value) {
	treenode *node;

        if(value==0) {
		node=new_leaf(OP_Zero);
	}
	else if(value==1) {
		node=new_leaf(OP_One);
	}
	else {
		node=new_leaf(OP_Number);
        }

	node->value=value;

	return node;
}

