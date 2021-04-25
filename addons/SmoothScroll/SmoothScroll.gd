extends Control

var v = Vector2(0,0) #current velocity
var just_stop_under = 0.01
export(float, -10, -1) var multi = -2 #speed of one input
var is_grabbed = false

var over_drag_multiplicator_top = 1
var over_drag_multiplicator_bottom = 1

func _process(delta):
	var d = delta
	var bottom_pos = get_children()[0].rect_position.y + get_children()[0].rect_size.y - self.rect_size.y
	var top_pos = get_children()[0].rect_position.y
	# If overdragged:
	if bottom_pos < 0 :
		over_drag_multiplicator_bottom = 1/abs(bottom_pos)*10
	else:
		over_drag_multiplicator_bottom = 1
	if top_pos > 0:
		over_drag_multiplicator_top = 1/abs(top_pos*top_pos)*10
	else:
		over_drag_multiplicator_top = 1
	v *= 0.9
	if v.length() <= just_stop_under:
		v = Vector2(0,0)
	
	if not is_grabbed:
		if bottom_pos < -20 :
			v.y = +2
		if top_pos > 20:
			v.y = -2
			
	if is_grabbed:
		if bottom_pos < -20 || top_pos > 20:
			v.y = v.y / 2

	get_children()[0].rect_position += v


func _gui_input(event):

	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_MIDDLE:  is_grabbed = event.pressed

	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_WHEEL_DOWN:  v.y += multi
			BUTTON_WHEEL_UP:    v.y -= multi
			BUTTON_WHEEL_RIGHT: v.x += multi
			BUTTON_WHEEL_LEFT:  v.x -= multi

