%{
#include "pseudo_code.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>

void yyerror(const char *);
extern int yylex(void);
extern FILE *yyin;
extern int yylineno;

int var_count;
VarNode **variables;

int fn_count;
Function **functions;

Node *Block(Node *a, Node *b);
Node *Oper(int type, int n, ...);
Node *IntToNode(int val);
Node *StrToNode(char *s);
void AddFn(VarNode *var, int par_count, Node *body);
Node *VarToFnCall(VarNode *var);
Node *VarToNode(VarNode *var);
Node *NodeToParam(Node *a);
Node *MoreParam(Node *a, Node *b);
Node *InitializeArray(VarNode *a, Node *b);
Node *AddArrayElement(Node *a, Node *b);
Node *ParseInts(Node *a, Node *b, int c);
%}

%union{
    int val;
    char *s;
    Node *node;
    VarNode *var;
}

%error-verbose
%token SWAP READ PRINT IF ELSE ENDIF FUNC ENDFUNC FOR ENDFOR LEN THEN FROM TO DO NEWLINE NEQ EQ GEQ LEQ NOT ARRAY
%token <val> INT
%token <s> STR
%token <var> VAR 
%type <node> stmts stmt exp exps array ints
%type <val> params
%left '>' '<' ">=" "<=" "==" "!="
%left '+' '-'
%left '*' '/'
%right NEG
%%
prog : fn                                                       { ; }
    | fn NEWLINE                                                { ; }
    | fn NEWLINE prog                                           { ; }
    ;
fn  : FUNC VAR '(' params ')' NEWLINE stmts ENDFUNC             { AddFn($2, $4, $7); }
    ;
params :                                                        { $$ = 0; }
    | VAR                                                       { $$ = 1; }
    | params ',' VAR                                            { $$ = $1 + 1; }
    ;
stmts : stmt NEWLINE                                            { $$ = $1; }
    | stmts stmt NEWLINE                                        { $$ = Block($1, $2); }
    ;
stmt : VAR '=' exp                                              { $$ = Oper('=', 2, VarToNode($1), $3); }
	  | VAR '=' ints                                              { $$ = InitializeArray($1, $3); }
    | array '=' exp                                             { $$ = Oper('=', 2, $1, $3); }
    | PRINT exp                                                 { $$ = Oper(PRINT, 1, $2); }
    | SWAP '(' exp ',' exp ')'                                  { $$ = Oper(SWAP, 2, $3, $5); }
    | PRINT STR                                                 { $$ = Oper(PRINT, 1, StrToNode($2)); }
    | READ VAR                                                  { $$ = Oper(READ, 1, VarToNode($2)); }
    | IF exp THEN NEWLINE stmts ENDIF                           { $$ = Oper(IF, 2, $2, $5); }
    | IF exp THEN NEWLINE stmts ELSE NEWLINE stmts ENDIF        { $$ = Oper(ELSE, 3, $2, $5, $8); }
    | FOR VAR FROM exp TO exp DO NEWLINE stmts ENDFOR           { $$ = Oper(FOR, 4, VarToNode($2), $4, $6, $9); }
    | VAR '(' exps ')'                                          { $$ = Oper(FUNC, 2, VarToFnCall($1), $3); }
    ;
