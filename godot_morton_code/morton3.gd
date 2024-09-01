extends Morton
class_name Morton3

## Return a 64 bits Morton code, with x, y, z bits interleaved:[br]
## 0 z20 y20 x20 _ z19 y19 x19 z18 _ ... _ z0 y0 x0[br]
## [b]NOTE:[/b] The first bit is always left out.[br]
## [b]WARNING:[/b]Can't encode value > 2097151 (0x1FFFFF, 21 bits).[br]
static func encode64(x: int, y: int, z: int) -> int:
	#assert(not ((x|y|z) & (~0x1FFFFF)), "ERROR: Morton3 encoding values of more than 21 bits")
	return _encodeMB64(x) | (_encodeMB64(y)<<1) | (_encodeMB64(z)<<2)

## Like [method encode64]. Encode [param v]'s x, y, z components.[br]
static func encode64v(v: Vector3i) -> int:
	return Morton3.encode64(v.x, v.y, v.z)


## Decode [param code] into x, y, z components of a Vector3.[br]
static func decode_vec3(code: int) -> Vector3:
	return Vector3(_decodeMB64(code & _INTERPOSITION),
					_decodeMB64((code >> 1) & _INTERPOSITION),
					_decodeMB64((code >> 2) & _INTERPOSITION))
					
					
## Decode [param code] into x, y, z components of a Vector3i.[br]
static func decode_vec3i(code: int) -> Vector3i:
	return Vector3i(_decodeMB64(code & _INTERPOSITION),
					_decodeMB64((code >> 1) & _INTERPOSITION),
					_decodeMB64((code >> 2) & _INTERPOSITION))


## Return undecoded x-component of [param morton].[br]
static func raw_x(morton: int) -> int:
	return morton & _X_MASK
## Return undecoded y-component of [param morton].[br]
static func raw_y(morton: int) -> int:
	return (morton>>1) & _Y_MASK
## Return undecoded z-component of [param morton].[br]
static func raw_z(morton: int) -> int:
	return (morton>>2) & _Z_MASK


## Return a copy of [param morton] with x-component set to [param new_value].[br]
static func set_x(morton: int, new_value: int) -> int:
	return morton & (~_X_MASK) | Morton3._encodeMB64(new_value)
## Return a copy of [param morton] with y-component set to [param new_value].[br]
static func set_y(morton: int, new_value: int) -> int:
	return morton & (~_Y_MASK) | (Morton3._encodeMB64(new_value) << 1)
## Return a copy of [param morton] with z-component set to [param new_value].[br]
static func set_z(morton: int, new_value: int) -> int:
	return morton & (~_Z_MASK) | (Morton3._encodeMB64(new_value) << 2)


## Return a Morton3 code with each x, y, z component 
## is sum of [param lhs] and [param rhs]' counterparts.[br] 
static func add(lhs: int, rhs: int) -> int:
	var x_sum = (lhs | _ZY_MASK) + (rhs & _X_MASK)
	var y_sum = (lhs | _ZX_MASK) + (rhs & _Y_MASK)
	var z_sum = (lhs | _YX_MASK) + (rhs & _Z_MASK)
	return ((x_sum & _X_MASK) | (y_sum & _Y_MASK) | (z_sum & _Z_MASK))
	
## Return a Morton3 code with each x, y, z component 
## is remainder of [param lhs] subtracted by [param rhs]' counterparts.[br] 
static func sub(lhs: int, rhs: int) -> int:
	var x_diff = (lhs & _X_MASK) - (rhs & _X_MASK)
	var y_diff = (lhs & _Y_MASK) - (rhs & _Y_MASK)
	var z_diff = (lhs & _Z_MASK) - (rhs & _Z_MASK)
	return ((x_diff & _X_MASK) | (y_diff & _Y_MASK) | (z_diff & _Z_MASK))


## Return a copy of [param code] with x-component added by 1.[br]
static func inc_x(code: int) -> int:
	var x_sum = ((code | _ZY_MASK) + 1)
	return ((x_sum & _X_MASK) | (code & _ZY_MASK))
## Return a copy of [param code] with y-component added by 1.[br]
static func inc_y(code: int) -> int:
	var y_sum = ((code | _ZX_MASK) + 2)
	return ((y_sum & _Y_MASK) | (code & _ZX_MASK))
## Return a copy of [param code] with z-component added by 1.[br]
static func inc_z(code: int) -> int:
	var z_sum = ((code | _YX_MASK) + 4)
	return ((z_sum & _Z_MASK) | (code & _YX_MASK))

