class_name Morton

## This Morton module ports C++ code from 
## - https://github.com/aavenel/mortonlib/
## - https://www.forceflow.be/2013/10/07/morton-encodingdecoding-through-bit-interleaving-implementations/
## If you have some free time, come over and star their repos

## Return a string like "0b1001010101010101".
##
## @x: an integer
##
## @prefix0b add "0b" to the start of the string.
##
## @length: 
## Specify how long the binary part after "0b" is.
## + Drop the most significant bits if shorter
static func int_to_bin(x: int, length: int = 64, prefix0b: bool = true) -> String:
	var bin = "0".repeat(64)
	for i in range(64):
		if x & (1 << (63-i)):
			bin[i] = "1"
	return ("0b" if prefix0b else "")\
		+  "0".repeat(maxi(0, length - bin.length()))\
		+  bin.substr(clampi(bin.length() - length, 0, bin.length()))
