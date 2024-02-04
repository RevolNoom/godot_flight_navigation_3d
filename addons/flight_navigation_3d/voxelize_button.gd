@tool
extends Button

func show_please_wait() -> void:
	$PleaseWaitDialog.position = get_viewport().get_visible_rect().get_center()
	$PleaseWaitDialog.popup()

func show_on_complete() -> void:
	$OnCompleteDialog.position = get_viewport().get_visible_rect().get_center()
	$OnCompleteDialog.popup()
