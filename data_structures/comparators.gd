class_name Comparator
## This class contains static functions that serve as Callable objects

static func LESS(a, b) -> bool:
	return a<b

static func LESS_EQUAL(a, b) -> bool:
	return a<=b

static func GREATER(a, b) -> bool:
	return a>b

static func GREATER_EQUAL(a, b) -> bool:
	return a>=b

static func EQUAL(a, b) -> bool:
	return a==b
	
static func UNEQUAL(a, b) -> bool:
	return a!=b
