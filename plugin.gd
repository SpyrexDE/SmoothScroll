tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("SmoothScroll", "ScrollContainer", preload("SmoothScroll.gd"), preload("class-icon.svg"))


func _exit_tree():
	remove_custom_type("SmoothScroll")
