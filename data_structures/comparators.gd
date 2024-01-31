## This class contains static functions that serve as Callable objects
class_name Comparator

## Return a < b
static func LESS(a, b) -> bool:
	return a<b

## Return a <= b
static func LESS_EQUAL(a, b) -> bool:
	return a<=b

## Return a > b
static func GREATER(a, b) -> bool:
	return a>b

## Return a >= b
static func GREATER_EQUAL(a, b) -> bool:
	return a>=b

## Return a == b
static func EQUAL(a, b) -> bool:
	return a==b
	
## Return a != b
static func UNEQUAL(a, b) -> bool:
	return a!=b
