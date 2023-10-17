class SVONode:
	## Morton Code of the node
	var morton: int
	
	var parent: Link
	
	var first_child: Link
	
class Link:
	var value: int
	
	func layer() -> int:
		return 0
		
	## Is offset into _leaves nodes
	func subnode_idx() -> int:
		return 0
	
	## Is offset into _nodes array
	func node_idx() -> int:
		return 0
	
