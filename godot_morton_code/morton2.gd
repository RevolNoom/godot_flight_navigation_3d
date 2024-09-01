extends Morton
class_name Morton2

## Return a 64 bits Morton code, with x, y, z bits interleaved:[br]
## y31 x31 _ y30 x30 _ ... _ y0 x0[br]
## [b]WARNING:[/b] Can't encode value > 0xFFFF_FFFF, 32 bits).[br]
static func encode64(x: int, y: int) -> int:
	#assert(not ((x|y) & (~0xFFFF_FFFF)), "ERROR: Morton2 encoding values of more than 32 bits")
	return _encodeMB64(x) | (_encodeMB64(y)<<1)

## Like [method encode64]. Encode [param v]'s x, y components.[br]
static func encode64v(v: Vector2i) -> int:
	return Morton2.encode64(v.x, v.y)


## Decode [param code] into x, y components of a Vector2.[br]
static func decode_vec2(code: int) -> Vector2:
	return Vector2(_decodeMB64(code & _INTERPOSITION),
					_decodeMB64(code >> 1) & _INTERPOSITION)
					
## Decode [param code] into x, y components of a Vector2i.[br]
static func decode_vec2i(code: int) -> Vector2i:
	return Vector2i(_decodeMB64(code & _INTERPOSITION),
					_decodeMB64(code >> 1) & _INTERPOSITION)


## Return undecoded x-component of [param morton].[br]
static func raw_x(morton: int) -> int:
	return morton & _X_MASK
	
## Return undecoded y-component of [param morton].[br]
static func raw_y(morton: int) -> int:
	return (morton>>1) & _Y_MASK


## Return a copy of [param morton] with x-component set to [param new_value].[br]
static func set_x(morton: int, new_value: int) -> int:
	return morton & (~_X_MASK) | Morton3._encodeMB64(new_value)

## Return a copy of [param morton] with y-component set to [param new_value].[br]
static func set_y(morton: int, new_value: int) -> int:
	return morton & (~_Y_MASK) | (Morton3._encodeMB64(new_value) << 1)


## Return a Morton2 code with each x, y component 
## is sum of [param lhs] and [param rhs]' counterparts.[br]
static func add(lhs: int, rhs: int):
	var x_sum = (lhs | _Y_MASK) + (rhs & _X_MASK)
	var y_sum = (lhs | _X_MASK) + (rhs & _Y_MASK)
	return (x_sum & _X_MASK) | (y_sum & _Y_MASK)

## Return a Morton2 code with each x, y component 
## is remainder of [param lhs] subtracted by [param rhs]' counterparts.[br] 
static func sub(lhs: int, rhs: int):
	var x_diff = (lhs & _X_MASK) - (rhs & _X_MASK)
	var y_diff = (lhs & _Y_MASK) - (rhs & _Y_MASK)
	return ((x_diff & _X_MASK) | (y_diff & _Y_MASK))



## Return a copy of [param code] with x-component added by 1.[br]
static func inc_x(code: int) -> int:
	var x_sum = ((code | _Y_MASK) + 1)
	return ((x_sum & _X_MASK) | (code & _Y_MASK))
	
## Return a copy of [param code] with y-component added by 1.[br]
static func inc_y(code: int) -> int:
	var y_sum = ((code | _X_MASK) + 2)
	return ((y_sum & _Y_MASK) | (code & _X_MASK))


## Return a copy of [param code] with x-component subtracted by 1.[br]
static func dec_x(code: int) -> int:
	var x_diff = ((code & _X_MASK) - 1)
	return ((x_diff & _X_MASK) | (code & _Y_MASK))
	
## Return a copy of [param code] with y-component subtracted by 1.[br]
static func dec_y(code: int) -> int:
	var y_diff = ((code & _Y_MASK) - 2)
	return ((y_diff & _Y_MASK) | (code & _X_MASK))


## Return true if all components of [param lhs] 
## is greater than [param rhs] counterparts.[br]
static func gt(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) > (rhs & _X_MASK)\
		and (lhs & _Y_MASK) > (rhs & _Y_MASK)
		
