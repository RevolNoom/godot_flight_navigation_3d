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
## @length < 0 means as long as needed.
## Add 0's paddings if it's longer than the result
## truncate if shorter
##
## NOTE: This function fails to address value -2^63
static func int_to_bin(x: int, length: int = -1, prefix0b: bool = true) -> String:
	var bin = ""
	if x == 0:
		bin = "0"
	else:
		while x != 0:
			bin = bin + str(x & 1)
			x >>= 1
	bin = bin.substr(0, length)
	bin += "0".repeat(maxi(0, length - bin.length()))
	bin = ("0b" if prefix0b else "") + bin.reverse()
	return bin