## Return a copy of [param code] with x-component subtracted by 1.[br]
static func dec_x(code: int) -> int:
	var x_diff = (code & _X_MASK) - 1
	return ((x_diff & _X_MASK) | (code & _ZY_MASK))
## Return a copy of [param code] with y-component subtracted by 1.[br]
static func dec_y(code: int) -> int:
	var y_diff = (code & _Y_MASK) - 2
	return ((y_diff & _Y_MASK) | (code & _ZX_MASK))
## Return a copy of [param code] with z-component subtracted by 1.[br]
static func dec_z(code: int) -> int:
	var z_diff = (code & _Z_MASK) - 4
	return ((z_diff & _Z_MASK) | (code & _YX_MASK))


## Return true if all components of [param lhs] 
## is greater than [param rhs] counterparts.[br]
static func gt(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) > (rhs & _X_MASK)\
		and (lhs & _Y_MASK) > (rhs & _Y_MASK)\
		and (lhs & _Z_MASK) > (rhs & _Z_MASK)
		
## Return true if all components of [param lhs] 
## is greater or equal to [param rhs] counterparts.[br]
static func ge(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) >= (rhs & _X_MASK)\
		and (lhs & _Y_MASK) >= (rhs & _Y_MASK)\
		and (lhs & _Z_MASK) >= (rhs & _Z_MASK)
		
## Return true if all components of [param lhs] 
## is less than [param rhs] counterparts.[br]
static func lt(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) < (rhs & _X_MASK)\
		and (lhs & _Y_MASK) < (rhs & _Y_MASK)\
		and (lhs & _Z_MASK) < (rhs & _Z_MASK)

## Return true if all components of [param lhs] 
## is less or equal to [param rhs] counterparts.[br]
static func le(lhs: int, rhs: int) -> bool:
	return (lhs & _X_MASK) <= (rhs & _X_MASK)\
		and (lhs & _Y_MASK) <= (rhs & _Y_MASK)\
		and (lhs & _Z_MASK) <= (rhs & _Z_MASK)


# Encode a value using Magic Bits algorithm.[br]
static func _encodeMB64(x: int) -> int:
	x &= 0x1FFFFF
	x = (x ^ (x<<32)) & 0b00000000_00011111_00000000_00000000_00000000_00000000_11111111_11111111
	x = (x ^ (x<<16)) & 0b00000000_00011111_00000000_00000000_11111111_00000000_00000000_11111111
	x = (x ^ (x<<8))  & 0b00010000_00001111_00000000_11110000_00001111_00000000_11110000_00001111
	x = (x ^ (x<<4))  & 0b00010000_11000011_00001100_00110000_11000011_00001100_00110000_11000011
	x = (x ^ (x<<2))  & _INTERPOSITION
	return x


# Decode a value using Magic Bits algorithm.[br]
static func _decodeMB64(x: int) -> int:
	x &= _INTERPOSITION
	x = (x ^ (x>>2))  & 0b00010000_11000011_00001100_00110000_11000011_00001100_00110000_11000011
	x = (x ^ (x>>4))  & 0b00010000_00001111_00000000_11110000_00001111_00000000_11110000_00001111
	x = (x ^ (x>>8))  & 0b00000000_00011111_00000000_00000000_11111111_00000000_00000000_11111111
	x = (x ^ (x>>16)) & 0b00000000_00011111_00000000_00000000_00000000_00000000_11111111_11111111
	x = (x ^ (x>>32)) & 0b00000000_00000000_00000000_00000000_00000000_00011111_11111111_11111111
	return x
	

static func _automated_test():
	var no_error = true
	for i in range(0, floor(64.0/3)):
		var value = 1 << i
		var encode_value = Morton3.encode64(value, 0, 0)
		var expected_value = 1 << (i*3)
		var decode_value = Morton3.decode_vec3i(expected_value).x
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
						
	# TODO: Add inc/dec add/sub tests
	
	if no_error:
		print("All Morton3 tests passed.")


const _INTERPOSITION = 0b001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001
const _Z_MASK = _INTERPOSITION << 2
const _Y_MASK = _INTERPOSITION << 1
const _X_MASK = _INTERPOSITION
const _ZY_MASK = _Z_MASK | _Y_MASK
const _ZX_MASK = _Z_MASK | _X_MASK
const _YX_MASK = _Y_MASK | _X_MASK