## Return true if all components of [param lhs] 
## is greater or equal to [param rhs] counterparts.[br]
static func ge(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) >= (rhs & _X_MASK)\
		and (lhs & _Y_MASK) >= (rhs & _Y_MASK)

## Return true if all components of [param lhs] 
## is less than [param rhs] counterparts.[br]
static func lt(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) < (rhs & _X_MASK)\
		and (lhs & _Y_MASK) < (rhs & _Y_MASK)

## Return true if all components of [param lhs] 
## is less or equal to [param rhs] counterparts.[br]
static func le(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) <= (rhs & _X_MASK)\
		and (lhs & _Y_MASK) <= (rhs & _Y_MASK)


# Encode a value using Magic Bits algorithm.[br]
# [b]NOTE:[/b] Godot v4.2.dev6.official.57a6813bb has problem parsing
# hex number, so I'm resorting to bits instead.[br]
static func _encodeMB64(x: int) -> int:
	x &= 0b00000000_00000000_00000000_00000000_11111111_11111111_11111111_11111111
	x = (x ^ (x<<16)) & 0b00000000_00000000_11111111_11111111_00000000_00000000_11111111_11111111
	x = (x ^ (x<<8))  & 0b00000000_11111111_00000000_11111111_00000000_11111111_00000000_11111111
	x = (x ^ (x<<4))  & 0b00001111_00001111_00001111_00001111_00001111_00001111_00001111_00001111
	x = (x ^ (x<<2))  & 0b00110011_00110011_00110011_00110011_00110011_00110011_00110011_00110011
	x = (x ^ (x<<1))  & _INTERPOSITION
	return x


# Decode a value using Magic Bits algorithm
static func _decodeMB64(x: int) -> int:
	x &= _INTERPOSITION
	x = (x ^ (x>>1))  & 0b00110011_00110011_00110011_00110011_00110011_00110011_00110011_00110011
	x = (x ^ (x>>2))  & 0b00001111_00001111_00001111_00001111_00001111_00001111_00001111_00001111
	x = (x ^ (x>>4))  & 0b00000000_11111111_00000000_11111111_00000000_11111111_00000000_11111111
	x = (x ^ (x>>8))  & 0b00000000_00000000_11111111_11111111_00000000_00000000_11111111_11111111
	x = (x ^ (x>>16)) & 0b00000000_00000000_00000000_00000000_11111111_11111111_11111111_11111111
	return x
	

static func _automated_test():
	var no_error = true
	for i in range(0, 32):
		var value = 1 << i
		var encode_value = encode64(value, 0)
		var expected_value = 1 << (i*2)
		var decode_value = Morton2.decode_vec2i(expected_value).x
		#print("Value:\t%s\nEncode:\t%s\nExpect:\t%s\nDecode:\t%s\n" % \
		#		[int_to_bin(value, 64),
		#		int_to_bin(encode_value, 64),
		#		int_to_bin(expected_value, 64),
		#		int_to_bin(decode_value, 64)])
				
		if encode_value != expected_value:
			no_error = false
			printerr("Encoding %d got %d but expected %d!" % [value, encode_value, expected_value])
			printerr("Value:\t'%s'\nEncoded:\t%s\nExpected:\t%s" \
					% [int_to_bin(value),\
						int_to_bin(expected_value),\
						int_to_bin(encode_value)])
		
		if decode_value != value:
			no_error = false
			printerr("Decoding %d got %d but expected %d!" % [expected_value, decode_value, value])
			printerr("Value:\t%s\nDecoded:\t%s\nExpected:\t%s" \
					% [int_to_bin(expected_value),\
						int_to_bin(decode_value),\
						int_to_bin(value)])
	# TODO: Add inc/dec/add/sub tests
	if no_error:
		print("All Morton2 tests passed.")
		
const _INTERPOSITION = 0b01010101_01010101_01010101_01010101_01010101_01010101_01010101_01010101
const _X_MASK = _INTERPOSITION
const _Y_MASK = _INTERPOSITION << 1
