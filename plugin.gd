@tool
extends EditorPlugin

var ai_panel
var panel_instance

func _enter_tree():
	ai_panel = preload("res://addons/godot_ai/ai_panel.gd")
	panel_instance = ai_panel.new()
	panel_instance.name = "GodotAI"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, panel_instance)
	print("GodotAI Plugin loaded!")

func _exit_tree():
	if panel_instance:
		remove_control_from_docks(panel_instance)
		panel_instance.queue_free()
