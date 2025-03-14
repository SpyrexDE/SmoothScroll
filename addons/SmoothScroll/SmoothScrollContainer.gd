## Smooth scroll functionality for ScrollContainer
##
## Applies velocity based momentum and "overdrag"
## functionality to a ScrollContainer
@tool
extends ScrollContainer
class_name SmoothScrollContainer

@export_group("Mouse Wheel")
## Drag impact for one scroll input
@export_range(0, 10, 0.01, "or_greater", "hide_slider")
var speed := 1000.0
## ScrollDamper for wheel scrolling
@export
var wheel_scroll_damper: ScrollDamper = ExpoScrollDamper.new()

@export_group("Dragging")
## ScrollDamper for dragging
@export
var dragging_scroll_damper: ScrollDamper = ExpoScrollDamper.new()
### Allow dragging with mouse or not
@export
var drag_with_mouse := true
## Allow dragging with touch or not
@export
var drag_with_touch := true

@export_group("Container")
## Below this value, snap content to boundary
@export
var just_snap_under := 0.4
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
## Whether the content of this container should be allowed to overshoot at the ends
## before interpolating back to its bounds
@export
var allow_overdragging := true

@export_group("Scroll Bar")
## Hides scrollbar as long as not hovered or interacted with
@export
var hide_scrollbar_over_time := false:
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

@export_group("Input")
## If true sets the input event as handled with set_input_as_handled()
@export
var handle_input := true

@export_group("Debug")
## Adds debug information
@export
var debug_mode := false

## Current velocity of the `content_node`
var velocity := Vector2(0,0)
## Control node to move when scrolling
var content_node: Control
## Current position of `content_node`
var pos := Vector2(0, 0)
## Current ScrollDamper to use, recording to last input type
var scroll_damper: ScrollDamper
## When true, `content_node`'s position is only set by dragging the h scroll bar
var h_scrollbar_dragging := false
## When true, `content_node`'s position is only set by dragging the v scroll bar
var v_scrollbar_dragging := false
## When ture, `content_node` follows drag position
var content_dragging := false
## When ture, `content_node` has moved by dragging
var content_dragging_moved := false
## Timer for hiding scroll bar
var scrollbar_hide_timer := Timer.new()
## Tween for showing scroll bar
var scrollbar_show_tween: Tween
## Tween for hiding scroll bar
var scrollbar_hide_tween: Tween
## Tween for scroll x to
var scroll_x_to_tween: Tween
## Tween for scroll y to
var scroll_y_to_tween: Tween
## [0,1] Mouse or touch's relative movement accumulation when overdrag[br]
## [2,3] Position where dragging starts[br]
## [4,5,6,7] Left_distance, right_distance, top_distance, bottom_distance
var drag_temp_data := []
## Whether touch point is in deadzone.
var is_in_deadzone := false
## Whether mouse is on h or v scroll bar
var mouse_on_scrollbar := false

## If content is being scrolled
var is_scrolling := false:
	set(val):
		if is_scrolling != val:
			if val:
				emit_signal("scroll_started")
			else:
				emit_signal("scroll_ended")
		is_scrolling = val

## Last type of input used to scroll
enum SCROLL_TYPE {WHEEL, BAR, DRAG}
var last_scroll_type: SCROLL_TYPE

#region Virtual Functions

func _ready() -> void:
	if debug_mode:
		setup_debug_drawing()
	# Initialize variables
	scroll_damper = wheel_scroll_damper
	
	get_v_scroll_bar().gui_input.connect(_scrollbar_input.bind(true))
	get_h_scroll_bar().gui_input.connect(_scrollbar_input.bind(false))
	get_v_scroll_bar().mouse_entered.connect(_mouse_on_scroll_bar.bind(true))
	get_v_scroll_bar().mouse_exited.connect(_mouse_on_scroll_bar.bind(false))
	get_h_scroll_bar().mouse_entered.connect(_mouse_on_scroll_bar.bind(true))
	get_h_scroll_bar().mouse_exited.connect(_mouse_on_scroll_bar.bind(false))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

	for c in get_children():
		if not c is ScrollBar:
			content_node = c
	
	add_child(scrollbar_hide_timer)
	scrollbar_hide_timer.one_shot = true
	scrollbar_hide_timer.timeout.connect(_scrollbar_hide_timer_timeout)
	if hide_scrollbar_over_time:
		scrollbar_hide_timer.start(scrollbar_hide_time)
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	scroll(true, velocity.y, pos.y, delta)
	scroll(false, velocity.x, pos.x, delta)
	update_scrollbars()
	update_is_scrolling()

	if debug_mode:
		queue_redraw()

