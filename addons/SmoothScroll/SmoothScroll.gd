extends Control

var v = Vector2(0,0) #current velocity
var just_stop_below = 0.01
export(float, -10, -1) var multi = -2 #speed of one input
var is_grabbed = false

var over_drag_multiplicator_top = 1
var over_drag_multiplicator_bottom = 1

var bottom_pos
var top_pos

export(float, 0, 1) var damping = 0.3

var margin = 10

func _process(delta):
	var d = delta
	bottom_pos = get_children()[0].rect_position.y + get_children()[0].rect_size.y - self.rect_size.y + margin
	top_pos = get_children()[0].rect_position.y - margin


	if v.length() <= just_stop_below:
		v = Vector2(0,0)
	
	if !(bottom_pos < 0 && v.y <= 0) && !(top_pos > 0 && v.y >= 0):
		v *= 0.9
	
	
	if bottom_pos < -20:	# This impulse force should get calculated by the bottom/top_pos and should already get applied on less/more then 0
		v.y = lerp(v.y, -bottom_pos/10, damping)
	elif top_pos > 20:
		v.y = lerp(v.y, -top_pos/10, damping)
	
	get_children()[0].rect_position += v


func _gui_input(event):
	#if bottom_pos < -1:
		if event is InputEventMouseButton:
			match event.button_index:
				BUTTON_WHEEL_UP:  v.y -= multi
				BUTTON_WHEEL_RIGHT: v.x += multi
				BUTTON_WHEEL_LEFT:  v.x -= multi
	#elif top_pos > 1:
		if event is InputEventMouseButton:
			match event.button_index:
				BUTTON_WHEEL_DOWN:    v.y += multi
				BUTTON_WHEEL_RIGHT: v.x += multi
				BUTTON_WHEEL_LEFT:  v.x -= multi
	#else:
		if event is InputEventMouseButton:
			match event.button_index:
				BUTTON_WHEEL_DOWN:    v.y += multi
				BUTTON_WHEEL_UP:  v.y -= multi
				BUTTON_WHEEL_RIGHT: v.x += multi
				BUTTON_WHEEL_LEFT:  v.x -= multi
