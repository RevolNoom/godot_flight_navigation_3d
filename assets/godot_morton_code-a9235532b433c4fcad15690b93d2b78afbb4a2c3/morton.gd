class_name Morton

## This Morton module ports C++ code from 
## - https://github.com/aavenel/mortonlib/
## - https://www.forceflow.be/2013/10/07/morton-encodingdecoding-through-bit-interleaving-implementations/
## If you have some free time, come over and star their repos

## Return a string of 64 characters representing an int64 in Big Endian
static func int_to_bin(x: int) -> String:
	var bin = "0000000000000000000000000000000000000000000000000000000000000000"
	for i in range(64):
		if x & (1 << (63-i)):
			bin[i] = "1"
	return bin