# Detecting mouse entering and exiting scroll bar
func _mouse_on_scroll_bar(entered: bool) -> void:
	mouse_on_scrollbar = entered

# Forwarding scroll inputs from scrollbar
func _scrollbar_input(event: InputEvent, vertical: bool) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN\
		or event.button_index == MOUSE_BUTTON_WHEEL_UP\
		or event.button_index == MOUSE_BUTTON_WHEEL_LEFT\
		or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_gui_input(event)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if vertical:
					v_scrollbar_dragging = true
					last_scroll_type = SCROLL_TYPE.BAR
					kill_scroll_to_tweens()
				else:
					h_scrollbar_dragging = true
					last_scroll_type = SCROLL_TYPE.BAR
					kill_scroll_to_tweens()
			else:
				if vertical:
					v_scrollbar_dragging = false
				else:
					h_scrollbar_dragging = false
	
	if event is InputEventScreenTouch:
		if event.pressed:
			if vertical:
				v_scrollbar_dragging = true
				last_scroll_type = SCROLL_TYPE.BAR
				kill_scroll_to_tweens()
			else:
				h_scrollbar_dragging = true
				last_scroll_type = SCROLL_TYPE.BAR
				kill_scroll_to_tweens()
		else:
			if vertical:
				v_scrollbar_dragging = false
			else:
				h_scrollbar_dragging = false

func _gui_input(event: InputEvent) -> void:
	# Show scroll bars when mouse moves
	if hide_scrollbar_over_time and event is InputEventMouseMotion:
		show_scrollbars()
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed or not should_scroll_vertical():
						if should_scroll_horizontal():
							velocity.x -= speed * event.factor
					else:
						if should_scroll_vertical():
							velocity.y -= speed  * event.factor
					scroll_damper = wheel_scroll_damper
					kill_scroll_to_tweens()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed or not should_scroll_vertical():
						if should_scroll_horizontal():
							velocity.x += speed * event.factor
					else:
						if should_scroll_vertical():
							velocity.y += speed * event.factor
					scroll_damper = wheel_scroll_damper
					kill_scroll_to_tweens()
			MOUSE_BUTTON_WHEEL_LEFT:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_vertical():
							velocity.y -= speed * event.factor
					else:
						if should_scroll_horizontal():
							velocity.x += speed * event.factor
					scroll_damper = wheel_scroll_damper
					kill_scroll_to_tweens()
			MOUSE_BUTTON_WHEEL_RIGHT:
				if event.pressed:
					last_scroll_type = SCROLL_TYPE.WHEEL
					if event.shift_pressed:
						if should_scroll_vertical():
							velocity.y += speed * event.factor
					else:
						if should_scroll_horizontal():
							velocity.x -= speed * event.factor
					scroll_damper = wheel_scroll_damper
					kill_scroll_to_tweens()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if !drag_with_mouse: return
					content_dragging = true
					is_in_deadzone = true
					scroll_damper = dragging_scroll_damper
					last_scroll_type = SCROLL_TYPE.DRAG
					init_drag_temp_data()
					kill_scroll_to_tweens()
				else:
					content_dragging = false
					is_in_deadzone = false
	
	if (event is InputEventScreenDrag and drag_with_touch) \
			or (event is InputEventMouseMotion and drag_with_mouse):
		if content_dragging:
			if should_scroll_horizontal():
				drag_temp_data[0] += event.relative.x
			if should_scroll_vertical():
				drag_temp_data[1] += event.relative.y
			remove_all_children_focus(self)
			handle_content_dragging()
	
	if event is InputEventPanGesture:
		if should_scroll_horizontal():
			velocity.x = -event.delta.x * speed
			kill_scroll_to_tweens()
		if should_scroll_vertical():
			velocity.y = -event.delta.y * speed
			kill_scroll_to_tweens()
	
	if event is InputEventScreenTouch:
		if event.pressed:
			if !drag_with_touch: return
			content_dragging = true
			is_in_deadzone = true
			scroll_damper = dragging_scroll_damper
			last_scroll_type = SCROLL_TYPE.DRAG
			init_drag_temp_data()
			kill_scroll_to_tweens()
		else:
			content_dragging = false
			is_in_deadzone = false
	# Handle input if handle_input is true
	if handle_input:
		get_tree().get_root().set_input_as_handled()

