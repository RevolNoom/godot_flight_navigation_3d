# GDScript Best Practices

## Each file encapsulates class. It must declare a class_name

## Documentation guideline
https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html#bbcode-and-class-reference

## Use "extends class_name" instead of script path
### Example 1
#### Bad
extends "res://src/i_svo_link.gd"
#### Good
extends ISvoLink

## Children nodes creation
### Prefer creating in the scene editor when:
#### They have the same lifespan as scene root

### Prefer creating by code when:
#### Their lifespans are hard to determine 
#### Their numbers are determined dynamically at runtime


## Use flipped bit sequence when the sign bit of integer is 1
Godot has a bug when parsing negative number. This is a workaround.

### Example 1
#### Before
0b11111111_11111111_11111111_11111111_11111111_11111111_11111111_11111111
#### After
~0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000

### Example 1
#### Before
0xFFFF_FFFF_FFFF_FFFF
#### After
~0x0000_0000_0000_0000

