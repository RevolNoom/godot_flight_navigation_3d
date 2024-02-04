@tool
extends Button

@onready var please_wait_dialog = $PleaseWaitDialog
@onready var on_complete_dialog = $OnCompleteDialog

func show_please_wait() -> void:
	please_wait_dialog.move_to_center()
	please_wait_dialog.popup()

func show_on_complete() -> void:
	on_complete_dialog.move_to_center()
	on_complete_dialog.popup()