# Scroll to new focused element
func _on_focus_changed(control: Control) -> void:
	if follow_focus:
		self.ensure_control_visible(control)

func _draw() -> void:
	if debug_mode:
		draw_debug()

# Sets default mouse filter for SmoothScroll children to MOUSE_FILTER_PASS
func _on_node_added(node: Node) -> void:
	if node is Control and Engine.is_editor_hint():
		if is_ancestor_of(node):
			node.mouse_filter = Control.MOUSE_FILTER_PASS

func _scrollbar_hide_timer_timeout() -> void:
	if !any_scroll_bar_dragged():
		hide_scrollbars()

func _set_hide_scrollbar_over_time(value: bool) -> bool:
	if value == false:
		if scrollbar_hide_timer != null:
			scrollbar_hide_timer.stop()
		if scrollbar_show_tween != null:
			scrollbar_show_tween.kill()
		if scrollbar_hide_tween != null:
			scrollbar_hide_tween.kill()
		get_h_scroll_bar().modulate = Color.WHITE
		get_v_scroll_bar().modulate = Color.WHITE
	else:
		if scrollbar_hide_timer != null and scrollbar_hide_timer.is_inside_tree():
			scrollbar_hide_timer.start(scrollbar_hide_time)
	return value

func _get(property: StringName) -> Variant:
	match property:
		"scroll_horizontal":
			if !content_node: return 0
			return -int(content_node.position.x)
		"scroll_vertical":
			if !content_node: return 0
			return -int(content_node.position.y)
		_:
			return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"scroll_horizontal":
			if !content_node:
				scroll_horizontal = 0
				return true
			scroll_horizontal = value
			kill_scroll_x_to_tween()
			velocity.x = 0.0
			pos.x = clampf(
				-value as float,
				-get_child_size_x_diff(content_node, true),
				0.0
			)
			return true
		"scroll_vertical":
			if !content_node:
				scroll_vertical = 0
				return true
			scroll_vertical = value
			kill_scroll_y_to_tween()
			velocity.y = 0.0
			pos.y = clampf(
				-value as float,
				-get_child_size_y_diff(content_node, true),
				0.0
			)
			return true
		_:
			return false

#endregion

#region Scrolling Logic

func scroll(vertical: bool, axis_velocity: float, axis_pos: float, delta: float):
	# If no scroll needed, don't apply forces
	if vertical:
		if not should_scroll_vertical():
			return
	else:
		if not should_scroll_horizontal():
			return
	if !scroll_damper: return
	# Applies counterforces when overdragging
	if not content_dragging:
		axis_velocity = handle_overdrag(vertical, axis_velocity, axis_pos, delta)
		# Move content node by applying velocity
		var slide_result = scroll_damper.slide(axis_velocity, delta)
		axis_velocity = slide_result[0]
		axis_pos += slide_result[1]
		# Snap to boundary if close enough
		var snap_result = snap(vertical, axis_velocity, axis_pos)
		axis_velocity = snap_result[0]
		axis_pos = snap_result[1]
	else:
		# Preserve dragging velocity for 1 frame
		# in case no movement event while releasing dragging with touch
		if content_dragging_moved:
			content_dragging_moved = false
		else:
			axis_velocity = 0.0
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
				axis_pos = -get_child_size_y_diff(content_node, true)
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
				axis_pos = -get_child_size_x_diff(content_node, true)
				axis_velocity = 0.0
		
		content_node.position.x = axis_pos
		pos.x = axis_pos
		velocity.x = axis_velocity

