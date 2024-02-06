@tool
extends Control

signal pressed
signal warning_confirmed

@onready var warning_dialog = $WarningDialog
@onready var please_wait_dialog = $PleaseWaitDialog
@onready var on_complete_dialog = $OnCompleteDialog
@onready var on_save_svo_error_dialog = $OnSaveSVOErrorDialog
@onready var _all_dialogs = [
	warning_dialog, 
	please_wait_dialog, 
	on_complete_dialog,
	on_save_svo_error_dialog,
	]

@onready var depth_choice = $HBoxContainer/DepthChoice

func _ready():
	(depth_choice.get_popup() as PopupMenu).id_pressed.connect(_on_depth_choice_id_pressed)

func get_depth() -> int:
	return depth_choice.text.to_int()

func show_warning_dialog() -> void:
	_show_dialog(warning_dialog)

func show_please_wait() -> void:
	_show_dialog(please_wait_dialog)

func show_on_complete() -> void:
	_show_dialog(on_complete_dialog)

func show_save_svo_error(errmsg: String):
	on_save_svo_error_dialog.dialog_text = errmsg
	_show_dialog(on_save_svo_error_dialog)

func _show_dialog(dialog: Window) -> void:
	_close_all_dialogs()
	dialog.move_to_center()
	dialog.popup()
	
func _close_all_dialogs() -> void:
	for dialog in _all_dialogs:
		dialog.hide()

func _on_depth_choice_id_pressed(id) -> void:
	depth_choice.text = str(id)

func _on_warning_dialog_confirmed() -> void:
	warning_confirmed.emit()

func _on_button_pressed() -> void:
	pressed.emit()
