class_name Morton

## This Morton module ports C++ code from:[br]
## - https://github.com/aavenel/mortonlib/[br]
## - https://www.forceflow.be/2013/10/07/morton-encodingdecoding-through-bit-interleaving-implementations/[br]
## Come over and star their repos if you have some free time, please?[br]

## Return a string of 64 characters representing an int64 in Big Endian
static func int_to_bin(x: int) -> String:
	var bin = "0000000000000000000000000000000000000000000000000000000000000000"
	for i in range(64):
		if x & (1 << (63-i)):
			bin[i] = "1"
	return bin