func handle_overdrag(vertical: bool, axis_velocity: float, axis_pos: float, delta: float) -> float:
	if !scroll_damper: return 0.0
	# Calculate the size difference between this container and content_node
	var size_diff = get_child_size_y_diff(content_node, true) \
		if vertical else get_child_size_x_diff(content_node, true)
	# Calculate distance to left and right or top and bottom
	var dist1 = get_child_top_dist(axis_pos, size_diff) \
		if vertical else get_child_left_dist(axis_pos, size_diff)
	var dist2 = get_child_bottom_dist(axis_pos, size_diff) \
		if vertical else get_child_right_dist(axis_pos, size_diff)
	# Calculate velocity to left and right or top and bottom
	var target_vel1 = scroll_damper._calculate_velocity_to_dest(dist1, 0.0)
	var target_vel2 = scroll_damper._calculate_velocity_to_dest(dist2, 0.0)
	# Bounce when out of boundary. When velocity is not fast enough to go back, 
	# apply a opposite force and get a new velocity. If the new velocity is too fast, 
	# apply a velocity that makes it scroll back exactly.
	if axis_pos > 0.0:
		if axis_velocity > target_vel1:
			axis_velocity = scroll_damper.attract(
				dist1,
				0.0,
				axis_velocity,
				delta
			)
	if axis_pos < -size_diff:
		if axis_velocity < target_vel2:
			axis_velocity = scroll_damper.attract(
				dist2,
				0.0,
				axis_velocity,
				delta
			)
	
	return axis_velocity

# Snap to boundary if close enough in next frame
func snap(vertical: bool, axis_velocity: float, axis_pos: float) -> Array:
	# Calculate the size difference between this container and content_node
	var size_diff = get_child_size_y_diff(content_node, true) \
		if vertical else get_child_size_x_diff(content_node, true)
	# Calculate distance to left and right or top and bottom
	var dist1 = get_child_top_dist(axis_pos, size_diff) \
		if vertical else get_child_left_dist(axis_pos, size_diff)
	var dist2 = get_child_bottom_dist(axis_pos, size_diff) \
		if vertical else get_child_right_dist(axis_pos, size_diff)
	if (
		dist1 > 0.0 \
		and abs(dist1) < just_snap_under \
		and abs(axis_velocity) < just_snap_under \
	):
		axis_pos -= dist1
		axis_velocity = 0.0
	elif (
		dist2 < 0.0 \
		and abs(dist2) < just_snap_under \
		and abs(axis_velocity) < just_snap_under \
	):
		axis_pos -= dist2
		axis_velocity = 0.0
	
	return [axis_velocity, axis_pos]

## Returns true when scrollbar was dragged
func handle_scrollbar_drag() -> bool:
	if h_scrollbar_dragging:
		velocity.x = 0.0
		pos.x = -get_h_scroll_bar().value
		return true
	
	if v_scrollbar_dragging:
		velocity.y = 0.0
		pos.y = -get_v_scroll_bar().value
		return true
	return false

