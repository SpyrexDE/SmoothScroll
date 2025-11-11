class_name ScrollInputHandler
extends RefCounted
## Handles all input events for SmoothScrollContainer.
##
## Processes mouse wheel, dragging (mouse/touch), gestures, and scrollbar interactions.


#region Variables
## Reference to the parent scroll container
var _container: SmoothScrollContainer = null
## Mouse wheel scroll speed multiplier
var speed: float = 1000.0
## Allow dragging with mouse
var drag_with_mouse: bool = true
## Allow dragging with touch
var drag_with_touch: bool = true
## Handle input events
var handle_input: bool = true
## Whether content is currently being dragged
var content_dragging: bool = false
## Whether content has moved during current drag
var content_dragging_moved: bool = false
## Whether touch point is in deadzone
var is_in_deadzone: bool = false
## When true, horizontal scrollbar is being dragged
var h_scrollbar_dragging: bool = false
## When true, vertical scrollbar is being dragged
var v_scrollbar_dragging: bool = false
## Whether mouse is on any scrollbar
var mouse_on_scrollbar: bool = false
## Drag state data: [0,1] relative accumulation, [2,3] start pos, [4-7] boundary distances
var drag_temp_data: Array = []
#endregion


## Initializes the input handler with a reference to the [param container].
func _init(container: SmoothScrollContainer) -> void:
	_container = container


## Processes GUI input events for scrolling. [br]
## Handles mouse wheel, dragging, pan gestures, and touch events from [param event].
func process_gui_input(event: InputEvent) -> void:
	# Show scrollbars on mouse motion
	if _container.hide_scrollbar_over_time and event is InputEventMouseMotion:
		_container.scrollbar_animator.show_scrollbars()
	
	# Mouse button events (wheel scrolling and drag start/end)
	if event is InputEventMouseButton:
		_process_mouse_button(event)
	
	# Drag motion events
	if (event is InputEventScreenDrag and drag_with_touch) \
			or (event is InputEventMouseMotion and drag_with_mouse):
		_process_drag_motion(event)
	
	# Pan gesture events
	if event is InputEventPanGesture:
		_process_pan_gesture(event)
	
	# Touch events
	if event is InputEventScreenTouch:
		_process_screen_touch(event)
	
	# Mark input as handled if configured
	if handle_input:
		_container.get_tree().get_root().set_input_as_handled()


## Processes scrollbar input events from [param event]. [br]
## Handles both [param vertical] and horizontal scrollbar interactions.
func process_scrollbar_input(event: InputEvent, vertical: bool) -> void:
	if event is InputEventMouseButton:
		# Forward wheel events to main input handler
		if event.button_index in [
			MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_UP,
			MOUSE_BUTTON_WHEEL_LEFT,
			MOUSE_BUTTON_WHEEL_RIGHT
		]:
			process_gui_input(event)
		
		# Handle scrollbar dragging
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_scrollbar_drag_button(event, vertical)
	
	if event is InputEventScreenTouch:
		_handle_scrollbar_touch(event, vertical)


## Called when mouse enters or exits scrollbar area based on [param entered].
func on_mouse_scrollbar(entered: bool) -> void:
	mouse_on_scrollbar = entered


## Checks if any scrollbar is being dragged.
func any_scrollbar_dragging() -> bool:
	return h_scrollbar_dragging or v_scrollbar_dragging


## Initializes drag temporary data with current position and boundary distances.
func init_drag_temp_data() -> void:
	var spare_size: Vector2 = ScrollLayout.get_spare_size(_container, _container.content_margins)
	var content_node_size_diff: Vector2 = ScrollLayout.get_child_size_diff(
		_container.content_node,
		spare_size,
		true,
		true
	)
	var content_node_boundary_dist: Vector4 = ScrollLayout.get_boundary_dist(
		_container.pos,
		content_node_size_diff
	)
	drag_temp_data = [
		0.0,  # X relative accumulation
		0.0,  # Y relative accumulation
		_container.pos.x,  # X start position
		_container.pos.y,  # Y start position
		content_node_boundary_dist.x,  # Left distance
		content_node_boundary_dist.y,  # Right distance
		content_node_boundary_dist.z,  # Top distance
		content_node_boundary_dist.w,  # Bottom distance
	]


## Processes mouse button events for wheel scrolling and dragging from [param event].
func _process_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_handle_wheel_scroll(event, false, true)  # Down direction
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_handle_wheel_scroll(event, true, true)  # Up direction
		MOUSE_BUTTON_WHEEL_LEFT:
			if event.pressed:
				_handle_wheel_scroll(event, true, false)  # Left direction
		MOUSE_BUTTON_WHEEL_RIGHT:
			if event.pressed:
				_handle_wheel_scroll(event, false, false)  # Right direction
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_content_drag()
			else:
				_end_content_drag()


