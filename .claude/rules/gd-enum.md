---
paths:
  - "src/enums/*.gd"
# A file holds only one enum, named Enum, so the enum can be used as a type in other scripts.
---

# Rules: GDScript enums

### Declare exactly one enum per file, named `Enum`.
```gdscript
enum Enum {
}
```

### Name `class_name` after the concept the enum describes.
```gdscript
class_name Separability
```

### Put a `##` doc comment above `class_name`.
```gdscript
## Determines how "thick" the surface voxelization is.
class_name Separability
```

### Name enum values in `CONSTANT_CASE`.
```gdscript
SEPARATING_6
```

### Put a `##` doc comment above every enum value.
```gdscript
enum Enum {
	## Thin voxelization.
	SEPARATING_6,
}
```