func handle_content_dragging() -> void:
	if !dragging_scroll_damper: return
	
	if(
		Vector2(drag_temp_data[0], drag_temp_data[1]).length() < scroll_deadzone \
		and is_in_deadzone
	):
		return
	elif is_in_deadzone == true:
		is_in_deadzone = false
		drag_temp_data[0] = 0.0
		drag_temp_data[1] = 0.0
	
	content_dragging_moved = true
	
	var calculate_dest = func(delta: float, damping: float) -> float:
		if delta >= 0.0:
			return delta / (1 + delta * damping * 0.00001)
		else:
			return delta
	
	var calculate_position = func(
		temp_dist1: float,		# Temp distance
		temp_dist2: float,
		temp_relative: float	# Event's relative movement accumulation
	) -> float:
		if temp_relative + temp_dist1 > 0.0:
			var delta = min(temp_relative, temp_relative + temp_dist1)
			var dest = calculate_dest.call(delta, dragging_scroll_damper._attract_factor)
			return dest - min(0.0, temp_dist1)
		elif temp_relative + temp_dist2 < 0.0:
			var delta = max(temp_relative, temp_relative + temp_dist2)
			var dest = -calculate_dest.call(-delta, dragging_scroll_damper._attract_factor)
			return dest - max(0.0, temp_dist2)
		else: return temp_relative
	
	if should_scroll_vertical():
		var y_pos = calculate_position.call(
			drag_temp_data[6],	# Temp top_distance
			drag_temp_data[7],	# Temp bottom_distance
			drag_temp_data[1]	# Temp y relative accumulation
		) + drag_temp_data[3]
		velocity.y = (y_pos - pos.y) / get_process_delta_time()
		pos.y = y_pos
	if should_scroll_horizontal():
		var x_pos = calculate_position.call(
			drag_temp_data[4],	# Temp left_distance
			drag_temp_data[5],	# Temp right_distance
			drag_temp_data[0]	# Temp x relative accumulation
		) + drag_temp_data[2]
		velocity.x = (x_pos - pos.x) / get_process_delta_time()
		pos.x = x_pos

func remove_all_children_focus(node: Node) -> void:
	if node is Control:
		var control = node as Control
		control.release_focus()
	
	for child in node.get_children():
		remove_all_children_focus(child)

func update_is_scrolling() -> void:
	if(
		(content_dragging and not is_in_deadzone)
		or any_scroll_bar_dragged()
		or velocity != Vector2.ZERO
	):
		is_scrolling = true
	else:
		is_scrolling = false

func update_scrollbars() -> void:
	# Update vertical scroll bar
	if get_v_scroll_bar().value != -pos.y:
		get_v_scroll_bar().set_value_no_signal(-pos.y)
		get_v_scroll_bar().queue_redraw()
	# Update horizontal scroll bar
	if get_h_scroll_bar().value != -pos.x:
		get_h_scroll_bar().set_value_no_signal(-pos.x)
		get_h_scroll_bar().queue_redraw()
	
	# Always show sroll bars when scrolling or mouse is on any scroll bar
	if hide_scrollbar_over_time and (is_scrolling or mouse_on_scrollbar):
		show_scrollbars()

func init_drag_temp_data() -> void:
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = get_child_size_diff(content_node, true, true)
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = get_child_boundary_dist(
		content_node.position,
		content_node_size_diff
	)
	drag_temp_data = [
		0.0, 
		0.0, 
		content_node.position.x,
		content_node.position.y,
		content_node_boundary_dist.x, 
		content_node_boundary_dist.y, 
		content_node_boundary_dist.z, 
		content_node_boundary_dist.w,
	]

# Get container size x without v scroll bar 's width
func get_spare_size_x() -> float:
	var size_x = size.x
	if get_v_scroll_bar().visible:
		size_x -= get_v_scroll_bar().size.x
	return max(size_x, 0.0)

# Get container size y without h scroll bar 's height
func get_spare_size_y() -> float:
	var size_y = size.y
	if get_h_scroll_bar().visible:
		size_y -= get_h_scroll_bar().size.y
	return max(size_y, 0.0)

# Get container size without scroll bars' size
func get_spare_size() -> Vector2:
	return Vector2(get_spare_size_x(), get_spare_size_y())

# Calculate the size x difference between this container and child node
func get_child_size_x_diff(child: Control, clamp: bool) -> float:
	var child_size_x = child.size.x * child.scale.x
	# Falsify the size of the child node to avoid errors 
	# when its size is smaller than this container 's
	if clamp:
		child_size_x = max(child_size_x, get_spare_size_x())
	return child_size_x - get_spare_size_x()

