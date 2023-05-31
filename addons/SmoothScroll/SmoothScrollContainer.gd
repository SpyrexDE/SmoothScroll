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
# Margin of the currently focused element
@export_range(0, 50)
var follow_focus_margin := 20
# Makes the container scrollable vertically
@export
var allow_vertical_scroll := true
# Makes the container scrollable horizontally
@export
var allow_horizontal_scroll := true
# Enables dragging content using touch input
@export
var enable_content_dragging_touch := true
# Enables dragging content using mouse input
@export
var enable_content_dragging_mouse := true
# Friction when using mouse wheel
@export_range(0, 1)
var friction_scroll := 0.9
# Friction when using touch
@export_range(0, 1)
var friction_drag := 0.9
# Adds debug information
@export
var debug_mode := false

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
var content_dragging := false
# Damping to use
var damping := 0.1
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


####################
##### Virtual functions

func _ready() -> void:
	if debug_mode:
		setup_debug_drawing()

	get_v_scroll_bar().scrolling.connect(_on_VScrollBar_scrolling)
	get_h_scroll_bar().scrolling.connect(_on_HScrollBar_scrolling)
	get_v_scroll_bar().gui_input.connect(_scrollbar_input)
	get_h_scroll_bar().gui_input.connect(_scrollbar_input)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	for c in get_children():
		if not c is ScrollBar:
			content_node = c
	
	if enable_content_dragging_touch or enable_content_dragging_mouse:
		remove_mouse_filter(content_node)

func _process(delta: float) -> void:
	calculate_distance()
	scroll(true, velocity.y, pos.y)
	scroll(false, velocity.x, pos.x)
	# Update vertical scroll bar
	get_v_scroll_bar().set_value_no_signal(-pos.y)
	get_v_scroll_bar().queue_redraw()
	# Update horizontal scroll bar
	get_h_scroll_bar().set_value_no_signal(-pos.x)
	get_h_scroll_bar().queue_redraw()

	if debug_mode:
		queue_redraw()

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
			MOUSE_BUTTON_LEFT:
				if enable_content_dragging_mouse:
					if event.pressed:
						content_dragging = true
						friction = 0.0
						drag_start_pos = content_node.position
					else:
						content_dragging = false
						friction = friction_drag
						damping = damping_drag
			_:                  scrolled = false
			
		if scrolled: 
			friction = friction_scroll
			damping = damping_scroll
	
	if event is InputEventScreenDrag or event is InputEventMouseMotion and enable_content_dragging_mouse:
		if content_dragging:
			remove_all_children_focus(self)
			handle_content_dragging(event.relative)
	
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
		scroll_y_to(content_node.position.y - focus_top + follow_focus_margin)
	
	if focus_bottom > self.size.y:
		scroll_y_to(content_node.position.y - focus_bottom + self.size.y - follow_focus_margin)
	
	if focus_left < 0.0:
		scroll_x_to(content_node.position.x - focus_left + follow_focus_margin)
	
	if focus_right > self.size.x:
		scroll_x_to(content_node.position.x - focus_right + self.size.x - follow_focus_margin)

func _on_VScrollBar_scrolling() -> void:
	v_scrollbar_dragging = true

func _on_HScrollBar_scrolling() -> void:
	h_scrollbar_dragging = true

func _draw() -> void:
	if debug_mode:
		draw_debug()

##### Virtual functions
####################


####################
##### LOGIC

func scroll(vertical : bool, axis_velocity : float, axis_pos : float):
	# If no scroll needed, don't apply forces
	if vertical:
		if not should_scroll_vertical():
			return
	else:
		if not should_scroll_horizontal():
			return
	
	# If velocity is too low, just set it to 0
	if abs(axis_velocity) <= just_stop_under:
		axis_velocity = 0.0
	
	# Applies counterforces when overdragging
	if not content_dragging:
		var result = handle_overdrag(vertical, axis_velocity, axis_pos)
		axis_velocity = result[0]
		axis_pos = result[1]
	
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if handle_scrollbar_drag():
		return
	
	# Move content node by applying velocity
	axis_pos += axis_velocity
	if vertical:
		content_node.position.y = axis_pos
		pos.y = axis_pos
		velocity.y = axis_velocity * friction
	else:
		content_node.position.x = axis_pos
		pos.x = axis_pos
		velocity.x = axis_velocity * friction

func handle_overdrag(vertical : bool, axis_velocity : float, axis_pos : float) -> Array:
	# Left/Right or Top/Bottom depending on x or y
	var dist1 = top_distance if vertical else left_distance
	var dist2 = bottom_distance if vertical else right_distance
	
	var calculate = func(dist):
		# Apply bounce force
		axis_velocity = lerp(axis_velocity, -dist/8, damping)
		# If it will be fast enough to scroll back next frame
		# Apply a speed that will make it scroll back exactly
		if will_stop_within(vertical, axis_velocity):
			axis_velocity = -dist*(1-friction)/(1-pow(friction, stop_frame(axis_velocity))) 
		# Snap to boundary if close enough
		if dist == top_distance && dist < just_snap_under || dist == bottom_distance && dist > -just_snap_under:
			axis_velocity = 0.0
			axis_pos -= dist
		return [axis_velocity, axis_pos]

	var result = [axis_velocity, axis_pos]
	
	# Overdrag on top
	if dist1 > 0 and not will_stop_within(vertical, axis_velocity):
		result = calculate.call(dist1)
	
	# Overdrag on bottom
	if dist2 < 0 and not will_stop_within(vertical, axis_velocity):
		result = calculate.call(dist2)
			
			
	return result