exp : INT                                                       { $$ = IntToNode($1); }
    | array 													{ $$ = $1; } 
    | VAR                                                       { $$ = VarToNode($1); } //we can't create new one every time
    | exp '+' exp                                               { $$ = Oper('+', 2, $1, $3); }
    | exp '-' exp                                               { $$ = Oper('-', 2, $1, $3); }
    | exp '/' exp                                               { $$ = Oper('/', 2, $1, $3); }
    | exp '*' exp                                               { $$ = Oper('*', 2, $1, $3); }
    | exp '>' exp                                               { $$ = Oper('>', 2, $1, $3); }
    | exp '<' exp                                               { $$ = Oper('<', 2, $1, $3); }
    | exp ">=" exp                                              { $$ = Oper(GEQ, 2, $1, $3); }
    | exp "<=" exp                                              { $$ = Oper(LEQ, 2, $1, $3); }
    | exp "==" exp                                              { $$ = Oper(EQ, 2, $1, $3); }
    | exp "!=" exp                                              { $$ = Oper(NEQ, 2, $1, $3); }
    | '(' exp ')'                                               { $$ = $2; }
    | '-' INT %prec NEG                                         { $$ = Oper(NEG, 1, IntToNode($2)); }
    | NOT exp %prec NEG                                         { $$ = Oper(NOT, 1, $2); }
    | VAR '(' exps ')'                                          { $$ = Oper(FUNC, 2, VarToFnCall($1), $3); }
    | LEN '(' VAR ')'                                           { $$ = Oper(LEN, 1, VarToNode($3)); }
    ;
exps :                                                          { $$ = NodeToParam(NULL); }
    | exp                                                       { $$ = NodeToParam($1); }
    | exps ',' exp                                              { $$ = MoreParam($1, $3); }
    ;
array : VAR '[' exp ']'											{ $$ = Oper(ARRAY, 2, VarToNode($1), $3); }
	;
ints : INT ',' ints                                             { $$ = ParseInts(IntToNode($1), $3, 1); }
     | INT ',' INT                                              { $$ = ParseInts(IntToNode($1), IntToNode($3), 0); }
     ;
%%
void init(void){
    var_count = 0;
    variables = NULL;
}

VarNode *NewVar(char *name){
    VarNode *v = malloc(sizeof(VarNode));
    assert(v != NULL);
    v->name = strdup(name);
    v->index = var_count++;
    v->len = 1;
    variables = realloc(variables, var_count * sizeof(void*));
    assert(variables != NULL);
    variables[var_count - 1] = v;
    return v;
}

VarNode *StrToVar(char *name){
    int i;
    for(i = 0; i < var_count; i++)
        if(strcasecmp(variables[i]->name, name) == 0) { 
            return variables[i];
        }   
    return NewVar(name);
}

Node *ParseInts(Node *a, Node *b, int c) {
	if(c) {                      
        return AddArrayElement(a, b);
    } else {
        return AddArrayElement(a, NodeToParam(b));
    }
}

Node *InitializeArray(VarNode *a, Node *b) {
  if(a->len != 1){
    printf("array %s has been already initialized\n", a->name);
    exit(0);    
  }
  int i;
  Node *block = NULL;
  int str_length = strlen(a->name) + 10;
  char *str = malloc(sizeof(char) * str_length); 
  for( i = 0; i < b->par.n; ++i) {
    sprintf(str, "%d%s", i, a->name);
    block = Block(block, Oper('=', 2, VarToNode(StrToVar(str)), b->par.params[b->par.n - i -1 ]));
  }
  a->len = b->par.n;
  free(str);
  return block;
}

Node *Block(Node *a, Node *b){ 
    if(a == NULL && b != NULL)
        return b;
    if(a != NULL && b == NULL)
        return a;
    if(a == NULL && b == NULL)
        return NULL;
    if(a->type == tBlock){
        a->block.n++;
        a->block.statements = realloc(a->block.statements, a->block.n * sizeof(void*));
        assert(a->block.statements != NULL);
        a->block.statements[a->block.n - 1] = b;
        return a;
    } else {
        Node *p = malloc(sizeof(Node));
        assert(p != NULL);
        p->type = tBlock;
        p->block.n = 2;
        p->block.statements = malloc(2 * sizeof(void*));        
        assert(p->block.statements != NULL);
        p->block.statements[0] = a;
        p->block.statements[1] = b;
        return p;
    }
}

Node *Oper(int type, int n, ...){ 
    va_list args;
    Node *p = malloc(sizeof(Node));
    assert(p != NULL);
    p->type = tOp;
    p->op.type = type;
    p->op.n = n;
    p->op.operands = malloc(n * sizeof(void*));
    assert(p->op.operands != NULL);
    va_start(args, n);
    int i;
    for(i = 0; i < n; i++)
        p->op.operands[i] = va_arg(args, Node*);
    va_end(args);
    return p;
}

