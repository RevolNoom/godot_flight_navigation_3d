---
paths:
  - "**/*.const.gd"
---

# Rules: GDScript constant style

## File contains only constants

## Name the file `<original_class>.const.gd`
```
src/svo.const.gd
```

## Postfix `class_name` with `Const`
```gdscript
class_name SvoConst
```

## Name `const` values in `CONSTANT_CASE`.
```gdscript
const SVOLINK = 1
```