# Calculate the size y difference between this container and child node
func get_child_size_y_diff(child: Control, clamp: bool) -> float:
	var child_size_y = child.size.y * child.scale.y
	# Falsify the size of the child node to avoid errors 
	# when its size is smaller than this container 's
	if clamp:
		child_size_y = max(child_size_y, get_spare_size_y())
	return child_size_y - get_spare_size_y()

# Calculate the size difference between this container and child node
func get_child_size_diff(child: Control, clamp_x: bool, clamp_y: bool) -> Vector2:
	return Vector2(
		get_child_size_x_diff(child, clamp_x),
		get_child_size_y_diff(child, clamp_y)
	)

# Calculate distance to left
func get_child_left_dist(child_pos_x: float, child_size_diff_x: float) -> float:
	return child_pos_x

# Calculate distance to right
func get_child_right_dist(child_pos_x: float, child_size_diff_x: float) -> float:
	return child_pos_x + child_size_diff_x

# Calculate distance to top
func get_child_top_dist(child_pos_y: float, child_size_diff_y: float) -> float:
	return child_pos_y

# Calculate distance to bottom
func get_child_bottom_dist(child_pos_y: float, child_size_diff_y: float) -> float:
	return child_pos_y + child_size_diff_y

# Calculate distance to left, right, top and bottom
func get_child_boundary_dist(child_pos: Vector2, child_size_diff: Vector2) -> Vector4:
	return Vector4(
		get_child_left_dist(child_pos.x, child_size_diff.x),
		get_child_right_dist(child_pos.x, child_size_diff.x),
		get_child_top_dist(child_pos.y, child_size_diff.y),
		get_child_bottom_dist(child_pos.y, child_size_diff.y),
	)

func kill_scroll_x_to_tween() -> void:
	if scroll_x_to_tween: scroll_x_to_tween.kill()

func kill_scroll_y_to_tween() -> void:
	if scroll_y_to_tween: scroll_y_to_tween.kill()

func kill_scroll_to_tweens() -> void:
	kill_scroll_x_to_tween()
	kill_scroll_y_to_tween()

#endregion

#region Debug Drawing

var debug_gradient := Gradient.new()

func setup_debug_drawing() -> void:
	debug_gradient.set_color(0.0, Color.GREEN)
	debug_gradient.set_color(1.0, Color.RED)

func draw_debug() -> void:
	# Calculate the size difference between this container and content_node
	var size_diff = get_child_size_diff(content_node, false, false)
	# Calculate distance to left, right, top and bottom
	var boundary_dist = get_child_boundary_dist(
		content_node.position,
		size_diff
	)
	var bottom_distance = boundary_dist.w
	var top_distance = boundary_dist.z
	var right_distance = boundary_dist.y
	var left_distance = boundary_dist.x
	# Overdrag lines
	# Top + Bottom
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, top_distance), debug_gradient.sample(clamp(top_distance / size.y, 0.0, 1.0)), 5.0)
	draw_line(Vector2(0.0, size.y), Vector2(0.0, size.y+bottom_distance), debug_gradient.sample(clamp(-bottom_distance / size.y, 0.0, 1.0)), 5.0)
	# Left + Right
	draw_line(Vector2(0.0, size.y), Vector2(left_distance, size.y), debug_gradient.sample(clamp(left_distance / size.y, 0.0, 1.0)), 5.0)
	draw_line(Vector2(size.x, size.y), Vector2(size.x+right_distance, size.y), debug_gradient.sample(clamp(-right_distance / size.y, 0.0, 1.0)), 5.0)
	
	# Velocity lines
	var origin := Vector2(5.0, size.y/2)
	draw_line(origin, origin + Vector2(0.0, velocity.y*0.01), debug_gradient.sample(clamp(velocity.y*2 / size.y, 0.0, 1.0)), 5.0)
	draw_line(origin, origin + Vector2(0.0, velocity.x*0.01), debug_gradient.sample(clamp(velocity.x*2 / size.x, 0.0, 1.0)), 5.0)

