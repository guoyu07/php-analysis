module lang::php::analysis::evaluators::Simplify

import lang::php::ast::AbstractSyntax;
import lang::php::ast::System;
import lang::php::analysis::evaluators::AlgebraicSimplification;
import lang::php::analysis::evaluators::SimulateCalls;
import lang::php::analysis::evaluators::MagicConstants;
import lang::php::analysis::includes::NormalizeConstCase;

@doc{Apply available normalization functions to simplify the expression}
public Expr simplifyExpr(Expr e, loc baseLoc) {
	e = normalizeConstCase(inlineMagicConstants(e, baseLoc));
	solve(e) {
		e = algebraicSimplification(simulateCalls(e));
	}
	return e;
}
