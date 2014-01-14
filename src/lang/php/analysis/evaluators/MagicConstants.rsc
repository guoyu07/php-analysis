@license{
  Copyright (c) 2009-2011 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - Mark.Hills@cwi.nl (CWI)}
module lang::php::analysis::evaluators::MagicConstants

// TODO: The current parse format does not distinguish between a 
// namespace with an empty body and a namespace given without
// brackets. Until this is fixed, assume here that an empty body 
// is a namespace without brackets.

// TODO: Add support for __TRAIT__. We aren't encountering this yet in code.

import lang::php::ast::AbstractSyntax;
import lang::php::util::System;
import Set;
import List;
import String;
import Exception;
import IO;

@doc{Replace magic constants with their actual values.}
public tuple[Script newScript, bool changed] inlineMagicConstants(Script scr, loc l, loc baseloc) {
	// First, replace any magic constants that require context. This includes
	// __CLASS__, __METHOD__, __FUNCTION__, __NAMESPACE__, and __TRAIT__.
	bool changed = false;
	
	Expr wrapReplace(Expr e) { changed = true; return e; }

	scr = top-down visit(scr) {
		case c:class(className,_,_,_,members) : {
			members = bottom-up visit(members) {
				case s:scalar(classConstant()) => wrapReplace(scalar(string(className))[@at=s@at])
			}
			insert(c[members=members]);
		}
		
		case m:method(methodName,_,_,_,body) : {
			body = bottom-up visit(body) {
				case s:scalar(methodConstant()) => wrapReplace(scalar(string(methodName))[@at=s@at])
			}
			insert(m[body=body]);
		}
		
		case f:function(funcName,_,_,body) : {
			body = bottom-up visit(body) {
				case s:scalar(funcConstant()) => wrapReplace(scalar(string(funcName))[@at=s@at])
			}
			insert(f[body=body]);
		}
		
		case n:namespace(maybeName,body) : {
			// NOTE: In PHP, a namespace without a name is used to
			// include global code in a file with a namespace declaration.

			namespaceName = "";
			if (someName(name(str nn)) := maybeName) namespaceName = nn;
			body = bottom-up visit(body) {
				case s:scalar(namespaceConstant()) => wrapReplace(scalar(string(namespaceName))[@at=s@at])
			}
			insert(n[body=body]);
		}
		
		case n:namespaceHeader(namespaceName) : {
			;
			// TODO: This sets the name for the other code in the file.
			// We need to look at a good way to "fence" these to make
			// this visible in __NAMESPACE__ occurrences...
		}
	}
	
	// Now, replace those magic constants that do not require any context,
	// such as __FILE__ and __DIR__. Also replace the magic constants that
	// do require context with "", this means they were used outside of a
	// valid context (e.g., __CLASS__ outside of a class).
	fileLoc = substring(l.path,size(baseloc.path));
	dirLoc = substring(l.parent.path,size(baseloc.path));
	
	scr = bottom-up visit(scr) {
		case s:scalar(classConstant()) => wrapReplace(scalar(string(""))[@at=s@at])
		case s:scalar(methodConstant()) => wrapReplace(scalar(string(""))[@at=s@at])
		case s:scalar(funcConstant()) => wrapReplace(scalar(string(""))[@at=s@at])
		case s:scalar(namespaceConstant()) => wrapReplace(scalar(string(""))[@at=s@at])

		case s:scalar(fileConstant()) => wrapReplace(scalar(string(fileLoc))[@at=s@at])
		case s:scalar(dirConstant()) => wrapReplace(scalar(string(dirLoc))[@at=s@at])

		case s:scalar(lineConstant()) : {
			try {
				insert(wrapReplace(scalar(integer(s@at.begin.line))[@at=s@at]));
			} catch UnavailableInformation() : {
				println("Tried to extract line number from location <s@at> with no line number information");
			}
		}
	}
	return < scr, changed >;
}

public System inlineMagicConstants(System scripts, loc baseloc) {
	return ( l : inlineMagicConstants(scripts[l],l,baseloc).newScript | l <- scripts );
}