#endregion

#region API Functions

## Scrolls to specific x position
func scroll_x_to(x_pos: float, duration := 0.5) -> void:
	if not should_scroll_horizontal(): return
	if content_dragging: return
	velocity.x = 0.0
	var size_x_diff = get_child_size_x_diff(content_node, true)
	x_pos = clampf(x_pos, -size_x_diff, 0.0)
	kill_scroll_x_to_tween()
	scroll_x_to_tween = create_tween()
	var tweener = scroll_x_to_tween.tween_property(self, "pos:x", x_pos, duration)
	tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

## Scrolls to specific y position
func scroll_y_to(y_pos: float, duration := 0.5) -> void:
	if not should_scroll_vertical(): return
	if content_dragging: return
	velocity.y = 0.0
	var size_y_diff = get_child_size_y_diff(content_node, true)
	y_pos = clampf(y_pos, -size_y_diff, 0.0)
	kill_scroll_y_to_tween()
	scroll_y_to_tween = create_tween()
	var tweener = scroll_y_to_tween.tween_property(self, "pos:y", y_pos, duration)
	tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

## Scrolls up a page
func scroll_page_up(duration := 0.5) -> void:
	var destination = content_node.position.y + get_spare_size_y()
	scroll_y_to(destination, duration)

## Scrolls down a page
func scroll_page_down(duration := 0.5) -> void:
	var destination = content_node.position.y - get_spare_size_y()
	scroll_y_to(destination, duration)

## Scrolls left a page
func scroll_page_left(duration := 0.5) -> void:
	var destination = content_node.position.x + get_spare_size_x()
	scroll_x_to(destination, duration)

## Scrolls right a page
func scroll_page_right(duration := 0.5) -> void:
	var destination = content_node.position.x - get_spare_size_x()
	scroll_x_to(destination, duration)

## Adds velocity to the vertical scroll
func scroll_vertically(amount: float) -> void:
	velocity.y -= amount

## Adds velocity to the horizontal scroll
func scroll_horizontally(amount: float) -> void:
	velocity.x -= amount

## Scrolls to top
func scroll_to_top(duration := 0.5) -> void:
	scroll_y_to(0.0, duration)

## Scrolls to bottom
func scroll_to_bottom(duration := 0.5) -> void:
	scroll_y_to(get_spare_size_y() - content_node.size.y, duration)

## Scrolls to left
func scroll_to_left(duration := 0.5) -> void:
	scroll_x_to(0.0, duration)

## Scrolls to right
func scroll_to_right(duration := 0.5) -> void:
	scroll_x_to(get_spare_size_x() - content_node.size.x, duration)

func is_outside_top_boundary(y_pos: float = pos.y) -> bool:
	var size_y_diff = get_child_size_y_diff(content_node,true)
	var top_dist = get_child_top_dist(y_pos, size_y_diff)
	return top_dist > 0.0

func is_outside_bottom_boundary(y_pos: float = pos.y) -> bool:
	var size_y_diff = get_child_size_y_diff(content_node,true)
	var bottom_dist = get_child_bottom_dist(y_pos, size_y_diff)
	return bottom_dist < 0.0

func is_outside_left_boundary(x_pos: float = pos.x) -> bool:
	var size_x_diff = get_child_size_x_diff(content_node,true)
	var left_dist = get_child_left_dist(x_pos, size_x_diff)
	return left_dist > 0.0

func is_outside_right_boundary(x_pos: float = pos.x) -> bool:
	var size_x_diff = get_child_size_x_diff(content_node,true)
	var right_dist = get_child_right_dist(x_pos, size_x_diff)
	return right_dist < 0.0

## Returns true if any scroll bar is being dragged
func any_scroll_bar_dragged() -> bool:
	return h_scrollbar_dragging or v_scrollbar_dragging

