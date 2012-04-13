module lang::php::stats::Stats

import Set;
import String;
import List;
import lang::php::util::Utils;
import lang::php::ast::AbstractSyntax;
import lang::php::util::Corpus;

alias FetchResult = rel[str product, str version, loc fileloc, Expr call];
alias Corpus = rel[str product, str version, loc fileloc, Script scr];

public bool containsVV(Expr e) = size({ v | /v:var(Expr ev) := e }) > 0;
public bool containsVV(someExpr(Expr e)) = size({ v | /v:var(Expr ev) := e }) > 0;
public bool containsVV(noExpr()) = false;

public FetchResult gatherExprStats(Corpus corpus, str product, str version, list[Expr](Script) f) {
	rel[loc fileloc, Script scr] scriptsByLoc = corpus[product,version];
	FetchResult res = { };
	for (l <- scriptsByLoc.fileloc, s <- scriptsByLoc[l], e <- f(s)) {
		res = res + < product, version, l, e >;
	}
	return res;
}

// Gather information on uses of class constants where the class name is given using a variable-variable
public list[Expr] fetchClassConstUses(Script scr) = [ f | /f:fetchClassConst(_,_) := scr ];
public list[Expr] fetchClassConstUsesVVTarget(Script scr) = [ f | f:fetchClassConst(expr(_),_) <- fetchClassConstUses(scr) ];
public FetchResult gatherVVClassConsts(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchClassConstUsesVVTarget);

// Gather information on assignments where the assignment target contains a variable-variable
public list[Expr] fetchAssignUses(Script scr) = [ a | /a:assign(_,_) := scr ];
public list[Expr] fetchAssignUsesVVTarget(Script scr) = [ a | a:assign(Expr t,_) <- fetchAssignUses(scr), containsVV(t) ];
public FetchResult gatherVVAssigns(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchAssignUsesVVTarget);

// Gather information on assignment/op combos where the assignment target contains a variable-variable
public list[Expr] fetchAssignWOpUses(Script scr) = [ a | /a:assignWOp(_,_,_) := scr ];
public list[Expr] fetchAssignWOpUsesVVTarget(Script scr) = [ a | a:assignWOp(Expr t,_,_) <- fetchAssignWOpUses(scr), containsVV(t) ];
public FetchResult gatherVVAssignWOps(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchAssignWOpUsesVVTarget);

// Gather information on list assignments where the assignment target contains a variable-variable
public list[Expr] fetchListAssignUses(Script scr) = [ a | /a:listAssign(_,_) := scr ];
public list[Expr] fetchListAssignUsesVVTarget(Script scr) = [ a | a:listAssign(ll,_) <- fetchListAssignUses(scr), true in { containsVV(t) | t <- ll } ];
public FetchResult gatherVVListAssigns(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchListAssignUsesVVTarget);

// Gather information on reference assignments where the assignment target contains a variable-variable
public list[Expr] fetchRefAssignUses(Script scr) = [ a | /a:refAssign(_,_) := scr ];
public list[Expr] fetchRefAssignUsesVVTarget(Script scr) = [ a | a:refAssign(Expr t,_) <- fetchRefAssignUses(scr), containsVV(t) ];
public FetchResult gatherVVRefAssigns(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchRefAssignUsesVVTarget);
 
// Gather information on assignments where the assignment target contains a variable-variable
public list[Expr] fetchNewUses(Script scr) = [ f | /f:new(_,_) := scr ];
public list[Expr] fetchNewUsesVVClass(Script scr) = [ f | f:new(expr(_),_) <- fetchNewUses(scr) ];
public FetchResult gatherVVNews(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchNewUsesVVClass);

// Gather information on calls where the function to call is given through a variable-variable
public list[Expr] fetchCallUses(Script scr) = [ c | /c:call(_,_) := scr ];
public list[Expr] fetchCallUsesVVName(Script scr) = [ c | c:call(expr(_),_) <- fetchCallUses(scr) ];
public FetchResult gatherVVCalls(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchCallUsesVVName);

// Gather information on method calls where the method to call is given through a variable-variable
public list[Expr] fetchMethodCallUses(Script scr) = [ m | /m:methodCall(_,_,_) := scr ];
public list[Expr] fetchMethodCallUsesVVTarget(Script scr) = [ m | m:methodCall(_,expr(_),_) <- fetchMethodCallUses(scr) ];
public FetchResult gatherMethodVVCalls(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchMethodCallUsesVVTarget);

// Gather information on static calls where the static class and/or the static method is given as a variable-variable
public list[Expr] fetchStaticCallUses(Script scr) = [ m | /m:staticCall(_,_,_) := scr ];
public list[Expr] fetchStaticCallUsesVVMethod(Script scr) = [ m | m:staticCall(_,expr(_),_) <- fetchStaticCallUses(scr) ];
public list[Expr] fetchStaticCallUsesVVTarget(Script scr) = [ m | m:staticCall(expr(_),_,_) <- fetchStaticCallUses(scr) ];
public FetchResult gatherStaticVVCalls(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchStaticCallUsesVVMethod);
public FetchResult gatherStaticVVTargets(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchStaticCallUsesVVTarget);

// Gather information on includes with paths based on expressions
public list[Expr] fetchIncludeUses(Script scr) = [ i | /i:include(_,_) := scr ];
public list[Expr] fetchIncludeUsesVarPaths(Script scr) = [ i | i:include(Expr e,_) <- fetchIncludeUses(scr), scalar(_) !:= e ];
public FetchResult gatherIncludesWithVarPaths(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchIncludeUsesVarPaths);

// Gather information on property fetch expressions with the property name given as a variable-variable
public list[Expr] fetchPropertyFetchUses(Script scr) = [ f | /f:propertyFetch(_,_) := scr ];
public list[Expr] fetchPropertyFetchVVNames(Script scr) = [ f | f:propertyFetch(_,expr(_)) <- fetchPropertyFetchUses(scr) ];
public FetchResult gatherPropertyFetchesWithVarNames(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchPropertyFetchVVNames);

// Gather information on static property fetches where the static class and/or the static property name is given as a variable-variable
public list[Expr] fetchStaticPropertyUses(Script scr) = [ m | /m:fetchStaticProperty(_,_) := scr ];
public list[Expr] fetchStaticPropertyVVName(Script scr) = [ m | m:fetchStaticProperty(_,expr(_)) <- fetchStaticPropertyUses(scr) ];
public list[Expr] fetchStaticPropertyVVTarget(Script scr) = [ m | m:fetchStaticProperty(expr(_),_) <- fetchStaticPropertyUses(scr) ];
public FetchResult gatherStaticPropertyVVNames(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchStaticPropertyVVName);
public FetchResult gatherStaticPropertyVVTargets(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchStaticPropertyVVTarget);

// Gather variable-variable uses
public list[Expr] fetchVarUses(Script scr) = [ v | /v:var(_) := scr ];
public list[Expr] fetchVarUsesVV(Script scr) = [ v | v:var(expr(_)) <- fetchVarUses(scr) ];
public FetchResult gatherVarVarUses(Corpus corpus, str product, str version) = gatherExprStats(corpus, product, version, fetchVarUsesVV);

public map[str,int] featureCounts(Corpus corpus, str product, str version) {
	int getCount(FetchResult fr) = size(fr[product,version]);
	map[str,int] counts = ( );
	
	counts["class consts with variable class name"] = getCount(gatherVVClassConsts(corpus, product, version));
	counts["assignments into variable-variables"] = getCount(gatherVVAssigns(corpus, product, version));
	counts["assignments w/ops into variable-variables"] = getCount(gatherVVAssignWOps(corpus, product, version));
	counts["list assignments into variable-variables"] = getCount(gatherVVListAssigns(corpus, product, version));
	counts["ref assignments into variable-variables"] = getCount(gatherVVRefAssigns(corpus, product, version));
	counts["object creation with variable class name"] = getCount(gatherVVNews(corpus, product, version));
	counts["calls of variable function names"] = getCount(gatherVVCalls(corpus, product, version));
	counts["calls of variable method names"] = getCount(gatherMethodVVCalls(corpus, product, version));
	counts["calls of static methods with variable names"] = getCount(gatherStaticVVCalls(corpus, product, version));
	counts["calls of static methods with variable targets"] = getCount(gatherStaticVVTargets(corpus, product, version));
	counts["includes with non-literal paths"] = getCount(gatherIncludesWithVarPaths(corpus, product, version));
	counts["fetches of properties with variable names"] = getCount(gatherPropertyFetchesWithVarNames(corpus, product, version));
	counts["fetches of static properties with variable names"] = getCount(gatherStaticPropertyVVNames(corpus, product, version));
	counts["fetches of static properties with variable targets"] = getCount(gatherStaticPropertyVVTargets(corpus, product, version));
	counts["uses of variable-variables (including the above)"] = getCount(gatherVarVarUses(corpus, product, version));
	
	return counts;

}

