## Smooth scroll functionality for ScrollContainer
##
## Applies velocity based momentum and "overdrag"
## functionality to a ScrollContainer
@tool
extends ScrollContainer

## Drag impact for one scroll input
@export_range(0, 10, 0.01, "or_greater")
var speed := 5.0
## Whether the content of this container should be allowed to overshoot at the ends
## before interpolating back to its bounds
@export
var allow_overdragging := true
## Softness of damping when "overdragging" with wheel button
@export_range(0, 1)
var damping_scroll := 0.1
## Softness of damping when "overdragging" with dragging
@export_range(0, 1)
var damping_drag := 0.1
## Scrolls to currently focused child element
@export
var follow_focus_ := true
## Margin of the currently focused element
@export_range(0, 50)
var follow_focus_margin := 20
## Makes the container scrollable vertically
@export
var allow_vertical_scroll := true
## Makes the container scrollable horizontally
@export
var allow_horizontal_scroll := true
## Makes the container only scrollable where the content has overflow
@export
var auto_allow_scroll := true
## Friction when using mouse wheel
@export_range(0, 1)
var friction_scroll := 0.9
## Friction when using touch
@export_range(0, 1)
var friction_drag := 0.9
## Hides scrollbar as long as not hovered or interacted with
@export
var hide_scrollbar_over_time:= false:
	set(val): hide_scrollbar_over_time = _set_hide_scrollbar_over_time(val)
## Time after scrollbar starts to fade out when 'hide_scrollbar_over_time' is true
@export
var scrollbar_hide_time := 5.0
## Fadein time for scrollbar when 'hide_scrollbar_over_time' is true
@export
var scrollbar_fade_in_time := 0.2
## Fadeout time for scrollbar when 'hide_scrollbar_over_time' is true
@export
var scrollbar_fade_out_time := 0.5
## Adds debug information
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
# Timer for hiding scroll bar
var scrollbar_hide_timer := Timer.new()
# Tween for hiding scroll bar
var scrollbar_hide_tween : Tween
# [0,1] Mouse or touch's relative movement accumulation when overdrag
# [2,3,4,5] Top_distance, bottom_distance, left_distance, right_distance
var drag_temp_data := []

# If content is being scrolled
var is_scrolling := false:
	set(val):
		is_scrolling = val
		if is_scrolling:
			emit_signal("scroll_started")
		else:
			emit_signal("scroll_ended")

# Last type of input used to scroll
enum SCROLL_TYPE {WHEEL, BAR, DRAG}
var last_scroll_type : SCROLL_TYPE

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
	
	add_child(scrollbar_hide_timer)
	scrollbar_hide_timer.timeout.connect(_scrollbar_hide_timer_timeout)
	if hide_scrollbar_over_time:
		scrollbar_hide_timer.start(scrollbar_hide_time)
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	calculate_distance()
	scroll(true, velocity.y, pos.y, delta)
	scroll(false, velocity.x, pos.x, delta)
	# Update vertical scroll bar
	get_v_scroll_bar().set_value_no_signal(-pos.y)
	get_v_scroll_bar().queue_redraw()
	# Update horizontal scroll bar
	get_h_scroll_bar().set_value_no_signal(-pos.x)
	get_h_scroll_bar().queue_redraw()
	# Update state
	update_state()

	if debug_mode:
		queue_redraw()

# Forwarding scroll inputs from scrollbar
func _scrollbar_input(event: InputEvent) -> void:
	if hide_scrollbar_over_time:
		show_scrollbars()
		scrollbar_hide_timer.start(scrollbar_hide_time)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN\
		or event.button_index == MOUSE_BUTTON_WHEEL_UP\
		or event.button_index == MOUSE_BUTTON_WHEEL_LEFT\
		or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_gui_input(event)

func _gui_input(event: InputEvent) -> void:
	if hide_scrollbar_over_time:
		show_scrollbars()
		scrollbar_hide_timer.start(scrollbar_hide_time)

	v_scrollbar_dragging = get_v_scroll_bar().has_focus() # != pressed => TODO
	h_scrollbar_dragging = get_h_scroll_bar().has_focus()
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_horizontal():
							velocity.x -= speed
					else:
						if should_scroll_vertical():
							velocity.y -= speed
					friction = friction_scroll
					damping = damping_scroll
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_horizontal():
							velocity.x += speed
					else:
						if should_scroll_vertical():
							velocity.y += speed
					friction = friction_scroll
					damping = damping_scroll
			MOUSE_BUTTON_WHEEL_LEFT:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_vertical():
							velocity.y -= speed
					else:
						if should_scroll_horizontal():
							velocity.x += speed
					friction = friction_scroll
					damping = damping_scroll
			MOUSE_BUTTON_WHEEL_RIGHT:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_vertical():
							velocity.y += speed
					else:
						if should_scroll_horizontal():
							velocity.x -= speed
					friction = friction_scroll
					damping = damping_scroll
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					content_dragging = true
					last_scroll_type = SCROLL_TYPE.DRAG
					friction = 0.0
					drag_start_pos = content_node.position
					init_drag_temp_data()
				else:
					content_dragging = false
					friction = friction_drag
					damping = damping_drag
	
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if content_dragging:
			is_scrolling = true
			if should_scroll_horizontal():
				drag_temp_data[0] += event.relative.x
			if should_scroll_vertical():
				drag_temp_data[1] += event.relative.y
			remove_all_children_focus(self)
			handle_content_dragging()
	
	if event is InputEventScreenTouch:
		if event.pressed:
			content_dragging = true
			last_scroll_type = SCROLL_TYPE.DRAG
			friction = 0.0
			drag_start_pos = content_node.position
			init_drag_temp_data()
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
	last_scroll_type = SCROLL_TYPE.BAR