## Returns true if there is enough content height to scroll
func should_scroll_vertical() -> bool:
	var disable_scroll = (not allow_vertical_scroll) \
		or (auto_allow_scroll and get_child_size_y_diff(content_node, false) <= 0) \
		or !scroll_damper
	if disable_scroll:
		velocity.y = 0.0
		return false
	else:
		return true

## Returns true if there is enough content width to scroll
func should_scroll_horizontal() -> bool:
	var disable_scroll = (not allow_horizontal_scroll) \
		or (auto_allow_scroll and get_child_size_x_diff(content_node, false) <= 0) \
		or !scroll_damper
	if disable_scroll:
		velocity.x = 0.0
		return false
	else:
		return true

## Fades out scrollbars within given [param time].[br]
## Default for [param time] is current [member scrollbar_fade_out_time]
func hide_scrollbars(time: float = scrollbar_fade_out_time) -> void:
	# Kill scrollbar_show_tween to avoid animation conflict
	if scrollbar_show_tween != null and scrollbar_show_tween.is_valid():
		scrollbar_show_tween.kill()
	# Create new tweens if needed
	if (
		get_v_scroll_bar().modulate != Color.TRANSPARENT \
		or get_h_scroll_bar().modulate != Color.TRANSPARENT
	):
		if scrollbar_hide_tween and !scrollbar_hide_tween.is_running():
			scrollbar_hide_tween.kill()
		if scrollbar_hide_tween == null or !scrollbar_hide_tween.is_valid():
			scrollbar_hide_tween = create_tween()
			scrollbar_hide_tween.set_parallel(true)
			scrollbar_hide_tween.tween_property(get_v_scroll_bar(), 'modulate', Color.TRANSPARENT, time)
			scrollbar_hide_tween.tween_property(get_h_scroll_bar(), 'modulate', Color.TRANSPARENT, time)

## Fades in scrollbars within given [param time].[br]
## Default for [param time] is current [member scrollbar_fade_in_time]
func show_scrollbars(time: float = scrollbar_fade_in_time) -> void:
	# Restart timer
	scrollbar_hide_timer.start(scrollbar_hide_time)
	# Kill scrollbar_hide_tween to avoid animation conflict
	if scrollbar_hide_tween != null and scrollbar_hide_tween.is_valid():
		scrollbar_hide_tween.kill()
	# Create new tweens if needed
	if (
		get_v_scroll_bar().modulate != Color.WHITE \
		or get_h_scroll_bar().modulate != Color.WHITE \
	):
		if scrollbar_show_tween and !scrollbar_show_tween.is_running():
			scrollbar_show_tween.kill()
		if scrollbar_show_tween == null or !scrollbar_show_tween.is_valid():
			scrollbar_show_tween = create_tween()
			scrollbar_show_tween.set_parallel(true)
			scrollbar_show_tween.tween_property(get_v_scroll_bar(), 'modulate', Color.WHITE, time)
			scrollbar_show_tween.tween_property(get_h_scroll_bar(), 'modulate', Color.WHITE, time)

## Scroll to position to ensure the given control node is visible
func ensure_control_visible(control: Control) -> void:
	if !content_node: return
	if !content_node.is_ancestor_of(control): return
	if !scroll_damper: return
	
	var size_diff = (
		control.get_global_rect().size - get_global_rect().size
	) / (get_global_rect().size / size)
	var boundary_dist = get_child_boundary_dist(
		(control.global_position - global_position) \
				/ (get_global_rect().size / size),
		size_diff
	)
	var content_node_position = content_node.position
	if boundary_dist.x < 0 + follow_focus_margin:
		scroll_x_to(content_node_position.x - boundary_dist.x + follow_focus_margin)
	elif boundary_dist.y > 0 - follow_focus_margin:
		scroll_x_to(content_node_position.x - boundary_dist.y - follow_focus_margin)
	if boundary_dist.z < 0 + follow_focus_margin:
		scroll_y_to(content_node_position.y - boundary_dist.z + follow_focus_margin)
	elif boundary_dist.w > 0 - follow_focus_margin:
		scroll_y_to(content_node_position.y - boundary_dist.w - follow_focus_margin)

#endregion
