---
paths:
  - "**/*.gd"
# LSP resolves symbols through the parsed syntax tree, so it finds real definitions
# instead of text matches spread across comments, strings, and similar names.
#
# Verified against Godot 4.7.1 on 2026-07-19.
#
# findReferences matches declarations and string literals but misses invocations, and
# returns a short plausible list instead of erroring. On get_neighbors_of it returned the
# definition, the *.abst.gd declaration, and that file's _abstract_fail("get_neighbors_of")
# string, missing all three call sites in src/greedy_a_star.gd and tests/svo.test.gd.
#
# workspaceSymbol, goToImplementation, and the call hierarchy operations return
# "Method not found". The server does not implement them.
#
# On a method overriding an *.abst.gd declaration, hover reports the abstract base in its
# "Defined in" line, not the concrete override under the cursor.
---

# Rules: GDScript

## Style

### PascalCase class_name
```gdscript
class_name Svo
```

### Type every variable declaration
```gdscript
var morton: Array[PackedInt64Array] = []
```

### Type every function parameter
```gdscript
func set_morton(layer: int, index: int, morton3_value: int) -> void:
```

### Explicit function return type
```gdscript
func set_layer_count(layer_count: int) -> void:
```

### Documentation

#### Function parameters
\#\# [param argname]: What it is, notes [br]
```gdscript
## [param from]: Global coordinate of starting position[br]
```

#### Use [ClassName] for class references
```gdscript
## [SVOLink] to the parent SVONode in the upper layer.
```

#### Use [br] for line breaks. Add breaks at the end of descriptions, param, return types.

#### Class document
Short descriptions
[br][br]
Detailed descriptions

```gdscript
## Sparse Voxel Octree 
## [br][br]
## Represents the solid/free states of volumes in 3D space.
## ...
```

#### Document all member variables
```gdscript
## [SVOLink] to the parent SVONode in the upper layer.
@export var parent: Array[PackedInt64Array] = []
```

#### Document all function parameters, return type
[b]Important notes[/b] (optional)[br]
[param argname]: argument description[br]
Return: return value description[br]

```gdscript
## [param from]: Global coordinate of starting position[br]
## [param to]: Global coordinate of destination position[br]
## Return: a path that connects [param from] and [param to].[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
```

## Code navigation

### List a file's classes, methods, and members with `documentSymbol`.
```
LSP(operation: "documentSymbol", filePath: "src/svo.gd", line: 1, character: 1)
```

### Find where a symbol is defined with `goToDefinition`, positioned on a call site or `class_name` usage.
```
LSP(operation: "goToDefinition", filePath: "tests/svo.test.gd", line: 136, character: 14)
```

### Read a symbol's signature and doc comment with `hover`.
```
LSP(operation: "hover", filePath: "src/svo.gd", line: 453, character: 6)
```

### Never locate call sites with `findReferences`.
❌
```
LSP(operation: "findReferences", filePath: "src/svo.gd", line: 337, character: 6)
```

### Never call `workspaceSymbol`, `goToImplementation`, `prepareCallHierarchy`, `incomingCalls`, or `outgoingCalls`.
❌
```
LSP(operation: "goToImplementation", filePath: "src/svo.abst.gd", line: 23, character: 6)
```
