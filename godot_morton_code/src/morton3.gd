extends Morton
class_name Morton3

## Return a 64 bits Morton code, with x, y, z bits interleaved:[br]
## 0 z20 y20 x20 _ z19 y19 x19 z18 _ ... _ z0 y0 x0[br]
## [b]NOTE:[/b] The first bit is always left out.[br]
## [b]WARNING:[/b]Can't encode value > 2097151 (0x1FFFFF, 21 bits).[br]
## [param x]: Integer.[br]
## [param y]: Integer.[br]
## [param z]: Integer.[br]
static func encode64(x: int, y: int, z: int) -> int:
	return _encode_mb64(x) | (_encode_mb64(y)<<1) | (_encode_mb64(z)<<2)

## Like [method encode64]. Encode [param v]'s x, y, z components.[br]
## [param v]: Integer components.[br]
static func encode64v(v: Vector3i) -> int:
	return Morton3.encode64(v.x, v.y, v.z)


## Decode [param code] into x, y, z components of a Vector3.[br]
## [param code]: Bitmask.[br]
static func decode_vec3(code: int) -> Vector3:
	return Vector3(_decode_mb64(code & MASK_X),
					_decode_mb64((code >> 1) & MASK_X),
					_decode_mb64((code >> 2) & MASK_X))
					
					
## Decode [param code] into x, y, z components of a Vector3i.[br]
## [param code]: Bitmask.[br]
static func decode_vec3i(code: int) -> Vector3i:
	return Vector3i(_decode_mb64(code & MASK_X),
					_decode_mb64((code >> 1) & MASK_X),
					_decode_mb64((code >> 2) & MASK_X))

## Return a copy of [param morton] with x-component set to [param new_value].[br]
## [param morton]: Bitmask.[br]
## [param new_value]: Integer.[br]
static func set_x(morton: int, new_value: int) -> int:
	return morton & (~MASK_X) | Morton3._encode_mb64(new_value)
## Return a copy of [param morton] with y-component set to [param new_value].[br]
## [param morton]: Bitmask.[br]
## [param new_value]: Integer.[br]
static func set_y(morton: int, new_value: int) -> int:
	return morton & (~MASK_Y) | (Morton3._encode_mb64(new_value) << 1)
## Return a copy of [param morton] with z-component set to [param new_value].[br]
## [param morton]: Bitmask.[br]
## [param new_value]: Integer.[br]
static func set_z(morton: int, new_value: int) -> int:
	return morton & (~MASK_Z) | (Morton3._encode_mb64(new_value) << 2)


## Return a Morton3 code with each x, y, z component 
## is sum of [param lhs] and [param rhs]' counterparts.[br] 
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func add(lhs: int, rhs: int) -> int:
	var x_sum = (lhs | _ZY_MASK) + (rhs & MASK_X)
	var y_sum = (lhs | _ZX_MASK) + (rhs & MASK_Y)
	var z_sum = (lhs | _YX_MASK) + (rhs & MASK_Z)
	return ((x_sum & MASK_X) | (y_sum & MASK_Y) | (z_sum & MASK_Z))
	
## Return a Morton3 code with each x, y, z component 
## is remainder of [param lhs] subtracted by [param rhs]' counterparts.[br] 
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func sub(lhs: int, rhs: int) -> int:
	var x_diff = (lhs & MASK_X) - (rhs & MASK_X)
	var y_diff = (lhs & MASK_Y) - (rhs & MASK_Y)
	var z_diff = (lhs & MASK_Z) - (rhs & MASK_Z)
	return ((x_diff & MASK_X) | (y_diff & MASK_Y) | (z_diff & MASK_Z))


## Return a copy of [param code] with x-component added by
## [param x].[br]
## [param code]: Bitmask.[br]
## [param x]: Integer amount.[br]
static func add_x(code: int, x: int) -> int:
	var encoded_x = Morton3._encode_mb64(x)
	var x_sum = (code | _ZY_MASK) + encoded_x
	return ((x_sum & MASK_X) | (code & _ZY_MASK))

## Return a copy of [param code] with y-component added by
## [param y].[br]
## [param code]: Bitmask.[br]
## [param y]: Integer amount.[br]
static func add_y(code: int, y: int) -> int:
	var encoded_y = Morton3._encode_mb64(y) << 1
	var y_sum = (code | _ZX_MASK) + encoded_y
	return ((y_sum & MASK_Y) | (code & _ZX_MASK))

## Return a copy of [param code] with z-component added by
## [param z].[br]
## [param code]: Bitmask.[br]
## [param z]: Integer amount.[br]
static func add_z(code: int, z: int) -> int:
	var encoded_z = Morton3._encode_mb64(z) << 2
	var z_sum = (code | _YX_MASK) + encoded_z
	return ((z_sum & MASK_Z) | (code & _YX_MASK))

## Return a copy of [param code] with x-component subtracted by
## [param x].[br]
## [param code]: Bitmask.[br]
## [param x]: Integer amount.[br]
static func sub_x(code: int, x: int) -> int:
	var encoded_x = Morton3._encode_mb64(x)
	var x_diff = (code & MASK_X) - encoded_x
	return ((x_diff & MASK_X) | (code & _ZY_MASK))

