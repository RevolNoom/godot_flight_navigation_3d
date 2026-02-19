# GDScript Best Practices

## Each file encapsulates class. It must declare a class_name

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