# Returns true when scrollbar was dragged
func handle_scrollbar_drag() -> bool:
	if h_scrollbar_dragging:
		velocity.x = 0.0
		pos.x = content_node.position.x
		return true
	
	if v_scrollbar_dragging:
		velocity.y = 0.0
		pos.y = content_node.position.y
		return true
	return false

func handle_content_dragging(relative : Vector2):
	var y_delta = content_node.position.y - drag_start_pos.y
	var x_delta = content_node.position.x - drag_start_pos.x

	var calculate_velocity = func(distance1: float, distance2: float, delta: float, relative: float) -> float:
		var vel = relative
		if distance1 > 0.0 and min(distance1, delta) > 0.0:
			vel = relative / (1 + min(distance1, delta) * damping_drag)
		elif distance2 < 0.0 and max(distance2, delta) < 0.0:
			vel = relative / (1 - max(distance2, delta) * damping_drag)
		return vel
	
	velocity.y = calculate_velocity.call(top_distance, bottom_distance, y_delta, relative.y)
	velocity.x = calculate_velocity.call(left_distance, right_distance, x_delta, relative.x)

func calculate_distance():
	bottom_distance = content_node.position.y + content_node.size.y - self.size.y
	top_distance = content_node.position.y
	right_distance = content_node.position.x + content_node.size.x - self.size.x
	left_distance = content_node.position.x
	if get_v_scroll_bar().visible:
		right_distance += get_v_scroll_bar().size.x
	if get_h_scroll_bar().visible:
		bottom_distance += get_h_scroll_bar().size.y

func stop_frame(vel : float) -> float:
	# How long it will take to stop scrolling
	# 0.001 and 0.999 is to ensure that the denominator is not 0
	var stop_frame = log(just_stop_under/(abs(vel)+0.001))/log(friction*0.999)
	# Clamp and floor
	stop_frame = floor(max(stop_frame, 0.0))
	return stop_frame

func will_stop_within(vertical : bool, vel : float) -> bool:
	# Calculate stop frame
	var stop_frame = stop_frame(vel)
	# Distance it takes to stop scrolling
	var stop_distance = vel*(1-pow(friction,stop_frame))/(1-friction)
	# Position it will stop at
	var stop_pos
	if vertical:
		stop_pos = pos.y + stop_distance
	else:
		stop_pos = pos.x + stop_distance

	var diff = self.size.y - content_node.size.y if vertical else self.size.x - content_node.size.x

	# Whether content node will stop inside the container
	return stop_pos <= 0.0 and stop_pos >= min(diff, 0.0)

# Needed to receive touch inputs
func remove_mouse_filter(node : Node):
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	for N in node.get_children():
		if N.get_child_count() > 0:
			N.mouse_filter = Control.MOUSE_FILTER_PASS
			remove_mouse_filter(N)
		else:
			N.mouse_filter = Control.MOUSE_FILTER_PASS

func remove_all_children_focus(node : Node):
	if node is Control:
		var control = node as Control
		control.release_focus()
	
	for child in node.get_children():
		remove_all_children_focus(child)

##### LOGIC
####################


####################
##### DEBUG DRAWING

var debug_gradient = Gradient.new()

func setup_debug_drawing() -> void:
	debug_gradient.set_color(0.0, Color.GREEN)
	debug_gradient.set_color(1.0, Color.RED)

func draw_debug() -> void:
	# Overdrag lines
	# Top + Bottom
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, top_distance), debug_gradient.sample(clamp(top_distance / size.y, 0.0, 1.0)), 5.0)
	draw_line(Vector2(0.0, size.y), Vector2(0.0, size.y+bottom_distance), debug_gradient.sample(clamp(-bottom_distance / size.y, 0.0, 1.0)), 5.0)
	# Left + Right
	draw_line(Vector2(0.0, size.y), Vector2(left_distance, size.y), debug_gradient.sample(clamp(left_distance / size.y, 0.0, 1.0)), 5.0)
	draw_line(Vector2(size.x, size.y), Vector2(size.x+right_distance, size.y), debug_gradient.sample(clamp(-right_distance / size.y, 0.0, 1.0)), 5.0)

	# Velocity lines
	var origin := Vector2(5.0, size.y/2)
	draw_line(origin, origin + Vector2(0.0, velocity.y), debug_gradient.sample(clamp(velocity.y*2 / size.y, 0.0, 1.0)), 5.0)
	draw_line(origin, origin + Vector2(0.0, velocity.x), debug_gradient.sample(clamp(velocity.x*2 / size.x, 0.0, 1.0)), 5.0)

##### DEBUG DRAWING
####################


####################
##### API FUNCTIONS

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

# Returns true if any scroll bar is being dragged
func any_scroll_bar_dragged() -> bool:
	if get_v_scroll_bar():
		return get_v_scroll_bar().has_focus()
	if get_h_scroll_bar():
		return get_h_scroll_bar().has_focus()
	return false

# Returns true if there is enough content height to scroll
func should_scroll_vertical() -> bool:
	if content_node.size.y - self.size.y < 1:
		return false
	if not allow_vertical_scroll:
		velocity.y = 0.0
	return allow_vertical_scroll

# Returns true if there is enough content width to scroll
func should_scroll_horizontal() -> bool:
	if content_node.size.x - self.size.x < 1:
		return false
	if not allow_horizontal_scroll:
		velocity.x = 0.0
	return allow_horizontal_scroll

##### API FUNCTIONS
########################
