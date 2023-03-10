## Smooth scroll functionality for ScrollContainer
##
## Applies velocity based momentum and "overdrag"
## functionality to a ScrollContainer
extends ScrollContainer

# Drag impact for one scroll input
@export_range(0, 10, 0.01, "or_greater")
var speed := 5.0
# Softness of damping when "overdragging" with wheel button
@export_range(0, 1)
var damping_scroll := 0.1
# Softness of damping when "overdragging" with dragging
@export_range(0, 1)
var damping_drag := 0.1
# Scrolls to currently focused child element
@export
var follow_focus_ := true
# Makes the container scrollable vertically
@export
var allow_vertical_scroll := true
# Makes the container scrollable horizontally
@export
var allow_horizontal_scroll := true
# Friction when using mouse wheel
@export_range(0, 1)
var friction_scroll := 0.9
# Friction when using touch
@export_range(0, 1)
var friction_drag := 0.9

# Current velocity of the `content_node`
var velocity := Vector2(0,0)
# Below this value, velocity is set to `0`
var just_stop_under := 0.01
# Below this value, snap content to boundary
var just_snap_under := 0.4
# Control node to move when scrolling
var content_node : Control
# Current position of `content_node`
var pos := Vector2(0, 0)
# When true, `content_node`'s position is only set by dragging the h scroll bar
var h_scrollbar_dragging := false
# When true, `content_node`'s position is only set by dragging the v scroll bar
var v_scrollbar_dragging := false
# Current friction
var friction := 0.9
# When ture, `content_node` follows drag position
var content_dragging = false
# Damping to use
var damping = 0.1
# Distance between content_node's bottom and bottom of the scroll box 
var bottom_distance := 0.0
# Distance between content_node and top of the scroll box
var top_distance := 0.0
# Distance between content_node's right and right of the scroll box 
var right_distance := 0.0
# Distance between content_node and left of the scroll box
var left_distance := 0.0
# Content node position where dragging starts
var drag_start_pos := Vector2.ZERO


func _ready() -> void:
	get_v_scroll_bar().scrolling.connect(_on_VScrollBar_scrolling)
	get_h_scroll_bar().scrolling.connect(_on_HScrollBar_scrolling)
	get_v_scroll_bar().gui_input.connect(_scrollbar_input)
	get_h_scroll_bar().gui_input.connect(_scrollbar_input)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	for c in get_children():
		if not c is ScrollBar:
			content_node = c

func _process(delta: float) -> void:
	calculate_distance()
	scroll_x()
	scroll_y()
	# Update vertical scroll bar
	get_v_scroll_bar().set_value_no_signal(-pos.y)
	get_v_scroll_bar().queue_redraw()
	# Update horizontal scroll bar
	get_h_scroll_bar().set_value_no_signal(-pos.x)
	get_h_scroll_bar().queue_redraw()

func calculate_distance():
	bottom_distance = content_node.position.y + content_node.size.y - self.size.y
	top_distance = content_node.position.y
	right_distance = content_node.position.x + content_node.size.x - self.size.x
	left_distance = content_node.position.x
	if get_v_scroll_bar().visible:
		right_distance += get_v_scroll_bar().size.x
	if get_h_scroll_bar().visible:
		bottom_distance += get_h_scroll_bar().size.y

func stop_frame(vel:float) -> float:
	# How long it will take to stop scrolling
	# 0.001 and 0.999 is to ensure that the denominator is not 0
	var stop_frame = log(just_stop_under/(abs(vel)+0.001))/log(friction*0.999)
	# Clamp and floor
	stop_frame = floor(max(stop_frame, 0.0))
	return stop_frame

func x_will_stop_inside(vel_x:float) -> bool:
	# Calculate stop frame
	var x_stop_frame = stop_frame(vel_x)
	# Distance it takes to stop scrolling
	var x_stop_distance = vel_x*(1-pow(friction,x_stop_frame))/(1-friction)
	# Position it will stop at
	var x_stop_pos = pos.x + x_stop_distance
	# Whether content node will stop inside the container
	return x_stop_pos <= 0.0 and x_stop_pos >= min(self.size.x - content_node.size.x, 0.0)

func y_will_stop_inside(vel_y:float) -> bool:
	# Calculate stop frame
	var y_stop_frame = stop_frame(vel_y)
	# Clamp and floor
	y_stop_frame = floor(max(y_stop_frame, 0.0))
	# Distance it takes to stop scrolling
	var y_stop_distance = vel_y*(1-pow(friction,y_stop_frame))/(1-friction)
	# Position it will stop at
	var y_stop_pos = pos.y + y_stop_distance
	# Whether content node will stop inside the container
	return y_stop_pos <= 0.0 and y_stop_pos >= min(self.size.y - content_node.size.y, 0.0)

