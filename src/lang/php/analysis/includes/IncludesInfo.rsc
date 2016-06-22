module lang::php::analysis::includes::IncludesInfo

import lang::php::ast::AbstractSyntax;
import lang::php::ast::System;
import lang::php::util::Config;
import lang::php::analysis::evaluators::AlgebraicSimplification;
import lang::php::analysis::evaluators::SimulateCalls;
import lang::php::analysis::evaluators::MagicConstants;
import lang::php::analysis::includes::NormalizeConstCase;
import lang::php::analysis::evaluators::DefinedConstants;
import lang::php::util::Utils;
import lang::php::analysis::evaluators::Simplify;

import Set;
import IO;
import ValueIO;

private loc infoLoc = baseLoc + "serialized/includeInfo";


public void buildIncludesInfo(str p, str v, loc baseloc) {
	return buildIncludesInfo("<p>-<v>", baseloc);
}

public void buildIncludesInfo(str name, loc baseloc) {
	if (exists(infoLoc + "<name>-l2c.bin")) return;
	sys = loadBinary(name);
	buildIncludesInfo(sys, name, baseloc);
}

public void buildIncludesInfo(System sys, str p, str v, loc baseloc) {
	buildIncludesInfo(sys, "<p>-<v>", baseloc);
}

public void buildIncludesInfo(System sys, str overrideName = "") {
	if (overrideName != "") {
		buildIncludesInfo(sys, overrideName, sys.baseLoc);
	} else if (sys has name && sys has version && sys has baseLoc) {
		buildIncludesInfo(sys, "<sys.name>-<sys.version>", sys.baseLoc);
	} else if (sys has name && sys has baseLoc) {
		buildIncludesInfo(sys, sys.name, sys.baseLoc);
	} else {
		throw "Cannot build includes for this system, name and baseLoc are both needed";
	}
}

public void buildIncludesInfo(System sys, str name, loc baseloc) {
	if (!exists(infoLoc)) mkDirectory(infoLoc);
	if (exists(infoLoc + "<name>-l2c.bin")) return;
	
	map[loc,set[ConstItemExp]] loc2consts = ( l : { cdef[e=simplifyExpr(cdef.e, baseloc)]  | cdef <- getScriptConstDefs(sys.files[l]) } | l <- sys.files);
	rel[ConstItem,loc,Expr] constrel = { < (classConst(cln,cn,ce) := ci) ? classConst(cln,cn) : normalConst(ci.constName), l, ci.e > | l <- loc2consts, ci <- loc2consts[l] };

	map[str, Expr] constMap = ( cn : ce | ci:normalConst(cn) <- constrel<0>, csub := constrel[ci,_], size(csub) == 1, ce:scalar(sv) := getOneFrom(csub), encapsed(_) !:= sv );  
	if ("DIRECTORY_SEPARATOR" notin constMap)
		constMap["DIRECTORY_SEPARATOR"] = scalar(string("/"));
	if ("PATH_SEPARATOR" notin constMap)
		constMap["PATH_SEPARATOR"] = scalar(string(":"));

	map[str, map[str, Expr]] classConstMap = ( );
	for (ci:classConst(cln,cn) <- constrel<0>, csub := constrel[ci,_], size(csub) == 1, ce:scalar(sv) := getOneFrom(csub), encapsed(_) !:= sv) {
		if (cln in classConstMap) {
			classConstMap[cln][cn] = ce;
		} else {
			classConstMap[cln] = ( cn : ce );
		}
	}
	
	writeBinaryValueFile(infoLoc + "<name>-l2c.bin", loc2consts);
	writeBinaryValueFile(infoLoc + "<name>-crel.bin", constrel);
	writeBinaryValueFile(infoLoc + "<name>-cmap.bin", constMap);
	writeBinaryValueFile(infoLoc + "<name>-ccmap.bin", classConstMap);
}

data IncludesInfo 
	= includesInfo(map[loc,set[ConstItemExp]] loc2consts,
				   rel[ConstItem,loc,Expr] constRel,
				   map[str, Expr] constMap,
				   map[str, map[str, Expr]] classConstMap);
				   

@doc{Merge two IncludesInfo records. This is useful when we have components that are treated separately but are also merged into other components or systems.}
public IncludesInfo mergeIncludesInfo(IncludesInfo ii1, IncludesInfo ii2) {
	// Build the merged loc2consts. We do this by including locations that are a) in ii1 but
	// not in ii2, b) in ii2 but not in ii1, and c) are in both, in which case we just
	// union the sets together.
	loc2consts = domainX(ii1.loc2consts, ii2.loc2consts<0>) +
		domainX(ii2.loc2consts, ii1.loc2consts<0>) +
		( l : ii1.loc2consts[l] + ii2.loc2consts[l] | l <- ii1.loc2consts, l in ii2.loc2consts );
	
	// Build the merged constRel. Since this is a relation, this is easy, we just put the
	// two relations together.
	constRel = ii1.constRel + ii2.constRel;
	
	// Build the merged const map, which has all the constants that are a) in ii1 but not in ii2, 
	// b) in ii2 but not in ii1, or c) are in both and are assigned the same defining expression,
	// which (see code above) is a scalar, non-encapsed value.
	constMap = domainX(ii1.constMap, ii2.constMap<0>) + 
		domainX(ii2.constMap, ii1.constMap<0>) + 
		( s : ii1.constMap[s] | s <- ii1.constMap, s in ii2.constMap, ii1.constMap[s] == ii2.constMap[2] );
	
	// Build the merged class const map. The easiest way to do this is to flatten it into a relation
	// and then put it back into a map form when possible (when the class constant only has a unique
	// defining expression)
	classConstRel = { < cl, c, ii1.classConstMap[cl][c] > | cl <- ii1.classConstMap, c <- ii1.classConstMap[cl] } +
		{ < cl, c, ii1.classConstMap[cl][c] > | cl <- ii1.classConstMap, c <- ii1.classConstMap[cl] };
	map[str, map[str, Expr]] classConstMap = ( );
	for (cl <- classConstRel<0>) {
		map[str, Expr] submap = ( c : v | c <- classConstRel[cl]<0>, vs := classConstRel[cl][c], size(vs) == 1, v := getOneFrom(vs) );
		classConstMap[cl] = submap;
	}
	
	return includesInfo(loc2consts, constRel, constMap, classConstRel);
}

public bool includesInfoExists(str p, str v) = includesInfoExists("<p>-<v>");

public bool includesInfoExists(str name) {
	return exists(infoLoc + "<name>-l2c.bin") && exists(infoLoc + "<name>-crel.bin") && exists(infoLoc + "<name>-cmap.bin") && exists(infoLoc + "<name>-ccmap.bin");
}
				  
public IncludesInfo loadIncludesInfo(str p, str v) = loadIncludesInfo("<p>-<v>");

public IncludesInfo loadIncludesInfo(str name) {
	map[loc,set[ConstItemExp]] loc2consts = readBinaryValueFile(#map[loc,set[ConstItemExp]], infoLoc + "<name>-l2c.bin");
	rel[ConstItem,loc,Expr] constRel = readBinaryValueFile(#rel[ConstItem,loc,Expr], infoLoc + "<name>-crel.bin");
	map[str, Expr] constMap = readBinaryValueFile(#map[str, Expr], infoLoc + "<name>-cmap.bin");
	map[str, map[str, Expr]] classConstMap = readBinaryValueFile(#map[str, map[str, Expr]], infoLoc + "<name>-ccmap.bin");
	
	return includesInfo(loc2consts, constRel, constMap, classConstMap);
}