## Handles mouse wheel scrolling from [param event]. [br]
## Scrolls in [param positive] direction (up/left or down/right) for the specified axis ([param is_vertical]).
func _handle_wheel_scroll(event: InputEventMouseButton, positive: bool, is_vertical: bool) -> void:
	_container.last_scroll_type = SmoothScrollContainer.SCROLL_TYPE.WHEEL
	_container.scroll_damper = _container.wheel_scroll_damper
	_container.scrollbar_animator.kill_scroll_tweens()
	
	var amount: float = speed * event.factor * (1.0 if positive else -1.0)
	
	# Determine which axis to scroll based on shift key and available scroll directions
	if is_vertical:
		if event.shift_pressed or not _container.should_scroll_vertical():
			if _container.should_scroll_horizontal():
				_container.velocity.x += amount
		else:
			if _container.should_scroll_vertical():
				_container.velocity.y += amount
	else:  # Horizontal wheel
		if event.shift_pressed:
			if _container.should_scroll_vertical():
				_container.velocity.y += amount if positive else -amount
		else:
			if _container.should_scroll_horizontal():
				_container.velocity.x += amount


## Starts content dragging.
func _start_content_drag() -> void:
	if not drag_with_mouse: return
	
	content_dragging = true
	is_in_deadzone = true
	_container.scroll_damper = _container.dragging_scroll_damper
	_container.last_scroll_type = SmoothScrollContainer.SCROLL_TYPE.DRAG
	init_drag_temp_data()
	_container.scrollbar_animator.kill_scroll_tweens()


## Ends content dragging.
func _end_content_drag() -> void:
	content_dragging = false
	is_in_deadzone = false


## Processes drag motion events with relative movement from [param event].
func _process_drag_motion(event) -> void:
	if not content_dragging: return
	
	if _container.should_scroll_horizontal():
		drag_temp_data[0] += event.relative.x
	if _container.should_scroll_vertical():
		drag_temp_data[1] += event.relative.y
	
	_remove_all_children_focus(_container)
	_container.handle_content_dragging()


## Processes pan gesture events from [param event].
func _process_pan_gesture(event: InputEventPanGesture) -> void:
	if _container.should_scroll_horizontal():
		_container.velocity.x = -event.delta.x * speed
		_container.scrollbar_animator.kill_scroll_tweens()
	if _container.should_scroll_vertical():
		_container.velocity.y = -event.delta.y * speed
		_container.scrollbar_animator.kill_scroll_tweens()


## Processes screen touch events from [param event].
func _process_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not drag_with_touch:
			return
		
		content_dragging = true
		is_in_deadzone = true
		_container.scroll_damper = _container.dragging_scroll_damper
		_container.last_scroll_type = SmoothScrollContainer.SCROLL_TYPE.DRAG
		init_drag_temp_data()
		_container.scrollbar_animator.kill_scroll_tweens()
	else:
		content_dragging = false
		is_in_deadzone = false


## Handles scrollbar dragging with mouse button from [param event]. [br]
## Processes [param vertical] or horizontal scrollbar interactions.
func _handle_scrollbar_drag_button(event: InputEventMouseButton, vertical: bool) -> void:
	if event.pressed:
		if vertical:
			v_scrollbar_dragging = true
		else:
			h_scrollbar_dragging = true
		_container.last_scroll_type = SmoothScrollContainer.SCROLL_TYPE.BAR
		_container.scrollbar_animator.kill_scroll_tweens()
	else:
		if vertical:
			v_scrollbar_dragging = false
		else:
			h_scrollbar_dragging = false


## Handles scrollbar dragging with touch from [param event]. [br]
## Processes [param vertical] or horizontal scrollbar interactions.
func _handle_scrollbar_touch(event: InputEventScreenTouch, vertical: bool) -> void:
	if event.pressed:
		if vertical:
			v_scrollbar_dragging = true
		else:
			h_scrollbar_dragging = true
		_container.last_scroll_type = SmoothScrollContainer.SCROLL_TYPE.BAR
		_container.scrollbar_animator.kill_scroll_tweens()
	else:
		if vertical:
			v_scrollbar_dragging = false
		else:
			h_scrollbar_dragging = false


## Recursively removes focus from the specified [param node] and all its children.
func _remove_all_children_focus(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.release_focus()
	
	for child: Node in node.get_children():
		_remove_all_children_focus(child)