func scroll_x():
	# If no scroll needed, don't apply forces
	if not should_scroll_horizontal():
		return
	
	# If velocity is too low, just set it to 0
	if abs(velocity.x) <= just_stop_under:
		velocity.x = 0.0
	
	# Applies counterforces when overdragging
	if not content_dragging:
		
		if right_distance < 0 and not x_will_stop_inside(velocity.x):
			# Apply bounce force
			velocity.x = lerp(velocity.x, -right_distance/8, damping)
			# If it will be fast enough to scroll back next frame
			# Apply a speed that will make it scroll back exactly
			if x_will_stop_inside(velocity.x):
				velocity.x = -right_distance*(1-friction)/(1-pow(friction, stop_frame(velocity.x))) 
			# Snap to boundary if close enough
			if right_distance > -just_snap_under:
				velocity.x = 0.0
				pos.x -= right_distance
		
		if left_distance > 0 and not x_will_stop_inside(velocity.x):
			# Apply bounce force
			velocity.x = lerp(velocity.x, -left_distance/8, damping)
			# If it will be fast enough to scroll back next frame
			# Apply a speed that will make it scroll back exactly
			if x_will_stop_inside(velocity.x):
				velocity.x = -left_distance*(1-friction)/(1-pow(friction, stop_frame(velocity.x))) 
			# Snap to boundary if close enough
			if left_distance < just_snap_under:
				velocity.x = 0.0
				pos.x -= left_distance
	
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if h_scrollbar_dragging:
		velocity.x = 0.0
		pos.x = content_node.position.x
		return
	
	# Move content node by applying velocity
	pos.x += velocity.x
	content_node.position.x = pos.x
	
	# Simulate friction
	velocity.x *= friction

func scroll_y():
	# If no scroll needed, don't apply forces
	if not should_scroll_vertical():
		return
	
	# If velocity is too low, just set it to 0
	if abs(velocity.y) <= just_stop_under:
		velocity.y = 0.0
	
	# Applies counterforces when overdragging
	if not content_dragging:
		
		if bottom_distance < 0 and not y_will_stop_inside(velocity.y):
			# Apply bounce force
			velocity.y = lerp(velocity.y, -bottom_distance/8, damping)
			# If it will be fast enough to scroll back next frame
			# Apply a speed that will make it scroll back exactly
			if y_will_stop_inside(velocity.y):
				velocity.y = -bottom_distance*(1-friction)/(1-pow(friction, stop_frame(velocity.y))) 
			# Snap to boundary if close enough
			if bottom_distance > -just_snap_under:
				velocity.y = 0.0
				pos.y -= bottom_distance
		
		if top_distance > 0 and not y_will_stop_inside(velocity.y):
			# Apply bounce force
			velocity.y = lerp(velocity.y, -top_distance/8, damping)
			# If it will be fast enough to scroll back next frame
			# Apply a speed that will make it scroll back exactly
			if y_will_stop_inside(velocity.y):
				velocity.y = -top_distance*(1-friction)/(1-pow(friction, stop_frame(velocity.y))) 
			# Snap to boundary if close enouh
			if top_distance < just_snap_under:
				velocity.y = 0.0
				pos.y -= top_distance
	
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if v_scrollbar_dragging:
		velocity.y = 0.0
		pos.y = content_node.position.y
		return
	
	# Move content node by applying velocity
	pos.y += velocity.y
	content_node.position.y = pos.y
	
	# Simulate friction
	velocity.y *= friction

func _scrollbar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN\
		or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_gui_input(event)

func _gui_input(event: InputEvent) -> void:
	v_scrollbar_dragging = get_v_scroll_bar().has_focus()
	h_scrollbar_dragging = get_h_scroll_bar().has_focus()
	
	if event is InputEventMouseButton:
		
		var scrolled = true
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					if event.shift_pressed:
						velocity.x -= speed
					else:
						velocity.y -= speed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					if event.shift_pressed:
						velocity.x += speed
					else:
						velocity.y += speed
			_:                  scrolled = false
			
		if scrolled: 
			friction = friction_scroll
			damping = damping_scroll
	
	if event is InputEventScreenDrag:
		if content_dragging:
			var y_delta = content_node.position.y - drag_start_pos.y
			var x_delta = content_node.position.x - drag_start_pos.x
			
			if top_distance > 0.0 and min(top_distance, y_delta) > 0.0: 
				velocity.y = event.relative.y/(1+min(top_distance, y_delta)*damping_drag)
			elif bottom_distance < 0.0 and max(bottom_distance, y_delta) < 0.0:
				velocity.y = event.relative.y/(1-max(bottom_distance, y_delta)*damping_drag)
			else: velocity.y = event.relative.y
			
			if left_distance > 0.0 and min(left_distance, x_delta) > 0.0: 
				velocity.x = event.relative.x/(1+min(left_distance, x_delta)*damping_drag)
			elif right_distance < 0.0 and max(right_distance, x_delta) < 0.0:
				velocity.x = event.relative.x/(1-max(right_distance, x_delta)*damping_drag)
			else: velocity.x = event.relative.x
	
	if event is InputEventScreenTouch:
		if event.pressed:
			content_dragging = true
			friction = 0.0
			drag_start_pos = content_node.position
		else:
			content_dragging = false
			friction = friction_drag
			damping = damping_drag
	# Handle input
	get_tree().get_root().set_input_as_handled()

