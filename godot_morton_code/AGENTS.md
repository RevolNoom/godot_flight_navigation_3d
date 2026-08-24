# Godot Morton Code best practice for AI
## Bit sequence format
### Morton2
#### Format bits in groups of 4 or 8
##### Example
0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
#### Use flipped version when the sign bit is 1
Godot considers bit/hex sequences as unsigned integers.
Negative-number bit sequence will be parsed incorrectly and output debugger errors.
##### References
https://github.com/godotengine/godot/issues/36387
https://github.com/godotengine/godot/issues/116438

##### Example
###### Bad
0b1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010_1010

###### Good
~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101

### Morton3
#### Format bits in groups of 3. 
It makes it easier for human eyes to pickout individual x, y, z components.
##### Example
0b010_101_010_101

## Number vs Bitmasks
Depending on the use case, function arguments will expect user input as bitmask or simple integer.
### Morton codes 
Should always be understood as bitmasks.
### Amount
Should always be understood as integer.
#### Example
Add/sub/set x/y/z components takes a Morton codes and an addition/subtraction amount.
### Documentation
Clarify function inputs whether they are bitmask or integer.
#### Example
##### Bad
Return a copy of [param morton] with x-component set to [param new_value].[br]
##### Good
Return a copy of [param morton] with x-component set to [param new_value].[br]
[param morton]: Bitmask.[br]
[param new_value]: Integer.[br]