Node *IntToNode(int val){ 
    Node *p = malloc(sizeof(Node));
    assert(p != NULL);
    p->type = tConst;
    p->con.value = val;
    return p;
}

Node *StrToNode(char *s){ 
    Node *p = malloc(sizeof(Node));
    assert(p != NULL);
    p->type = tString;
    p->str.s = s;
    return p;
}

void AddFn(VarNode *var, int par_cnt, Node *body){
    Function *fn = malloc(sizeof(Function));
    fn->name = strdup(var->name);
    fn->param_count = par_cnt;
    fn->body = body;
    fn->var_count = var_count;
    fn->variables = variables;
    init(); 
    fn_count++;
    functions = realloc(functions, fn_count * sizeof(void*));
    assert(functions != NULL);
    functions[fn_count - 1] = fn;
}

Node *VarToFnCall(VarNode *var){
    Node *p = malloc(sizeof(Node));
    p->type = tFnCall;
    p->var = var;
    return p;
}

Node *VarToNode(VarNode *var){
    Node *p = malloc(sizeof(Node));
    assert(p != NULL);
    p->type = tVar;
    p->var = var;
    return p;
}

Node *NodeToParam(Node *a){
    Node *p = malloc(sizeof(Node));
    assert(p != NULL);
    p->type = tParam;
    if(a == NULL){
        p->par.n = 0;
        p->par.params = NULL;
    } else {
        p->par.n = 1;
        p->par.params = malloc(sizeof(void*));
        assert(p->par.params != NULL);
        p->par.params[0] = a;
    }
    return p;
}

Node *MoreParam(Node *a, Node *b){
    int index = a->par.n++;
    a->par.params = realloc(a->par.params, a->par.n * sizeof(void*));
    assert(a->par.params != NULL);
    a->par.params[index] = b;
    return a;
}

Node *AddArrayElement(Node *a, Node *b) {
    int index = b->par.n++;
    b->par.params = realloc(b->par.params, b->par.n * sizeof(void*));
    assert(b->par.params != NULL);
    b->par.params[index] = a;
    return b;
}

void yyerror(const char *s){
    printf("error at line %d: %s\n", yylineno, s);
}

void FreeNode(Node *p){
    if(p == NULL)
        return;
    int i;
    switch(p->type){
        case tBlock: 
            for(i = 0; i < p->block.n; i++)
                FreeNode(p->block.statements[i]);
            free(p->block.statements);
            break;
        case tOp:
            for(i = 0; i < p->op.n; i++)
                FreeNode(p->op.operands[i]);
            free(p->op.operands);
            break;
        case tString:
            free(p->str.s);
            break;
        case tParam:
            for(i = 0; i < p->par.n; i++)
                FreeNode(p->par.params[i]);
            free(p->par.params);
        default: 
            break;
    }
    free(p);
}

void FreeVars(int var_count, VarNode **variables){
    int i;
    for(i = 0; i < var_count; i++){
        free(variables[i]->name);
        free(variables[i]);
    }
    var_count = 0;
    free(variables);
    variables = NULL;
}

void FreeFunction(Function *fn){
    FreeVars(fn->var_count, fn->variables);
    FreeNode(fn->body);
    free(fn);
}

void FreeFunctions(FnList *x){
    int i;
    for(i = 0; i < x->fn_count; i++)
        FreeFunction(x->functions[i]);
    free(x);
}
    
FnList *ReadFunctions(char *file_name, FnList *x){
    if(x){
        fn_count = x->fn_count;
        functions = x->functions;
    } else {
        fn_count = 0;
        functions = NULL;
        x = malloc(sizeof(FnList));
        assert(x != NULL);
    }   
    yyin = fopen(file_name, "r");
    if(yyin){
        init();
        yyparse();
    }
    x->fn_count = fn_count;
    x->functions = functions;
    return x;
}





