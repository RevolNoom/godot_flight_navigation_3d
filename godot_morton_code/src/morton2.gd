extends Morton
class_name Morton2

## Return a 64 bits Morton code, with x, y bits interleaved:[br]
## y31 x31 _ y30 x30 _ ... _ y0 x0[br]
## [b]WARNING:[/b] Can't encode value > 0xFFFF_FFFF, 32 bits).[br]
## [param x]: Integer.[br]
## [param y]: Integer.[br]
static func encode64(x: int, y: int) -> int:
	return _encode_mb64(x) | (_encode_mb64(y)<<1)

## Like [method encode64]. Encode [param v]'s x, y components.[br]
## [param v]: Integer components.[br]
static func encode64v(v: Vector2i) -> int:
	return Morton2.encode64(v.x, v.y)


## Decode [param code] into x, y components of a Vector2.[br]
## [param code]: Bitmask.[br]
static func decode_vec2(code: int) -> Vector2:
	return Vector2(_decode_mb64(code & MASK_X),
					_decode_mb64((code >> 1) & MASK_X))
					
## Decode [param code] into x, y components of a Vector2i.[br]
## [param code]: Bitmask.[br]
static func decode_vec2i(code: int) -> Vector2i:
	return Vector2i(_decode_mb64(code & MASK_X),
					_decode_mb64((code >> 1) & MASK_X))


## Return a copy of [param morton] with x-component set to [param new_value].[br]
## [param morton]: Bitmask.[br]
## [param new_value]: Integer.[br]
static func set_x(morton: int, new_value: int) -> int:
	return (morton & MASK_Y) | Morton2._encode_mb64(new_value)

## Return a copy of [param morton] with y-component set to [param new_value].[br]
## [param morton]: Bitmask.[br]
## [param new_value]: Integer.[br]
static func set_y(morton: int, new_value: int) -> int:
	return (morton & MASK_X) | (Morton2._encode_mb64(new_value) << 1)


## Return a Morton2 code with each x, y component 
## is sum of [param lhs] and [param rhs]' counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func add(lhs: int, rhs: int):
	var x_sum = (lhs | MASK_Y) + (rhs & MASK_X)
	var y_sum = (lhs | MASK_X) + (rhs & MASK_Y)
	return (x_sum & MASK_X) | (y_sum & MASK_Y)

## Return a Morton2 code with each x, y component 
## is remainder of [param lhs] subtracted by [param rhs]' counterparts.[br] 
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func sub(lhs: int, rhs: int):
	var x_diff = (lhs & MASK_X) - (rhs & MASK_X)
	var y_diff = (lhs & MASK_Y) - (rhs & MASK_Y)
	return ((x_diff & MASK_X) | (y_diff & MASK_Y))


## Return a copy of [param code] with x-component added by [param x].[br]
## [param code]: Bitmask.[br]
## [param x]: Integer amount.[br]
static func add_x(code: int, x: int) -> int:
	var encoded_x = Morton2._encode_mb64(x)
	var x_sum = (code | MASK_Y) + encoded_x
	return (x_sum & MASK_X) | (code & MASK_Y)

## Return a copy of [param code] with y-component added by [param y].[br]
## [param code]: Bitmask.[br]
## [param y]: Integer amount.[br]
static func add_y(code: int, y: int) -> int:
	var encoded_y = Morton2._encode_mb64(y) << 1
	var y_sum = (code | MASK_X) + encoded_y
	return (y_sum & MASK_Y) | (code & MASK_X)

## Return a copy of [param code] with x-component subtracted by [param x].[br]
## [param code]: Bitmask.[br]
## [param x]: Integer amount.[br]
static func sub_x(code: int, x: int) -> int:
	var encoded_x = Morton2._encode_mb64(x)
	var x_diff = (code & MASK_X) - encoded_x
	return (x_diff & MASK_X) | (code & MASK_Y)