func _on_HScrollBar_scrolling() -> void:
	h_scrollbar_dragging = true
	last_scroll_type = SCROLL_TYPE.BAR

func _draw() -> void:
	if debug_mode:
		draw_debug()

# Sets default mouse filter for SmoothScroll children to MOUSE_FILTER_PASS
func _on_node_added(node) -> void:
	if node is Control and Engine.is_editor_hint():
		if is_ancestor_of(node):
			node.mouse_filter = Control.MOUSE_FILTER_PASS

func _scrollbar_hide_timer_timeout() -> void:
	if !any_scroll_bar_dragged():
		hide_scrollbars()

func _set_hide_scrollbar_over_time(value) -> bool:
	if value == false:
		if scrollbar_hide_timer != null:
			scrollbar_hide_timer.stop()
		if scrollbar_hide_tween != null:
			scrollbar_hide_tween.kill()
		get_h_scroll_bar().modulate = Color.WHITE
		get_v_scroll_bar().modulate = Color.WHITE
	else:
		if scrollbar_hide_timer != null and scrollbar_hide_timer.is_inside_tree():
			scrollbar_hide_timer.start(scrollbar_hide_time)
	return value
##### Virtual functions
####################


####################
##### LOGIC

func scroll(vertical : bool, axis_velocity : float, axis_pos : float, delta : float):
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

		# Move content node by applying velocity
		axis_pos += axis_velocity * (pow(friction, delta*100) - 1) / log(friction)
		axis_velocity *= pow(friction, delta*100)
	
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if handle_scrollbar_drag():
		return
	
	if vertical:
		if not allow_overdragging:
			# Clamp if calculated position is beyond boundary
			if is_outside_top_boundary(axis_pos):
				axis_pos = 0.0
				axis_velocity = 0.0
			elif is_outside_bottom_boundary(axis_pos):
				axis_pos = self.size.y - content_node.size.y
				axis_velocity = 0.0

		content_node.position.y = axis_pos 
		pos.y = axis_pos
		velocity.y = axis_velocity
	else:
		if not allow_overdragging:
			# Clamp if calculated position is beyond boundary
			if is_outside_left_boundary(axis_pos):
				axis_pos = 0.0
				axis_velocity = 0.0
			elif is_outside_right_boundary(axis_pos):
				axis_pos = self.size.x - content_node.size.x
				axis_velocity = 0.0

		content_node.position.x = axis_pos
		pos.x = axis_pos
		velocity.x = axis_velocity

func handle_overdrag(vertical : bool, axis_velocity : float, axis_pos : float) -> Array:
	# Left/Right or Top/Bottom depending on x or y
	var dist1 = top_distance if vertical else left_distance
	var dist2 = bottom_distance if vertical else right_distance
	
	# Modify dist2 if content is smaller than container
	if vertical:
		var size_y = size.y
		if get_h_scroll_bar().visible:
			size_y -= get_h_scroll_bar().size.y
		dist2 += max(size_y - content_node.size.y, 0)
	else:
		var size_x = content_node.size.x
		if get_v_scroll_bar().visible:
			size_x -= get_v_scroll_bar().size.x
		dist2 += max(size_x - content_node.size.x, 0)
	
	var calculate = func(dist):
		# Apply bounce force
		axis_velocity = lerp(axis_velocity, -dist/8*get_process_delta_time()*100, damping)
		# If it will be fast enough to scroll back next frame
		# Apply a speed that will make it scroll back exactly
		if will_stop_within(vertical, axis_velocity):
			axis_velocity = -dist*(1-friction)/(1-pow(friction, stop_frame(axis_velocity)))

		return axis_velocity
	
	var result = [axis_velocity, axis_pos]
	
	if not (dist1 > 0 or dist2 < 0) or will_stop_within(vertical, axis_velocity):
		return result

	# Overdrag on top or left
	if dist1 > 0:
		# Snap to boundary if close enough
		if dist1 < just_snap_under and abs(axis_velocity) < just_snap_under:
			result[0] = 0.0
			result[1] -= dist1
		else: 
			result[0] = calculate.call(dist1)
	# Overdrag on bottom or right
	elif dist2 < 0:
		# Snap to boundary if close enough
		if dist2 > -just_snap_under and abs(axis_velocity) < just_snap_under:
			result[0] = 0.0
			result[1] -= dist2
		else:
			result[0] = calculate.call(dist2)
	
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

