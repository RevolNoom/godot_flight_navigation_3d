class_name SVOLink

static var NULL = ~0

## WARNING: Not checking valid value for performance 
static func from(layer: int, offset: int, subgrid: int = 0) -> int:
	return (layer << 60) | (offset << 6) | subgrid 

## 4 leftmost bits
static func layer(link: int) -> int:
	return link >> 60

## 6 rightmost bits
static func subgrid(link: int) -> int:
	return link & 0x3F

## The rest
static func offset(link: int) -> int:
	return (link << 4) >> 10

# @return true if they have different layer field values
static func in_diff_layers(link1: int, link2: int) -> bool: 
	return (link1^link2) & 0x0FFF_FFFF_FFFF_FFFF
