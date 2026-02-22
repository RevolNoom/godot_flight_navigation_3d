## This class contains static functions that serve as Callable objects
class_name Comparator

## Return a < b
static func less(a, b) -> bool:
	return a<b

## Return a <= b
static func less_equal(a, b) -> bool:
	return a<=b

## Return a > b
static func greater(a, b) -> bool:
	return a>b

## Return a >= b
static func greater_equal(a, b) -> bool:
	return a>=b

## Return a == b
static func equal(a, b) -> bool:
	return a==b
	
## Return a != b
static func unequal(a, b) -> bool:
	return a!=b