func handle_content_dragging() -> void:
	var calculate_dest = func(delta: float, damping: float) -> float:
		if delta >= 0.0:
			return delta / (1 + delta * damping * 0.1)
		else:
			return delta
	
	var calculate_position = func(
		temp_dist1: float,		# Temp distance
		temp_dist2: float,
		temp_relative: float	# Event's relative movement accumulation
	) -> float:
		if temp_relative + temp_dist1 > 0.0:
			var delta = min(temp_relative, temp_relative + temp_dist1)
			var dest = calculate_dest.call(delta, damping_drag)
			return dest - min(0.0, temp_dist1)
		elif temp_relative + temp_dist2 < 0.0:
			var delta = max(temp_relative, temp_relative + temp_dist2)
			var dest = -calculate_dest.call(-delta, damping_drag)
			return dest - max(0.0, temp_dist2)
		else: return temp_relative
	
	if should_scroll_vertical():
		var y_pos = calculate_position.call(
			drag_temp_data[2],	# Temp top_distance
			drag_temp_data[3],	# Temp bottom_distance
			drag_temp_data[1]	# Temp y relative accumulation
		) + drag_start_pos.y
		velocity.y = (y_pos - pos.y) / get_process_delta_time() / 100
		pos.y = y_pos
	if should_scroll_horizontal():
		var x_pos = calculate_position.call(
			drag_temp_data[4],	# Temp left_distance
			drag_temp_data[5],	# Temp right_distance
			drag_temp_data[0]	# Temp x relative accumulation
		) + drag_start_pos.x
		velocity.x = (x_pos - pos.x) / get_process_delta_time() / 100
		pos.x = x_pos

func calculate_distance() -> void:
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

func remove_all_children_focus(node : Node) -> void:
	if node is Control:
		var control = node as Control
		control.release_focus()
	
	for child in node.get_children():
		remove_all_children_focus(child)

func update_state() -> void:
	if content_dragging\
	or v_scrollbar_dragging\
	or h_scrollbar_dragging\
	or velocity != Vector2.ZERO:
		is_scrolling = true
	else:
		is_scrolling = false

func init_drag_temp_data() -> void:
	drag_temp_data = [0.0, 0.0, top_distance, bottom_distance, left_distance, right_distance]

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

func is_outside_top_boundary(y_pos: float = pos.y) -> bool:
	return y_pos > 0.0

func is_outside_bottom_boundary(y_pos: float = pos.y) -> bool:
	return y_pos < self.size.y - content_node.size.y

func is_outside_left_boundary(x_pos: float = pos.x) -> bool:
	return x_pos > 0.0

func is_outside_right_boundary(x_pos: float = pos.x) -> bool:
	return x_pos < self.size.x - content_node.size.x

# Returns true if any scroll bar is being dragged
func any_scroll_bar_dragged() -> bool:
	if get_v_scroll_bar():
		if get_v_scroll_bar().has_focus():
			return true
	if get_h_scroll_bar().has_focus():
			return true
	return false

# Returns true if there is enough content height to scroll
func should_scroll_vertical() -> bool:
	var disable_scroll = content_node.size.y - self.size.y < 1 or not allow_vertical_scroll\
			if auto_allow_scroll else not allow_vertical_scroll
	if disable_scroll:
		velocity.y = 0.0
		return false
	else:
		return true

# Returns true if there is enough content width to scroll
func should_scroll_horizontal() -> bool:
	var disable_scroll = content_node.size.x - self.size.x < 1 or not allow_horizontal_scroll\
			if auto_allow_scroll else not allow_horizontal_scroll
	if disable_scroll:
		velocity.x = 0.0
		return false
	else:
		return true

func hide_scrollbars() -> void:
	if scrollbar_hide_tween != null:
		scrollbar_hide_tween.kill()
	scrollbar_hide_tween = create_tween()
	scrollbar_hide_tween.set_parallel(true)
	scrollbar_hide_tween.tween_property(get_v_scroll_bar(), 'modulate', Color.TRANSPARENT, scrollbar_fade_out_time)
	scrollbar_hide_tween.tween_property(get_h_scroll_bar(), 'modulate', Color.TRANSPARENT, scrollbar_fade_out_time)

func show_scrollbars() -> void:
	if scrollbar_hide_tween != null:
		scrollbar_hide_tween.kill()
	scrollbar_hide_tween = create_tween()
	scrollbar_hide_tween.set_parallel(true)
	scrollbar_hide_tween.tween_property(get_v_scroll_bar(), 'modulate', Color.WHITE, scrollbar_fade_in_time)
	scrollbar_hide_tween.tween_property(get_h_scroll_bar(), 'modulate', Color.WHITE, scrollbar_fade_in_time)

##### API FUNCTIONS
########################
