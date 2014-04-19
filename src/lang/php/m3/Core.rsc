@doc{
Synopsis: extends the M3 [$analysis/m3/Core] with Php specific concepts 

Description: 

For a quick start, go find [createM3FromEclipseProject].
}
module lang::php::m3::Core

import lang::php::m3::AST;

extend analysis::m3::Core;

import analysis::graphs::Graph;
import analysis::m3::Registry;

import lang::php::ast::AbstractSyntax;
import lang::php::util::Utils;
import lang::php::util::System;

import IO;
import String;
import Relation;
import Set;
import String;
import Map;
import Node;
import List;
import Traversal;

import util::FileSystem;
import demo::common::Crawl;

alias M3Collection = map[loc fileloc, M3 model];

anno rel[loc from, loc to] M3@extends;      // classes extending classes and interfaces extending interfaces
anno rel[loc from, loc to] M3@implements;   // classes implementing interfaces
anno rel[loc pos, str phpDoc] M3@phpDoc;    // Multiline php comments /** ... */

public loc globalNamespace = |php+namespace:///|;

public M3 composePhpM3(loc id, set[M3] models) {
  m = composeM3(id, models);
  
  m@extends 	= {*model@extends 		| model <- models};
  m@implements 	= {*model@implements 	| model <- models};
  m@annotations = {*model@annotations 	| model <- models};
  m@phpDoc 		= {*model@phpDoc 		| model <- models};
  
  return m;
}

// hack to make decls work on (all) nodes; visit does not recognize the annotations on specific nodes when visiting `node`
public anno loc node@at;
public anno loc node@decl;
public anno str node@phpdoc;
public anno node node@scope;

@doc{
Synopsis: globs for jars, class files and java files in a directory and tries to compile all source files into an [$analysis/m3] model
}
public M3Collection createM3sFromDirectory(loc l) {
	if (!isDirectory(l)) throw AssertionFailed("Location <l> must be a directory");
    
    System system = loadPHPFiles(l);
    return getM3CollectionForSystem(system);
}

public M3Collection getM3CollectionForSystem(System system) {
    M3Collection m3s = (l:m3(l) | l <- system); // for each file, create an empty m3
	
	// fill declarations
	for (l <- system) {
		visit (system[l]) {
			case node n: {
				if ( (n@at)? && (n@decl)? ) {
					m3s[l]@declarations += {<n@decl, n@at>};
					m3s[l]@names += {<n@decl.file, n@decl>};
				}
			}
	   	}
	   	// if there are no namespaces, add global namespace
	   	if (isEmpty({ ns | <ns,_> <- m3s[l]@declarations, isNamespace(ns) })) {
			m3s[l]@declarations += {<globalNamespace, l>};
	   	}
	}	
	
	// fill containtment with declarations
	for (l <- system) {
		m3s[l] = fillContainment(m3s[l], system[l]);
	}	
	
	
	// fill extends and implements, by trying to look up class names
	for (l <- system) {
		visit (system[l]) {
			case c:class(_,_,someName(name(name)),_,_): 
			{
				set[loc] possibleExtends = getPossibleClassesInM3(m3s[l], name);
				m3s[l]@extends += {<c@decl, ext> | ext <- possibleExtends};
				fail; // continue this visit, a class can have extends and implements.
			}
			case c:class(_,_,_,list[Name] implements,_):
			{
				for (name <- [n | name(n) <- implements]) {
					set[loc] possibleImplements = getPossibleInterfacesInM3(m3s[l], name);
					m3s[l]@implements += {<c@decl, impl> | impl <- possibleImplements};
				}
			}	
	   	}
	}	
	
   	
   	// fill modifiers for classes, class fields and class methods
	for (l <- system) {
	   	visit (system[l]) {
   			case n:class(_,set[Modifier] mfs,_,_,_): 				m3s[l]@modifiers += {<n@decl, mf> | mf <- mfs};
			case n:property(set[Modifier] mfs,list[Property] ps): 	m3s[l]@modifiers += {<p@decl, mf> | mf <- mfs, p <- ps };	
			case n:method(_,set[Modifier] mfs,_,_,_):				m3s[l]@modifiers += {<n@decl, mf> | mf <- mfs};
   		}
   	}
   	 
 	// fill documentation, defined as @phpdoc
	for (l <- system) {
	  visit (system[l]) {
			case node n:
				if ( (n@decl)? && (n@phpdoc)? ) 
					m3s[l]@phpDoc += {<n@decl, n@phpdoc>};
		}	
	}

	// fill containment, for now only for compilationMethod, Class/Interface/Trait, Method, field
	for (l <- system) {
		visit (system[l]) {
			case _: ;
		}
	}

	// fill uses, first for class instantiations
	// also fill types relation
	for (l <- system) {
		visit (system[l]) {
			/* new(NameOrExpr className, list[ActualParameter] parameters) */
			case n:new(c:expr(className), params): {
				println("Warning: dynamic class instantiation is not supported");
				m3s[l]@uses += {<n@at, emptyId>};
			}
			case n:new(name(c:name(className)), params): {
				set[loc] classDecls = findClassDeclaration(m3s[l], className);
				m3s[l]@uses += {<c@at, decl> | decl <- classDecls};
				// fill types
			}
		}
	}

	// fill uses, now for other elements	
	for (l <- system) {
		visit (system[l]) {
			/* example: $target->name; || $target->$expr; */
			case propertyFetch(target, property): {
				m3s[l]@uses += {<property@at, decl> | decl <- {}};
				//m3s[l]@uses += {<property@at, decl> | decl <- findClassPoperty(m3s[l], target, property)};
			} 
		}
	}   	
	return m3s;
}