## Return a copy of [param code] with y-component subtracted by [param y].[br]
## [param code]: Bitmask.[br]
## [param y]: Integer amount.[br]
static func sub_y(code: int, y: int) -> int:
	var encoded_y = Morton2._encode_mb64(y) << 1
	var y_diff = (code & MASK_Y) - encoded_y
	return (y_diff & MASK_Y) | (code & MASK_X)



## Return a copy of [param code] with x-component added by 1.[br]
## [param code]: Bitmask.[br]
static func inc_x(code: int) -> int:
	var x_sum = ((code | MASK_Y) + 1)
	return ((x_sum & MASK_X) | (code & MASK_Y))
	
## Return a copy of [param code] with y-component added by 1.[br]
## [param code]: Bitmask.[br]
static func inc_y(code: int) -> int:
	var y_sum = ((code | MASK_X) + 2)
	return ((y_sum & MASK_Y) | (code & MASK_X))


## Return a copy of [param code] with x-component subtracted by 1.[br]
## [param code]: Bitmask.[br]
static func dec_x(code: int) -> int:
	var x_diff = (code & MASK_X) - 1
	return (x_diff & MASK_X) | (code & MASK_Y)
	
## Return a copy of [param code] with y-component subtracted by 1.[br]
## [param code]: Bitmask.[br]
static func dec_y(code: int) -> int:
	var y_diff = (code & MASK_Y) - 2
	return (y_diff & MASK_Y) | (code & MASK_X)


## Return true if all components of [param lhs] 
## is greater than [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func gt(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) > (rhs & MASK_X)\
		and (lhs & MASK_Y) > (rhs & MASK_Y)
		
## Return true if all components of [param lhs] 
## is greater or equal to [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func ge(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) >= (rhs & MASK_X)\
		and (lhs & MASK_Y) >= (rhs & MASK_Y)

## Return true if all components of [param lhs] 
## is less than [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func lt(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) < (rhs & MASK_X)\
		and (lhs & MASK_Y) < (rhs & MASK_Y)

## Return true if all components of [param lhs] 
## is less or equal to [param rhs] counterparts.[br]
## [param lhs]: Bitmask.[br]
## [param rhs]: Bitmask.[br]
static func le(lhs: int, rhs: int) -> bool:
	return (lhs & MASK_X) <= (rhs & MASK_X)\
		and (lhs & MASK_Y) <= (rhs & MASK_Y)


# Encode a value using Magic Bits algorithm.[br]
static func _encode_mb64(x: int) -> int:
	x &= 0b00000000_00000000_00000000_00000000_11111111_11111111_11111111_11111111
	x = (x ^ (x<<16)) & 0b00000000_00000000_11111111_11111111_00000000_00000000_11111111_11111111
	x = (x ^ (x<< 8)) & 0b00000000_11111111_00000000_11111111_00000000_11111111_00000000_11111111
	x = (x ^ (x<< 4)) & 0b00001111_00001111_00001111_00001111_00001111_00001111_00001111_00001111
	x = (x ^ (x<< 2)) & 0b00110011_00110011_00110011_00110011_00110011_00110011_00110011_00110011
	x = (x ^ (x<< 1)) & MASK_X
	return x


# Decode a value using Magic Bits algorithm
static func _decode_mb64(x: int) -> int:
	x &= MASK_X
	x = (x ^ (x>> 1)) & 0b00110011_00110011_00110011_00110011_00110011_00110011_00110011_00110011
	x = (x ^ (x>> 2)) & 0b00001111_00001111_00001111_00001111_00001111_00001111_00001111_00001111
	x = (x ^ (x>> 4)) & 0b00000000_11111111_00000000_11111111_00000000_11111111_00000000_11111111
	x = (x ^ (x>> 8)) & 0b00000000_00000000_11111111_11111111_00000000_00000000_11111111_11111111
	x = (x ^ (x>>16)) & 0b00000000_00000000_00000000_00000000_11111111_11111111_11111111_11111111
	return x


const MASK_X = 0b01010101_01010101_01010101_01010101_01010101_01010101_01010101_01010101
const MASK_Y = MASK_X << 1