# Scroll to new focused element
func _on_focus_changed(control: Control) -> void:
	var is_child := false
	if content_node.is_ancestor_of(control):
		is_child = true
	if not is_child:
		return
	if not follow_focus_:
		return
	
	var focus_size_x = control.size.x
	var focus_size_y = control.size.y
	var focus_left = control.global_position.x - self.global_position.x
	var focus_right = focus_left + focus_size_x
	var focus_top = control.global_position.y - self.global_position.y
	var focus_bottom = focus_top + focus_size_y
	
	if focus_top < 0.0:
		scroll_y_to(content_node.position.y - focus_top)
	
	if focus_bottom > self.size.y:
		scroll_y_to(content_node.position.y - focus_bottom + self.size.y)
	
	if focus_left < 0.0:
		scroll_x_to(content_node.position.x - focus_left)
	
	if focus_right > self.size.x:
		scroll_x_to(content_node.position.x - focus_right + self.size.x)

func _on_VScrollBar_scrolling() -> void:
	v_scrollbar_dragging = true

func _on_HScrollBar_scrolling() -> void:
	h_scrollbar_dragging = true

# Scrolls to specific x position
func scroll_x_to(x_pos: float, duration:float=0.5) -> void:
	if not should_scroll_horizontal(): return
	velocity.x = 0.0
	x_pos = clampf(x_pos, self.size.x-content_node.size.x, 0.0)
	var tween = create_tween()
	var tweener = tween.tween_property(self, "pos:x", x_pos, 0.5)
	tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

# Scrolls to specific y position
func scroll_y_to(y_pos: float, duration:float=0.5) -> void:
	if not should_scroll_vertical(): return
	velocity.y = 0.0
	y_pos = clampf(y_pos, self.size.y-content_node.size.y, 0.0)
	var tween = create_tween()
	var tweener = tween.tween_property(self, "pos:y", y_pos, duration)
	tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

# Scrolls up a page
func scroll_page_up(duration:float=0.5) -> void:
	var destination = content_node.position.y + self.size.y
	scroll_y_to(destination, duration)

# Scrolls down a page
func scroll_page_down(duration:float=0.5) -> void:
	var destination = content_node.position.y - self.size.y
	scroll_y_to(destination, duration)

# Scrolls left a page
func scroll_page_left(duration:float=0.5) -> void:
	var destination = content_node.position.x + self.size.x
	scroll_x_to(destination, duration)

# Scrolls right a page
func scroll_page_right(duration:float=0.5) -> void:
	var destination = content_node.position.x - self.size.x
	scroll_x_to(destination, duration)

# Adds velocity to the vertical scroll
func scroll_vertically(amount: float) -> void:
	velocity.y -= amount

# Adds velocity to the vertical scroll
func scroll_horizontally(amount: float) -> void:
	velocity.x -= amount

# Scrolls to top
func scroll_to_top(duration:float=0.5) -> void:
	scroll_y_to(0.0, duration)

# Scrolls to bottom
func scroll_to_bottom(duration:float=0.5) -> void:
	scroll_y_to(self.size.y - content_node.size.y, duration)

# Scrolls to left
func scroll_to_left(duration:float=0.5) -> void:
	scroll_x_to(0.0, duration)

# Scrolls to right
func scroll_to_right(duration:float=0.5) -> void:
	scroll_x_to(self.size.x - content_node.size.x, duration)

func any_scroll_bar_dragged() -> bool:
	if get_v_scroll_bar():
		return get_v_scroll_bar().has_focus()
	if get_h_scroll_bar():
		return get_h_scroll_bar().has_focus()
	return false

func should_scroll_vertical() -> bool:
	if content_node.size.y - self.size.y < 1:
		return false
	if not allow_vertical_scroll:
		velocity.y = 0.0
	return allow_vertical_scroll

func should_scroll_horizontal() -> bool:
	if content_node.size.x - self.size.x < 1:
		return false
	if not allow_horizontal_scroll:
		velocity.x = 0.0
	return allow_horizontal_scroll
