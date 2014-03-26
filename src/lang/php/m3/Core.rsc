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

import util::FileSystem;
import demo::common::Crawl;

alias M3Collection = map[loc fileloc, M3 model];

anno rel[loc from, loc to] M3@extends;		// classes extending classes and interfaces extending interfaces
anno rel[loc from, loc to] M3@implements;	// classes implementing interfaces
anno rel[loc pos, str phpDoc] M3@phpDoc;    // Multiline php comments /** ... */

public M3 composePhpM3(loc id, set[M3] models) {
  m = composeM3(id, models);
  
  m@extends = {*model@extends | model <- models};
  m@implements = {*model@implements | model <- models};
  m@annotations = {*model@annotations | model <- models};
  m@phpDoc = {*model@phpDoc | model <- models};
  
  return m;
}


map[loc, map[loc, Declaration]] methodASTs = ();


// hack to make decls work on nodes; visit does recognize the annotations
public anno loc node@at;
public anno loc node@decl;
public anno str node@phpdoc;

@doc{
Synopsis: globs for jars, class files and java files in a directory and tries to compile all source files into an [$analysis/m3] model
}
public M3Collection createM3sFromDirectory(loc project) {
    if (!(isDirectory(project)))
      throw "<project> is not a valid directory";
    
    System system = loadPHPFiles(project);
    M3Collection m3s = (l:m3(l) | l <- system); // for each file, create an empty m3
    
	// fill declarations
	for (l <- system) {
		visit (system[l]) {
			case node n:
				if ( (n@at)? && (n@decl)? ) {
					m3s[l]@declarations += {<n@decl, n@at>};
					m3s[l]@names += {<n@decl.file, n@decl>};
				}
	   	}
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
					set[loc] possibleImplements = getPossibleClassesInM3(m3s[l], name);
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
			case node n: {
				if ( (n@decl)? && (n@phpdoc)? ) 
					m3s[l]@phpDoc += {<n@decl, n@phpdoc>};
			}
	   	}
   	}
   	
    return m3s;
}

    
public set[loc] getPossibleClassesInM3(M3 m3, str className) {
	set[loc] locs = {};
	
	for (name <- m3@names) 
		if (name.simpleName == className && isClass(name.qualifiedName))
			locs += name.qualifiedName;
				
	return isEmpty(locs) ? {|php+unknownClass:///| + className} : locs;
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
public bool isMethod(loc entity) = entity.scheme == "php+method";
public bool isTrait(loc entity) = entity.scheme == "php+trait";
public bool isParameter(loc entity) = entity.scheme == "php+parameter";
public bool isFunction(loc entity) = entity.scheme == "php+function";
public bool isVariable(loc entity) = entity.scheme == "php+variable";
public bool isField(loc entity) = entity.scheme == "php+field";
public bool isInterface(loc entity) = entity.scheme == "php+interface";

@memo public set[loc] namespaces(M3 m) = {e | e <- m@declarations<name>, isNamespace(e)};
@memo public set[loc] classes(M3 m) =  {e | e <- m@declarations<name>, isClass(e)};
@memo public set[loc] interfaces(M3 m) =  {e | e <- m@declarations<name>, isInterface(e)};
@memo public set[loc] traits(M3 m) = {e | e <- m@declarations<name>, isTrait(e)};
@memo public set[loc] parameters(M3 m)  = {e | e <- m@declarations<name>, isParameter(e)};
@memo public set[loc] functions(M3 m)  = {e | e <- m@declarations<name>, isFunction(e)};
@memo public set[loc] variables(M3 m) = {e | e <- m@declarations<name>, isVariable(e)};
@memo public set[loc] fields(M3 m) = {e | e <- m@declarations<name>, isField(e)};
@memo public set[loc] methods(M3 m) = {e | e <- m@declarations<name>, isMethod(e)};

public set[loc] elements(M3 m, loc parent) = { e | <parent, e> <- m@containment };

@memo public set[loc] fields(M3 m, loc class) = { e | e <- elements(m, class), isField(e) };
@memo public set[loc] methods(M3 m, loc class) = { e | e <- elements(m, class), isMethod(e) };
@memo public set[loc] nestedClasses(M3 m, loc class) = { e | e <- elements(m, class), isClass(e) };