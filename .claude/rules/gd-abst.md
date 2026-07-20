---
paths:
  - "**/*.abst.*gd"
# - An abstract file declares the contract only; every method body fails loudly at runtime
# so a missing override surfaces on first call instead of silently returning a default.
# - TODO: @abstract annotation
---

# Rules: GDScript abstract class style

## File name format: `<snake_case_name>.abst.gd`
```
src/svo.abst.gd
```

## Class name format: AClassName
```gdscript
class_name ASvo
```

## Abstract functions name format: do_function_name
```gdscript
func do_find_path(_from: int, _to: int, _svo: SVO) -> PackedInt64Array:
```

## Open every abstract method body with `assert(false, "Not implemented")`
```gdscript
func do_find_path(_from: int, _to: int, _svo: SVO) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []
```
