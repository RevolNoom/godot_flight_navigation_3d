---
paths:
  - "**/*.test.*gd"
# An abstract file declares the contract only; every method body fails loudly at runtime
# so a missing override surfaces on first call instead of silently returning a default.
---

# Rules: GDScript test class style

## Name the file `<test_file>.test.gd`
src/svo.test.gd
src/svo.abst.test.gd

## Postfix `class_name` with `Test`
```gdscript
class_name SvoTest
```

## Parameterized tests
### Parameters comments
```gdscript
var find_path_params = [
	[
		1, # from
		3, # to
		Svo.new(), # Svo
		new PackedInt64Array([1, 2, 3]) # expected
	], 
	[
		4, # from
		6, # to
		Svo.new(), # Svo
		new PackedInt64Array([4, 5, 6]) # expected
	], 
]
```

### All test functions are parameterized
```gdscript
var find_path_params = [
	...
]
func test_find_path(params = use_parameters(find_path_params)) -> void:
	# Setups
	# ...
	# 
	var test_instance = GreedyAStar.new()

	# Run test
  var result = GreedyAStar.find_path(params[0], params[1], params[2])

	# Asserts
	# ...
  assert_eq(result, params[3])
```

## Test cases
Based on the number of arguments in the tested function. With N arguments:
- n unique happy cases 
- n unique failure cases 
- n unique edge cases 