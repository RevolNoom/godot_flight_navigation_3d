# Godot Unit Test Guidelines

## Always parameterize tests with use_parameters() instead of loops or duplicate codes

## Do not write tests for constants

## Dependency injection

### Parameterize interface test functions with concrete implementation instance and arguments

#### Example
##### Bad: 2 functions for 2 implementations
func test_svolink32_null():
	assert_eq(_svolink32.null_link(), 0xFFFF_FFFF)

func test_svolink64_null():
	assert_eq(_svolink64.null_link(), ~0)
##### Good: 1 function, 2 sets of parameters for 2 implementations
func test_svolink_null(params = use_parameters([{
	"singleton": SvoLink32.singleton,
	"expected": 0xFFFF_FFFF,
}, {
	"singleton": SvoLink64.singleton,
	"expected": ~0,
},])):
	var singleton = params["singleton"]
	var expected = params["expected"]
	assert_eq(singleton.null_link(), expected)