## Return a copy of [param code] with y-component subtracted by
## [param y].[br]
## [param code]: Bitmask.[br]
## [param y]: Integer amount.[br]
static func sub_y(code: int, y: int) -> int:
	var encoded_y = Morton3._encode_mb64(y) << 1
	var y_diff = (code & MASK_Y) - encoded_y
	return ((y_diff & MASK_Y) | (code & _ZX_MASK))

## Return a copy of [param code] with z-component subtracted by
## [param z].[br]
## [param code]: Bitmask.[br]
## [param z]: Integer amount.[br]
static func sub_z(code: int, z: int) -> int:
	var encoded_z = Morton3._encode_mb64(z) << 2
	var z_diff = (code & MASK_Z) - encoded_z
	return ((z_diff & MASK_Z) | (code & _YX_MASK))


## Return a copy of [param code] with x-component added by 1.[br]
## [param code]: Bitmask.[br]
static func inc_x(code: int) -> int:
	var x_sum = ((code | _ZY_MASK) + 1)
	return ((x_sum & MASK_X) | (code & _ZY_MASK))
## Return a copy of [param code] with y-component added by 1.[br]
## [param code]: Bitmask.[br]
static func inc_y(code: int) -> int:
	var y_sum = ((code | _ZX_MASK) + 2)
	return ((y_sum & MASK_Y) | (code & _ZX_MASK))
## Return a copy of [param code] with z-component added by 1.[br]
## [param code]: Bitmask.[br]
static func inc_z(code: int) -> int:
	var z_sum = ((code | _YX_MASK) + 4)
	return ((z_sum & MASK_Z) | (code & _YX_MASK))

## Return a copy of [param code] with x-component subtracted by 1.[br]
## [param code]: Bitmask.[br]
static func dec_x(code: int) -> int:
	var x_diff = (code & MASK_X) - 1
	return ((x_diff & MASK_X) | (code & _ZY_MASK))
## Return a copy of [param code] with y-component subtracted by 1.[br]
## [param code]: Bitmask.[br]
static func dec_y(code: int) -> int:
	var y_diff = (code & MASK_Y) - 2
	return ((y_diff & MASK_Y) | (code & _ZX_MASK))
## Return a copy of [param code] with z-component subtracted by 1.[br]
## [param code]: Bitmask.[br]
static func dec_z(code: int) -> int:
	var z_diff = (code & MASK_Z) - 4
	return ((z_diff & MASK_Z) | (code & _YX_MASK))


## Return true if all components of [param lhs] 
## is greater than [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func gt(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) > (rhs & MASK_X)\
		and (lhs & MASK_Y) > (rhs & MASK_Y)\
		and (lhs & MASK_Z) > (rhs & MASK_Z)
		
## Return true if all components of [param lhs] 
## is greater or equal to [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func ge(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) >= (rhs & MASK_X)\
		and (lhs & MASK_Y) >= (rhs & MASK_Y)\
		and (lhs & MASK_Z) >= (rhs & MASK_Z)
		
## Return true if all components of [param lhs] 
## is less than [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func lt(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) < (rhs & MASK_X)\
		and (lhs & MASK_Y) < (rhs & MASK_Y)\
		and (lhs & MASK_Z) < (rhs & MASK_Z)

## Return true if all components of [param lhs] 
## is less or equal to [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func le(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) <= (rhs & MASK_X)\
		and (lhs & MASK_Y) <= (rhs & MASK_Y)\
		and (lhs & MASK_Z) <= (rhs & MASK_Z)


# Encode a value using Magic Bits algorithm.[br]
static func _encode_mb64(x: int) -> int:
	x &= 0x1FFFFF
	x = (x ^ (x<<32)) & 0b00000000_00011111_00000000_00000000_00000000_00000000_11111111_11111111
	x = (x ^ (x<<16)) & 0b00000000_00011111_00000000_00000000_11111111_00000000_00000000_11111111
	x = (x ^ (x<<8))  & 0b00010000_00001111_00000000_11110000_00001111_00000000_11110000_00001111
	x = (x ^ (x<<4))  & 0b00010000_11000011_00001100_00110000_11000011_00001100_00110000_11000011
	x = (x ^ (x<<2))  & MASK_X
	return x


# Decode a value using Magic Bits algorithm.[br]
static func _decode_mb64(x: int) -> int:
	x &= MASK_X
	x = (x ^ (x>>2))  & 0b00010000_11000011_00001100_00110000_11000011_00001100_00110000_11000011
	x = (x ^ (x>>4))  & 0b00010000_00001111_00000000_11110000_00001111_00000000_11110000_00001111
	x = (x ^ (x>>8))  & 0b00000000_00011111_00000000_00000000_11111111_00000000_00000000_11111111
	x = (x ^ (x>>16)) & 0b00000000_00011111_00000000_00000000_00000000_00000000_11111111_11111111
	x = (x ^ (x>>32)) & 0b00000000_00000000_00000000_00000000_00000000_00011111_11111111_11111111
	return x


const MASK_X = 0b0001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001_001
const MASK_Y = MASK_X << 1
const MASK_Z = MASK_X << 2
const MASK_XYZ = MASK_X | MASK_Y | MASK_Z
const _ZY_MASK = MASK_Z | MASK_Y
const _ZX_MASK = MASK_Z | MASK_X
const _YX_MASK = MASK_Y | MASK_X