public M3 addUsageForNode(M3 m3, Expr elm) {
	set decl = "";
	m3@uses += {<elm@at, decl> | decl <- decls};

}

@doc { recursively fill containment }
public M3 fillContainment(M3 m3, Script script) {
	// use this to test one m3
	if (m3.id != |file:///Users/ruud/test/containment.php| &&
		m3.id != |file:///Users/ruud/test/containment2.php|) {
		iprintln("<m3.id> skipped");
		return m3;
	}
	loc currNs = globalNamespace;
	top-down-break visit (script.body) {
		case Stmt stmt: m3 = fillContainment(m3, stmt, currNs);
	}
	// this commented line kills the script
   	//return m3;
}

public M3 fillContainment(M3 m3, Stmt statement, loc currNs) {
	top-down-break visit (statement) {
		case ns:namespace(_,body): {
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, ns@decl);
		}
		case ns:namespaceHeader(_): {
			// set the current namespace to this one.
			currNs = ns@decl;
			fail; // continue the visit
		}
		case c:class(_,_,_,_,body): {
			println("<currNs> \> <c@decl>");
			m3@containment += { <currNs, c@decl> };
			
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, c@decl, currNs);
		}
		case i:interface(_,_,body): {
			println("<currNs> \> <i@decl>");
			m3@containment += { <currNs, i@decl> };
			
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, i@decl, currNs);
		}
		case t:trait(_,body): {
			println("<currNs> \> <t@decl>");
			m3@containment += { <currNs, t@decl> };
			
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, t@decl, currNs);
		}
		case f:function(_,_,params,body): { 
			println("<currNs> \> <f@decl>");
			m3@containment += { <currNs, f@decl> };
			
			for (p <- params)
				m3@containment += { <f@decl, p@decl> };
				
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, currNs);
		}
		case e:exprstmt(expr): {
			// variables are not handled correctly yet.
			loc ref = (statement@decl)? ? statement@decl : currNs;
			m3 = fillContainment(m3, expr, ref, currNs);
		}
	}
	return m3;
}

public M3 fillContainment(M3 m3, ClassItem c, loc declRef, loc currNs) {
	top-down-break visit (c) {
		case property(_,ps): {
			for (p <- ps) {	
				println("<declRef> \> <p@decl>");
				m3@containment += { <declRef, p@decl> };
			}
		}
		case constCI(cs): {
			for (c_ <- cs) {
				println("<declRef> \> <c_@decl>");
				m3@containment += { <declRef, c_@decl> };
			}
		}
		case m:method(_,_,_,params,body): {
			println("<declRef> \> <m@decl>");
			m3@containment += { <declRef, m@decl> };
			
			for (p <- params)
				m3@containment += { <m@decl, p@decl> };
				
			for (stmt <- body)
				m3 = fillContainment(m3, stmt, currNs);
		}
	}
	return m3;
}

public M3 fillContainment(M3 m3, Expr e, loc declRef, loc currNs) {
	top-down-break visit (e) {
		case v:var(_): {
			println("<declRef> \> <v@decl>");
			m3@containment += { <declRef, v@decl> };
		}
	}
	
	return m3;
}