public tuple[map[str,int] featureCounts, map[str,int] exprCounts, map[str,int] stmtCounts] gatherCounts(Corpus corpus, str product, str version) {
	fc = featureCounts(corpus, product, version);
	sc = stmtCounts(corpus, product, version);
	ec = exprCounts(corpus, product, version);
	return < fc, ec, sc >;
}

public map[tuple[str product, str version], tuple[map[str,int] featureCounts, map[str,int] exprCounts, map[str,int] stmtCounts]] gatherAllCounts() {
	map[tuple[str product, str version], tuple[map[str,int] featureCounts, map[str,int] exprCounts, map[str,int] stmtCounts]] res = ( );
	for (p <- getProducts(), v <- getVersions(p)) {
		c = loadProduct(p,v);
		res[<p,v>] = gatherCounts(c,p,v);
	}
	for (p <- getPlugins(), v <- getPluginVersions(p)) {
		c = loadPlugin(p,v);
		res[<p,v>] = gatherCounts(c,p,v);
	}
	return res;
}

public map[tuple[str product, str version], tuple[map[str,int] featureCounts, map[str,int] exprCounts, map[str,int] stmtCounts]] gatherMWCounts() {
	map[tuple[str product, str version], tuple[map[str,int] featureCounts, map[str,int] exprCounts, map[str,int] stmtCounts]] res = ( );
	for (v <- getMWVersions()) {
		c = loadMWVersion(v);
		res[<"MediaWiki",v>] = gatherCounts(c,"MediaWiki",v);
	}
	return res;
}

// Gather statement counts
public map[str,int] stmtCounts(Corpus corpus, str product, str version) {
	map[str,int] counts = ( );
	rel[loc fileloc, Script scr] scriptsByLoc = corpus[product,version];
	for (l <- scriptsByLoc.fileloc, s <- scriptsByLoc[l]) {
		visit(s) {
			case Stmt stmt : {
				stmtKey = getStmtKey(stmt);
				if (stmtKey in counts)
					counts[stmtKey] += 1;
				else
					counts[stmtKey] = 1;
			}
		}
	} 
	return counts;
}

// Gather expression counts
public map[str,int] exprCounts(Corpus corpus, str product, str version) {
	map[str,int] counts = ( );
	rel[loc fileloc, Script scr] scriptsByLoc = corpus[product,version];
	for (l <- scriptsByLoc.fileloc, s <- scriptsByLoc[l]) {
		visit(s) {
			case Expr expr : {
				exprKey = getExprKey(expr);
				if (exprKey in counts)
					counts[exprKey] += 1;
				else
					counts[exprKey] = 1;
			}
		}
	} 
	return counts;
}

public str getExprKey(Expr::array(_)) = "array";
public str getExprKey(fetchArrayDim(_,_)) = "fetch array dim";
public str getExprKey(fetchClassConst(_,_)) = "fetch class const";
public str getExprKey(assign(_,_)) = "assign";
public str getExprKey(assignWOp(_,_,Op op)) = "assign with operation: <getOpKey(op)>";
public str getExprKey(listAssign(_,_)) = "list assign";
public str getExprKey(refAssign(_,_)) = "ref assign";
public str getExprKey(binaryOperation(_,_,Op op)) = "binary operation: <getOpKey(op)>";
public str getExprKey(unaryOperation(_,Op op)) = "unary operation: <getOpKey(op)>";
public str getExprKey(new(_,_)) = "new";
public str getExprKey(classConst(_)) = "class const";
public str getExprKey(cast(CastType ct,_)) = "cast to <getCastTypeKey(ct)>";
public str getExprKey(clone(_)) = "clone";
public str getExprKey(closure(_,_,_,_,_)) = "closure";
public str getExprKey(fetchConst(_)) = "fetch const";
public str getExprKey(empty(_)) = "empty";
public str getExprKey(suppress(_)) = "suppress";
public str getExprKey(eval(_)) = "eval";
public str getExprKey(exit(_)) = "exit";
public str getExprKey(call(_,_)) = "call";
public str getExprKey(methodCall(_,_,_)) = "method call";
public str getExprKey(staticCall(_,_,_)) = "static call";
public str getExprKey(Expr::include(_,_)) = "include";
public str getExprKey(instanceOf(_,_)) = "instanceOf";
public str getExprKey(isSet(_)) = "isSet";
public str getExprKey(print(_)) = "print";
public str getExprKey(propertyFetch(_,_)) = "property fetch";
public str getExprKey(shellExec(_)) = "shell exec";
public str getExprKey(ternary(_,_,_)) = "exit";
public str getExprKey(fetchStaticProperty(_,_)) = "fetch static property";
public str getExprKey(scalar(_)) = "scalar";
public str getExprKey(var(_)) = "var";

