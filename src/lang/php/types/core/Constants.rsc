module lang::php::types::core::Constants

import lang::php::types::TypeSymbol;

// Predefined constants	
// https://github.com/php/php-langspec/blob/master/spec/06-constants.md#core-predefined-constants

public map[str, TypeSymbol] predefinedConstants =
(
	"DEFAULT_INCLUDE_PATH": stringType(), 
	"E_ALL": integerType(), 
	"E_COMPILE_ERROR": integerType(), 
	"E_COMPILE_WARNING": integerType(), 
	"E_CORE_ERROR": integerType(), 
	"E_CORE_WARNING": integerType(), 
	"E_DEPRECATED": integerType(), 
	"E_ERROR": integerType(), 
	"E_NOTICE": integerType(), 
	"E_PARSE": integerType(), 
	"E_RECOVERABLE_ERROR": integerType(), 
	"E_STRICT": integerType(), 
	"E_USER_DEPRECATED": integerType(), 
	"E_USER_ERROR": integerType(), 
	"E_USER_NOTICE": integerType(), 
	"E_USER_WARNING": integerType(), 
	"E_WARNING": integerType(), 
	"FALSE": booleanType(), 
	"INF": floatType(), 
	"M_1_PI": floatType(), 
	"M_2_PI": floatType(), 
	"M_2_SQRTPI": floatType(), 
	"M_E": floatType(), 
	"M_EULER": floatType(), 
	"M_LN10": floatType(),
	"M_LN2": floatType(), 
	"M_LNPI": floatType(), 
	"M_LOG10E": floatType(), 
	"M_LOG2E": floatType(), 
	"M_PI": floatType(), 
	"M_PI_2": floatType(), 
	"M_PI_4": floatType(), 
	"M_SQRT1_2": floatType(), 
	"M_SQRT2": floatType(), 
	"M_SQRT3": floatType(), 
	"M_SQRTPI": floatType(), 
	"NAN": floatType(), 
	"NULL": nullType(), 
	"PHP_BINARY": stringType(), 
	"PHP_BINDIR": stringType(), 
	"PHP_CONFIG_FILE_PATH": stringType(), 
	"PHP_CONFIG_FILE_SCAN_DIR": stringType(), 
	"PHP_DEBUG": integerType(), 
	"PHP_EOL": stringType(), 
	"PHP_EXTENSION_DIR": stringType(), 
	"PHP_EXTRA_VERSION": stringType(), 
	"PHP_INT_MAX": integerType(), 
	"PHP_INT_SIZE": integerType(), 
	"PHP_MAJOR_VERSION": integerType(), 
	"PHP_MANDIR": stringType(), 
	"PHP_MAXPATHLEN": integerType(), 
	"PHP_MINOR_VERSION": integerType(), 
	"PHP_OS": stringType(), 
	"PHP_PREFIX": stringType(), 
	"PHP_RELEASE_VERSION": integerType(), 
	"PHP_ROUND_HALF_DOWN": integerType(), 
	"PHP_ROUND_HALF_EVEN": integerType(), 
	"PHP_ROUND_HALF_ODD": integerType(), 
	"PHP_ROUND_HALF_UP": integerType(), 
	"PHP_SAPI": stringType(), 
	"PHP_SHLIB_SUFFIX": stringType(), 
	"PHP_SYSCONFDIR": stringType(), 
	"PHP_VERSION": stringType(), 
	"PHP_VERSION_ID": integerType(), 
	"PHP_ZTS": integerType(), 
	"STDIN": resourceType(), 
	"STDOUT": resourceType(), 
	"STDERR": resourceType(), 
	"TRUE": booleanType()
);