extends SceneTree

func _init():
	print("Running tests with Godot Editor caches...")
	var svo_link = load("res://src/svo_link.gd")
	var success = true
	var link1 = svo_link.from(1, 0, 0)
	var link2 = svo_link.from(1, 10, 5)
	var link3 = svo_link.from(2, 0, 0)
	var link4 = svo_link.from(0, 0, 0)
	var link5 = svo_link.from(15, 0, 0)

	if svo_link.not_same_layer(link1, link2):
		print("FAIL: not_same_layer should return false for link1 and link2")
		success = false

	if not svo_link.not_same_layer(link1, link3):
		print("FAIL: not_same_layer should return true for link1 and link3")
		success = false

	if not svo_link.not_same_layer(link1, link4):
		print("FAIL: not_same_layer should return true for link1 and link4")
		success = false

	if not svo_link.not_same_layer(link1, link5):
		print("FAIL: not_same_layer should return true for link1 and link5")
		success = false

	if success:
		print("SVOLink tests passed!")
		quit(0)
	else:
		print("SVOLink tests failed!")
		quit(1)