public str getOpKey(bitwiseAnd()) = "bitwise and";
public str getOpKey(bitwiseOr()) = "bitwise or";
public str getOpKey(bitwiseXor()) = "bitwise xor";
public str getOpKey(concat()) = "concat";
public str getOpKey(div()) = "div";
public str getOpKey(minus()) = "minus";
public str getOpKey(\mod()) = "mod";
public str getOpKey(mul()) = "mul";
public str getOpKey(plus()) = "plus";
public str getOpKey(rightShift()) = "right shift";
public str getOpKey(leftShift()) = "left shift";
public str getOpKey(booleanAnd()) = "boolean and";
public str getOpKey(booleanOr()) = "boolean or";
public str getOpKey(booleanNot()) = "boolean not";
public str getOpKey(bitwiseNot()) = "bitwise not";
public str getOpKey(gt()) = "gt";
public str getOpKey(geq()) = "geq";
public str getOpKey(logicalAnd()) = "logical and";
public str getOpKey(logicalOr()) = "logical or";
public str getOpKey(logicalXor()) = "logical xor";
public str getOpKey(notEqual()) = "not equal";
public str getOpKey(notIdentical()) = "not identical";
public str getOpKey(postDec()) = "post dec";
public str getOpKey(preDec()) = "pre dec";
public str getOpKey(postInc()) = "post inc";
public str getOpKey(preInc()) = "pre inc";
public str getOpKey(lt()) = "lt";
public str getOpKey(leq()) = "leq";
public str getOpKey(unaryPlus()) = "unary plus";
public str getOpKey(unaryMinus()) = "unary minus";
public str getOpKey(equal()) = "equal";
public str getOpKey(identical()) = "identical";

public str getCastTypeKey(\int()) = "int";
public str getCastTypeKey(\bool()) = "bool";
public str getCastTypeKey(CastType::float()) = "float";
public str getCastTypeKey(CastType::string()) = "string";
public str getCastTypeKey(CastType::array()) = "array";
public str getCastTypeKey(object()) = "object";
public str getCastTypeKey(CastType::unset()) = "unset";

public str getStmtKey(\break(_)) = "break";
public str getStmtKey(classDef(_)) = "class def";
public str getStmtKey(Stmt::const(_)) = "const";
public str getStmtKey(\continue(_)) = "continue";
public str getStmtKey(declare(_,_)) = "declare";
public str getStmtKey(do(_,_)) = "do";
public str getStmtKey(echo(_)) = "echo";
public str getStmtKey(exprstmt(_)) = "expression statement (chain rule)";
public str getStmtKey(\for(_,_,_,_)) = "for";
public str getStmtKey(foreach(_,_,_,_,_)) = "foreach";
public str getStmtKey(function(_,_,_,_)) = "function def";
public str getStmtKey(global(_)) = "global";
public str getStmtKey(goto(_)) = "goto";
public str getStmtKey(haltCompiler(_)) = "halt compiler";
public str getStmtKey(\if(_,_,_,_)) = "if";
public str getStmtKey(inlineHTML(_)) = "inline HTML";
public str getStmtKey(interfaceDef(_)) = "interface def";
public str getStmtKey(traitDef(_)) = "trait def";
public str getStmtKey(label(_)) = "label";
public str getStmtKey(namespace(_,_)) = "namespace";
public str getStmtKey(\return(_)) = "return";
public str getStmtKey(Stmt::static(_)) = "static";
public str getStmtKey(\switch(_,_)) = "switch";
public str getStmtKey(\throw(_)) = "throw";
public str getStmtKey(tryCatch(_,_)) = "try/catch";
public str getStmtKey(Stmt::unset(_)) = "unset";
public str getStmtKey(Stmt::use(_)) = "use";
public str getStmtKey(\while(_,_)) = "while def";