@doc {	search in declarations for classNames }
public set[loc] findClassDeclaration(M3 m3, str className) {
	// todo check name space
	set[loc] decls = { decl | <name,decl> <- m3@names, name == className, isClass(decl)};
	if (isEmpty(decls)) {
		decls += |php+unresolvedClass:///-/| + className;
	}
	return decls;
}
public loc findClassPoperty(M3 m3, target, property) {
	// resolve the class type of target
	// resolve the property declaration	
	// todo: this is a simple implementation which only handles $var->prop;
	
}

public set[loc] findVarInM3UsingScopeInfo(M3 m3, str name, Expr elm) {
	loc possibleVar = createPossibleDeclaration(elm@scope, name);
	set[loc] declaredVars = { l | <l,at> <- m3@declarations, isVariable(l), possibleVar == l };
	
	if (isEmpty(declaredVars)) {
		possibleVar.scheme = "php+unknownVariable";
		return {possibleVar};
	} else {
		return declaredVars;
	}
}
 
public set[loc] getPossibleClassesInM3(M3 m3, str className) {
	set[loc] locs = {};
	
	for (name <- m3@names) 
		if (name.simpleName == className && isClass(name.qualifiedName))
			locs += name.qualifiedName;
				
	return isEmpty(locs) ? {|php+unknownClass:///| + className} : locs;
}
public set[loc] getPossibleInterfacesInM3(M3 m3, str className) {
	set[loc] locs = {};
	
	for (name <- m3@names) 
		if (name.simpleName == className && isInterface(name.qualifiedName))
			locs += name.qualifiedName;
				
	return isEmpty(locs) ? {|php+unknownInterface:///| + className} : locs;
}

public set[loc] getPossibleClassesInSystem(M3Collection m3map, str className) {
	set[loc] locs = {};
	set[M3] m3s = {m3map[m3] | m3 <- m3map};
	
	for (l <- m3map) 
		for (name <- m3map[l]@names) 
			if (name.simpleName == className && isClass(name.qualifiedName))
				locs += name.qualifiedName;
				
	return isEmpty(locs) ? {|php+unknownClass:///| + className} : locs;
}

public bool isNamespace(loc entity) = entity.scheme == "php+namespace";
public bool isClass(loc entity) = entity.scheme == "php+class";
public bool isInterface(loc entity) = entity.scheme == "php+interface";
public bool isTrait(loc entity) = entity.scheme == "php+trait";
public bool isMethod(loc entity) = entity.scheme == "php+method";
public bool isFunction(loc entity) = entity.scheme == "php+function";
public bool isParameter(loc entity) = entity.scheme == "php+parameter";
public bool isVariable(loc entity) = entity.scheme == "php+variable";
public bool isField(loc entity) = entity.scheme == "php+field";

@memo public set[loc] namespaces(M3 m) = {e | e <- m@declarations<name>, isNamespace(e)};
@memo public set[loc] classes(M3 m) =  {e | e <- m@declarations<name>, isClass(e)};
@memo public set[loc] interfaces(M3 m) =  {e | e <- m@declarations<name>, isInterface(e)};
@memo public set[loc] traits(M3 m) = {e | e <- m@declarations<name>, isTrait(e)};
@memo public set[loc] functions(M3 m)  = {e | e <- m@declarations<name>, isFunction(e)};
@memo public set[loc] variables(M3 m) = {e | e <- m@declarations<name>, isVariable(e)};
@memo public set[loc] methods(M3 m) = {e | e <- m@declarations<name>, isMethod(e)};
@memo public set[loc] parameters(M3 m)  = {e | e <- m@declarations<name>, isParameter(e)};
@memo public set[loc] fields(M3 m) = {e | e <- m@declarations<name>, isField(e)};

public set[loc] elements(M3 m, loc parent) = { e | <parent, e> <- m@containment };

@memo public set[loc] fields(M3 m, loc class) = { e | e <- elements(m, class), isField(e) };
@memo public set[loc] methods(M3 m, loc class) = { e | e <- elements(m, class), isMethod(e) };
@memo public set[loc] nestedClasses(M3 m, loc class) = { e | e <- elements(m, class), isClass(e) };

// temp dirty function to cat file location to m3 location
public loc createPossibleDeclaration(node s, str name) {
	return toLocation("php+variable:///<s[0]>/<s[1]>/<s[2]>/<s[3]>/<name>");
}