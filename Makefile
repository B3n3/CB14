all: gesamt

scanner.c: oxout.l
	flex -oscanner.c oxout.l

scanner.o: scanner.c parser.h symbol_table.h
	gcc -g -c -ansi -pedantic scanner.c -D_GNU_SOURCE

gesamt: scanner.o parser.o symbol_table.o code_gen.o tree.o code.o
	gcc -o gesamt symbol_table.o scanner.o parser.o code_gen.o tree.o code.o -lfl

tree.o: tree.c tree.h
	gcc -g -c -ansi -pedantic -Wall tree.c

code_gen.o: code_gen.c code_gen.h
	gcc -g -c -ansi -pedantic -Wall code_gen.c -D_GNU_SOURCE

symbol_table.o: symbol_table.c symbol_table.h
	gcc -g -c -ansi -pedantic -Wall symbol_table.c -D_GNU_SOURCE

parser.o: parser.c symbol_table.h code_gen.h tree.h
	gcc -g -c -ansi -pedantic parser.c

parser.c parser.h: oxout.y
	yacc -d oxout.y -o parser.c

oxout.y oxout.l: parser.y scanner.lex
	ox parser.y scanner.lex

code.o: code.c tree.h
	gcc -g -ansi -c code.c

code.c: code.bfe
	bfe < code.bfe | iburg > code.c

clean:
	rm -f gesamt scanner.o scanner.c parser.h parser.c parser.o oxout.y oxout.l symbol_table.o code_gen.o tree.o code.c code.o testgesamt* a.out

