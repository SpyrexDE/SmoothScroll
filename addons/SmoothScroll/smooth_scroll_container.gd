@tool
class_name SmoothScrollContainer
extends ScrollContainer
## Smooth scroll functionality for ScrollContainer.
##
## Applies velocity based momentum and "overdrag"
## functionality to a ScrollContainer.


#region Variables
## Last type of input used to scroll
enum SCROLL_TYPE {
	## Mouse wheel scrolling
	WHEEL,
	## Scrollbar dragging
	BAR,
	## Content dragging
	DRAG
}

#region Exported Variables
@export_group("Mouse Wheel")
## Drag impact for one scroll input
@export_range(0.0, 10.0, 0.01, "or_greater", "hide_slider") var speed: float = 1000.0
## ScrollDamper for wheel scrolling
@export var wheel_scroll_damper: ScrollDamper = ExpoScrollDamper.new()

@export_group("Dragging")
## ScrollDamper for dragging
@export var dragging_scroll_damper: ScrollDamper = ExpoScrollDamper.new()
## Allow dragging with mouse or not
@export var drag_with_mouse: bool = true
## Allow dragging with touch or not
@export var drag_with_touch: bool = true

@export_group("Container")
## Below this value, snap content to boundary
@export var just_snap_under: float = 0.4
## Margin of the currently focused element
@export_range(0, 50) var follow_focus_margin: int = 20
## Makes the container scrollable vertically
@export var allow_vertical_scroll: bool = true
## Makes the container scrollable horizontally
@export var allow_horizontal_scroll: bool = true
## Makes the container only scrollable where the content has overflow
@export var auto_allow_scroll: bool = true
## Whether the content of this container should be allowed to overshoot at the ends
## before interpolating back to its bounds
@export var allow_overdragging: bool = true

@export_group("Scroll Bar")
## Hides scrollbar as long as not hovered or interacted with
@export var hide_scrollbar_over_time: bool = false:
	set(val): hide_scrollbar_over_time = _set_hide_scrollbar_over_time(val)
## Time after scrollbar starts to fade out when 'hide_scrollbar_over_time' is true
@export var scrollbar_hide_time: float = 5.0
## Fadein time for scrollbar when 'hide_scrollbar_over_time' is true
@export var scrollbar_fade_in_time: float = 0.2
## Fadeout time for scrollbar when 'hide_scrollbar_over_time' is true
@export var scrollbar_fade_out_time: float = 0.5

@export_group("Input")
## If true sets the input event as handled with set_input_as_handled()
@export var handle_input: bool = true
## If true, automatically sets child Control nodes' mouse_filter to MOUSE_FILTER_PASS
## to ensure smooth scrolling works properly.
@export var override_mouse_filters: bool = true:
	set(val): override_mouse_filters = _set_override_mouse_filters(val)

@export_group("Debug")
## Adds debug information
@export var debug_mode: bool = false
#endregion

#region Public Variables
## Current velocity of the `content_node`
var velocity := Vector2.ZERO
## Control node to move when scrolling
var content_node: Control
## Current position of `content_node`
var pos := Vector2(0, 0)
## Current ScrollDamper to use, according to last input type
var scroll_damper: ScrollDamper
## If content is being scrolled
var is_scrolling: bool = false:
	set(val):
		if is_scrolling != val:
			if val:
				emit_signal("scroll_started")
			else:
				emit_signal("scroll_ended")
		is_scrolling = val
## Last type of input used to scroll
var last_scroll_type: SCROLL_TYPE
#endregion

#region Private Variables
## StyleBox content margins (left, top, right, bottom)
var content_margins := Vector4.ZERO
## True while margins/layout are being (re)applied; disables scrolling
var _initializing_margins: bool = false
## Baseline layout offset applied by StyleBox/content
var _base_offset := Vector2.ZERO
## True after first margin/layout initialization; gates follow_focus during startup
var _startup_done: bool = false
## True if initial margin calculation was skipped due to being hidden
var _initial_margins_skipped: bool = false
## Scrollbar animator for fade in/out effects and scroll tweens
var scrollbar_animator: ScrollbarAnimator
## Input handler for all user input events
var input_handler: ScrollInputHandler
## Cache is_editor_hint() value for performance
var _is_editor_hint = Engine.is_editor_hint()

## Cache last known size to detect size changes for follow_focus deferral
var _last_ensure_size := Vector2.ZERO
## Counter to track frames of size stability
var _size_stable_frames := 0
## Pending control to scroll to after size stabilizes
var _pending_ensure_control: Control = null
## Timer to check for size stability
var _ensure_stability_timer: Timer = null
#endregion

#endregion


#region Native Functions
## Called when the node enters the scene tree for the first time. [br]
## Sets up scrollbars, timers, and initial configuration.
func _ready() -> void:
	if not ScrollDebugger.debug_gradient: ScrollDebugger.setup_debug_drawing()
	
	# Initialize variables
	scroll_damper = wheel_scroll_damper
	scrollbar_animator = ScrollbarAnimator.new(self)
	scrollbar_animator.hide_time = scrollbar_hide_time
	scrollbar_animator.fade_in_time = scrollbar_fade_in_time
	scrollbar_animator.fade_out_time = scrollbar_fade_out_time
	
	# Initialize input handler
	input_handler = ScrollInputHandler.new(self)
	input_handler.speed = speed
	input_handler.drag_with_mouse = drag_with_mouse
	input_handler.drag_with_touch = drag_with_touch
	input_handler.handle_input = handle_input
	
	get_v_scroll_bar().gui_input.connect(_scrollbar_input.bind(true))
	get_h_scroll_bar().gui_input.connect(_scrollbar_input.bind(false))
	get_v_scroll_bar().mouse_entered.connect(_mouse_on_scroll_bar.bind(true))
	get_v_scroll_bar().mouse_exited.connect(_mouse_on_scroll_bar.bind(false))
	get_h_scroll_bar().mouse_entered.connect(_mouse_on_scroll_bar.bind(true))
	get_h_scroll_bar().mouse_exited.connect(_mouse_on_scroll_bar.bind(false))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

	visibility_changed.connect(_visibility_changed)
	theme_changed.connect(_update_content_margins)
	
	# Check if we're initially hidden - if so, defer margin calculation until visible
	if visible:
		call_deferred("_update_content_margins")
	else:
		_initial_margins_skipped = true

	for child: Node in get_children():
		if child is Control and not child is ScrollBar:
			content_node = child
			break
	
	if content_node:
		_base_offset = content_node.position
	
	if hide_scrollbar_over_time:
		scrollbar_animator.start_hide_timer()
	
	if override_mouse_filters:
		get_tree().node_added.connect(_on_node_added)
		if not _is_editor_hint:
			call_deferred("_apply_mouse_filters_to_children")
	
	# Default to idle state until needed
	set_process(false)


## Called every frame. Updates scroll position, velocity, and scrollbar state.
func _process(delta: float) -> void:
	if _is_editor_hint: return
	if _initializing_margins: return

	scroll(true, velocity.y, pos.y, delta)
	scroll(false, velocity.x, pos.x, delta)
	update_scrollbars()
	update_is_scrolling()

	if debug_mode: queue_redraw()
	
	if not is_scrolling:
		set_process(false)
#endregion


#region Input Handling
## Detects when mouse enters or exits scroll bar areas. Triggers appropriate visibility behavior based on [param entered].
func _mouse_on_scroll_bar(entered: bool) -> void:
	input_handler.on_mouse_scrollbar(entered)


## Forwards scroll inputs from the specified scrollbar to the input handler. [br]
## Handles both [param vertical] and horizontal scrollbar [param event] inputs.
func _scrollbar_input(event: InputEvent, vertical: bool) -> void:
	set_process(true)
	input_handler.process_scrollbar_input(event, vertical)


## Handles all GUI input events by delegating them to the input handler.
func _gui_input(event: InputEvent) -> void:
	set_process(true)
	input_handler.process_gui_input(event)


## Scrolls to ensure the newly focused [param control] is visible when focus changes.
func _on_focus_changed(control: Control) -> void:
	if follow_focus and _startup_done:
		self.ensure_control_visible_smooth(control)


## Draws debug information when debug mode is enabled.
func _draw() -> void:
	if debug_mode: ScrollDebugger.draw_debug(self)


## Sets default mouse filter for SmoothScroll children to [constant Control.MOUSE_FILTER_PASS]. [br]
## Called when a [param node] is added to the tree.
func _on_node_added(node: Node) -> void:
	if node is Control and is_ancestor_of(node):
		if override_mouse_filters:
			if not node.has_meta("_smooth_scroll_default_mouse_filter_set"):
				node.mouse_filter = Control.MOUSE_FILTER_PASS
				node.set_meta("_smooth_scroll_default_mouse_filter_set", true)


## Called when the scrollbar hide timer times out. Hides scrollbars when neither scrollbar is being dragged.
func _scrollbar_hide_timer_timeout() -> void:
	if scrollbar_animator.should_hide(input_handler.h_scrollbar_dragging, input_handler.v_scrollbar_dragging):
		scrollbar_animator.hide_scrollbars()


## Updates content margins from the current StyleBox. [br]
## Captures baseline offset and clears velocity to keep scroll math in margin-free space.
func _update_content_margins() -> void:
	set_process(true)
	_initializing_margins = true
	
	content_margins = ScrollLayout.get_content_margins(self)
	
	if content_node:
		_base_offset = ScrollLayout.calculate_base_offset(content_margins)
		
		if _initial_margins_skipped:
			pos = Vector2.ZERO
		
		if not _startup_done:
			velocity = Vector2.ZERO
	
	call_deferred("_end_margin_init")


## Finalizes margin initialization by resetting the initializing flag.
func _end_margin_init() -> void:
	_initializing_margins = false
	_startup_done = true
	_initial_margins_skipped = false


## Called when visibility changes. Updates margins when needed.
func _visibility_changed() -> void:
	if visible and content_node:
		if _initial_margins_skipped:
			call_deferred("_update_content_margins")
		
		elif _startup_done:
			call_deferred("_update_content_margins")


## Setter for [member hide_scrollbar_over_time]. Controls whether scrollbars automatically hide over time based on [param value].
func _set_hide_scrollbar_over_time(value: bool) -> bool:
	if value == false:
		if scrollbar_animator:
			scrollbar_animator.stop_hide_timer()
			scrollbar_animator.show_scrollbars_immediate()
	else:
		if scrollbar_animator:
			scrollbar_animator.start_hide_timer()
	return value


## Setter for [member override_mouse_filters]. Applies mouse filter to existing children when enabled at runtime.
func _set_override_mouse_filters(value: bool) -> bool:
	if is_inside_tree():
		if value:
			if not get_tree().node_added.is_connected(_on_node_added):
				get_tree().node_added.connect(_on_node_added)
			if not _is_editor_hint:
				call_deferred("_apply_mouse_filters_to_children")
		else:
			if get_tree().node_added.is_connected(_on_node_added):
				get_tree().node_added.disconnect(_on_node_added)
	return value


## Applies MOUSE_FILTER_PASS to all child Control nodes recursively.
func _apply_mouse_filters_to_children() -> void:
	_apply_mouse_filter_recursive(self)


## Recursively applies mouse filter to Control nodes.
func _apply_mouse_filter_recursive(node: Node) -> void:
	if node is Control and node != self and is_ancestor_of(node):
		if not node.has_meta("_smooth_scroll_default_mouse_filter_set"):
			node.mouse_filter = Control.MOUSE_FILTER_PASS
			node.set_meta("_smooth_scroll_default_mouse_filter_set", true)
	
	for child in node.get_children():
		_apply_mouse_filter_recursive(child)


## Getter for [member scroll_horizontal] and [member scroll_vertical] properties. [br]
## Returns the scroll value for the specified [param property].
func _get(property: StringName) -> Variant:
	match property:
		"scroll_horizontal":
			if not content_node: return 0
			return -int(pos.x)
		
		"scroll_vertical":
			if not content_node: return 0
			return -int(pos.y)
		
		_:
			return null


## Setter for [member scroll_horizontal] and [member scroll_vertical] properties. [br]
## Sets the specified [param property] to [param value] and updates scroll position accordingly.
func _set(property: StringName, value: Variant) -> bool:
	match property:
		"scroll_horizontal":
			if not content_node:
				scroll_horizontal = 0
				return true
			
			if _initializing_margins: return true

			scroll_horizontal = value
			scrollbar_animator.kill_scroll_x_tween()
			velocity.x = 0.0
			var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
			pos.x = clampf(
				-value as float,
				-ScrollLayout.get_child_size_x_diff(content_node, spare_size_x, true),
				0.0
			)
			# Wake up process to ensure scrollbars update visually
			set_process(true) 
			return true
		
		"scroll_vertical":
			if not content_node:
				scroll_vertical = 0
				return true
			
			if _initializing_margins: return true

			scroll_vertical = value
			scrollbar_animator.kill_scroll_y_tween()
			velocity.y = 0.0
			var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
			pos.y = clampf(
				-value as float,
				-ScrollLayout.get_child_size_y_diff(content_node, spare_size_y, true),
				0.0
			)
			# Important: Wake up process to ensure scrollbars update visually
			set_process(true)
			return true
		_:
			return false
#endregion


#region Scrolling Logic
## Handles scrolling along a single axis. Applies velocity damping, overdrag forces, and boundary snapping. [br]
## Processes scrolling for either [param vertical] or horizontal axis based on [param axis_velocity], 
## [param axis_pos], and [param delta] time.
func scroll(vertical: bool, axis_velocity: float, axis_pos: float, delta: float) -> void:
	# Special case: If delta is 0, we treat this as a forced position set (teleport)
	# This allows callers to reset scroll state manually (e.g. scroll(true, 0, 0, 0))
	if is_zero_approx(delta):
		if vertical:
			velocity.y = axis_velocity
			pos.y = axis_pos
			if content_node:
				content_node.position.y = _base_offset.y + axis_pos
			if get_v_scroll_bar(): get_v_scroll_bar().set_value_no_signal(-axis_pos)
		else:
			velocity.x = axis_velocity
			pos.x = axis_pos
			if content_node:
				content_node.position.x = _base_offset.x + axis_pos
			if get_h_scroll_bar(): get_h_scroll_bar().set_value_no_signal(-axis_pos)
		return

	# If no scroll needed, don't apply forces
	if vertical:
		if not should_scroll_vertical(): 
			# Ensures position resets to 0 if content fits and auto-scroll disabled it
			if auto_allow_scroll and pos.y != 0 and content_node:
				var spare = ScrollLayout.get_spare_size_y(self, content_margins)
				var diff = ScrollLayout.get_child_size_y_diff(content_node, spare, false)
				if diff <= 0:
					velocity.y = 0.0
					pos.y = 0.0
					content_node.position.y = _base_offset.y + pos.y
			return
	
	else:
		if not should_scroll_horizontal(): 
			# Ensures position resets to 0 if content fits and auto-scroll disabled it
			if auto_allow_scroll and pos.x != 0 and content_node:
				var spare = ScrollLayout.get_spare_size_x(self, content_margins)
				var diff = ScrollLayout.get_child_size_x_diff(content_node, spare, false)
				if diff <= 0:
					velocity.x = 0.0
					pos.x = 0.0
					content_node.position.x = _base_offset.x + pos.x
			return
	
	if not scroll_damper: return
	# Applies counterforces when overdragging
	if not input_handler.content_dragging:
		axis_velocity = handle_overdrag(vertical, axis_velocity, axis_pos, delta)
		# Move content node by applying velocity
		var slide_result: Array = scroll_damper.slide(axis_velocity, delta)
		axis_velocity = slide_result[0]
		axis_pos += slide_result[1]
		# Snap to boundary if close enough
		var snap_result: Array = snap(vertical, axis_velocity, axis_pos)
		axis_velocity = snap_result[0]
		axis_pos = snap_result[1]
	else:
		# Preserve dragging velocity for 1 frame
		# in case no movement event while releasing dragging with touch
		if input_handler.content_dragging_moved:
			input_handler.content_dragging_moved = false
		else:
			axis_velocity = 0.0
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if handle_scrollbar_drag():	return
	
	if vertical:
		if not allow_overdragging:
			# Clamp if calculated position is beyond boundary
			var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
			var size_diff_y: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size_y, true)

			if ScrollLayout.is_outside_top_boundary(axis_pos):
				axis_pos = 0.0
				axis_velocity = 0.0
			
			elif ScrollLayout.is_outside_bottom_boundary(axis_pos, size_diff_y):
				axis_pos = -size_diff_y
				axis_velocity = 0.0
		content_node.position.y = _base_offset.y + axis_pos
		pos.y = axis_pos
		velocity.y = axis_velocity
	
	else:
		if not allow_overdragging:
			# Clamp if calculated position is beyond boundary
			var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
			var size_diff_x: float = ScrollLayout.get_child_size_x_diff(content_node, spare_size_x, true)

			if ScrollLayout.is_outside_left_boundary(axis_pos):
				axis_pos = 0.0
				axis_velocity = 0.0
			
			elif ScrollLayout.is_outside_right_boundary(axis_pos, size_diff_x):
				axis_pos = -size_diff_x
				axis_velocity = 0.0
			
		content_node.position.x = _base_offset.x + axis_pos
		pos.x = axis_pos
		velocity.x = axis_velocity


## Applies counterforces when content is dragged beyond boundaries. [br]
## Calculates and applies attraction forces for the specified [param vertical] or horizontal axis
## based on [param axis_velocity], [param axis_pos], and [param delta] time.
func handle_overdrag(vertical: bool, axis_velocity: float, axis_pos: float, delta: float) -> float:
	if not scroll_damper: return 0.0
	
	var spare_size: Vector2 = ScrollLayout.get_spare_size(self, content_margins)
	var size_diff: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size.y, true) if vertical \
		else ScrollLayout.get_child_size_x_diff(content_node, spare_size.x, true)
	
	return ScrollPhysics.apply_overdrag(scroll_damper, axis_pos, axis_velocity, size_diff, delta)


## Snaps content to boundary when velocity and distance are both below threshold. [br]
## Checks the specified [param vertical] or horizontal axis with [param axis_velocity] and [param axis_pos]. [br]
## Returns [code][velocity, position][/code] array with potentially snapped values.
func snap(vertical: bool, axis_velocity: float, axis_pos: float) -> Array:
	var spare_size: Vector2 = ScrollLayout.get_spare_size(self, content_margins)
	var size_diff: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size.y, true) if vertical \
		else ScrollLayout.get_child_size_x_diff(content_node, spare_size.x, true)
	
	return ScrollPhysics.apply_snap(axis_velocity, axis_pos, size_diff, just_snap_under)


## Handles scrollbar drag input and updates content position accordingly. [br]
## Returns [code]true[/code] when a scrollbar was being dragged.
func handle_scrollbar_drag() -> bool:
	if input_handler.h_scrollbar_dragging:
		velocity.x = 0.0
		pos.x = -get_h_scroll_bar().value
		content_node.position.x = _base_offset.x + pos.x
		return true
	
	if input_handler.v_scrollbar_dragging:
		velocity.y = 0.0
		pos.y = -get_v_scroll_bar().value
		content_node.position.y = _base_offset.y + pos.y
		return true
	
	return false


## Handles content dragging with overdrag resistance when dragged beyond boundaries.
func handle_content_dragging() -> void:
	if not dragging_scroll_damper: return
	
	if Vector2(input_handler.drag_temp_data[0], input_handler.drag_temp_data[1]).length() < scroll_deadzone and input_handler.is_in_deadzone:
		return
	
	elif input_handler.is_in_deadzone == true:
		input_handler.is_in_deadzone = false
		input_handler.drag_temp_data[0] = 0.0
		input_handler.drag_temp_data[1] = 0.0
	
	input_handler.content_dragging_moved = true
	
	if should_scroll_vertical():
		var y_pos: float = ScrollPhysics.calculate_drag_position(
			input_handler.drag_temp_data[6],  # Temp top_distance
			input_handler.drag_temp_data[7],  # Temp bottom_distance
			input_handler.drag_temp_data[1],  # Temp y relative accumulation
			input_handler.drag_temp_data[3],  # Y position where dragging started
			dragging_scroll_damper._attract_factor
		)
		velocity.y = (y_pos - pos.y) / get_process_delta_time()
		pos.y = y_pos
		content_node.position.y = _base_offset.y + y_pos
	
	if should_scroll_horizontal():
		var x_pos: float = ScrollPhysics.calculate_drag_position(
			input_handler.drag_temp_data[4],  # Temp left_distance
			input_handler.drag_temp_data[5],  # Temp right_distance
			input_handler.drag_temp_data[0],  # Temp x relative accumulation
			input_handler.drag_temp_data[2],  # X position where dragging started
			dragging_scroll_damper._attract_factor
		)
		velocity.x = (x_pos - pos.x) / get_process_delta_time()
		pos.x = x_pos
		content_node.position.x = _base_offset.x + x_pos


## Updates the [member is_scrolling] state based on current dragging, velocity, and active tweens.
func update_is_scrolling() -> void:
	if(
		(input_handler.content_dragging and not input_handler.is_in_deadzone)
		or input_handler.any_scrollbar_dragging()
		or velocity != Vector2.ZERO
		or scrollbar_animator.has_active_scroll_tween()
	):
		is_scrolling = true
	
	else:
		is_scrolling = false


## Updates scrollbar positions to match current scroll position and shows them when needed.
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
	if hide_scrollbar_over_time and (is_scrolling or input_handler.mouse_on_scrollbar):
		scrollbar_animator.show_scrollbars()
#endregion


#region Public API Functions
## Scrolls to a specific horizontal position with a tween animation. [br]
## Animates content to [param x_pos] over the specified [param duration] in seconds.
func scroll_x_to(x_pos: float, duration := 0.5) -> void:
	if not should_scroll_horizontal(): return
	if input_handler.content_dragging: return
	_scroll_x_to_internal(x_pos, duration)


## Internal method to scroll horizontally, bypassing should_scroll checks. [br]
## Used by [method ensure_control_visible_smooth] to ensure focus scrolling always works.
func _scroll_x_to_internal(x_pos: float, duration := 0.5) -> void:
	if not content_node: return
	if not allow_horizontal_scroll: return
	
	set_process(true)
	velocity.x = 0.0
	var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
	var size_x_diff: float = ScrollLayout.get_child_size_x_diff(content_node, spare_size_x, true)
	x_pos = clampf(x_pos, -size_x_diff, 0.0)
	scrollbar_animator.kill_scroll_x_tween()
	scrollbar_animator.scroll_x_to(x_pos, duration)


## Scrolls to a specific vertical position with a tween animation. [br]
## Animates content to [param y_pos] over the specified [param duration] in seconds.
func scroll_y_to(y_pos: float, duration := 0.5) -> void:
	if not should_scroll_vertical(): return
	if input_handler.content_dragging: return
	_scroll_y_to_internal(y_pos, duration)


## Internal method to scroll vertically, bypassing should_scroll checks. [br]
## Used by [method ensure_control_visible_smooth] to ensure focus scrolling always works.
func _scroll_y_to_internal(y_pos: float, duration := 0.5) -> void:
	if not content_node: return
	if not allow_vertical_scroll: return

	set_process(true)
	velocity.y = 0.0
	var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
	var size_y_diff: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size_y, true)
	y_pos = clampf(y_pos, -size_y_diff, 0.0)
	scrollbar_animator.kill_scroll_y_tween()
	scrollbar_animator.scroll_y_to(y_pos, duration)


## Scrolls up one page with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_page_up(duration := 0.5) -> void:
	var destination: float = pos.y + ScrollLayout.get_spare_size_y(self, content_margins)
	scroll_y_to(destination, duration)


## Scrolls down one page with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_page_down(duration := 0.5) -> void:
	var destination: float = pos.y - ScrollLayout.get_spare_size_y(self, content_margins)
	scroll_y_to(destination, duration)


## Scrolls left one page with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_page_left(duration := 0.5) -> void:
	var destination: float = pos.x + ScrollLayout.get_spare_size_x(self, content_margins)
	scroll_x_to(destination, duration)


## Scrolls right one page with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_page_right(duration := 0.5) -> void:
	var destination: float = pos.x - ScrollLayout.get_spare_size_x(self, content_margins)
	scroll_x_to(destination, duration)


## Adds velocity to the vertical scroll for momentum-based scrolling. [br]
## Positive [param amount] scrolls up, negative scrolls down.
func scroll_vertically(amount: float) -> void:
	velocity.y -= amount
	set_process(true)


## Adds velocity to the horizontal scroll for momentum-based scrolling. [br]
## Positive [param amount] scrolls left, negative scrolls right.
func scroll_horizontally(amount: float) -> void:
	velocity.x -= amount
	set_process(true)


## Scrolls to the top with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_to_top(duration := 0.5) -> void:
	scroll_y_to(0.0, duration)


## Scrolls to the bottom with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_to_bottom(duration := 0.5) -> void:
	var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
	scroll_y_to(spare_size_y - content_node.size.y, duration)


## Scrolls to the leftmost position with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_to_left(duration := 0.5) -> void:
	scroll_x_to(0.0, duration)


## Scrolls to the rightmost position with a tween animation. Duration is specified by [param duration] in seconds.
func scroll_to_right(duration := 0.5) -> void:
	var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
	scroll_x_to(spare_size_x - content_node.size.x, duration)


## Resets the scroll position and velocity to zero instantly.
func reset_scroll() -> void:
	velocity = Vector2.ZERO
	pos = Vector2.ZERO
	scrollbar_animator.kill_scroll_tweens()
	if content_node:
		# Reset position based on current base offset or 0 if margin layout
		# Usually we just want to apply 0 scroll:
		content_node.position = _base_offset
	
	# Sync native scrollbars
	if get_v_scroll_bar(): get_v_scroll_bar().value = 0
	if get_h_scroll_bar(): get_h_scroll_bar().value = 0


## Returns [code]true[/code] when there is enough content height to scroll vertically.
func should_scroll_vertical() -> bool:
	var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
	var child_size_diff: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size_y, false)
	var disable_scroll: bool = (not allow_vertical_scroll) \
		or (auto_allow_scroll and child_size_diff <= 0) \
		or not scroll_damper
	
	if disable_scroll:
		velocity.y = 0.0
		return pos.y != 0
	
	else:
		return true


## Returns [code]true[/code] when there is enough content width to scroll horizontally.
func should_scroll_horizontal() -> bool:
	var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
	var child_size_diff: float = ScrollLayout.get_child_size_x_diff(content_node, spare_size_x, false)
	var disable_scroll: bool = (not allow_horizontal_scroll) \
		or (auto_allow_scroll and child_size_diff <= 0) \
		or not scroll_damper
	
	if disable_scroll:
		velocity.x = 0.0
		return pos.x != 0
	
	else:
		return true


## Overrides built-in method to use smooth scrolling.
func ensure_control_visible(control: Control) -> void:
	ensure_control_visible_smooth(control)


## Smoothly scrolls to ensure the given [param control] node is visible with animation. [br]
## Replaces the built-in [method ScrollContainer.ensure_control_visible] function.
func ensure_control_visible_smooth(control: Control) -> void:
	if not content_node: return
	if not content_node.is_ancestor_of(control): return
	if not scroll_damper: return
	
	# If container size is 0, wait for first valid size then track resizes
	var current_size := size
	if current_size.x <= 0 or current_size.y <= 0:
		_pending_ensure_control = control
		if not resized.is_connected(_on_resized_for_ensure_continuous):
			resized.connect(_on_resized_for_ensure_continuous)
		return
	
	# Execute the scroll
	_execute_ensure_control_visible(control, false)
	
	# Track this control for continuous updates during resize
	_pending_ensure_control = control
	_last_ensure_size = current_size
	if not resized.is_connected(_on_resized_for_ensure_continuous):
		resized.connect(_on_resized_for_ensure_continuous)
	
	# Start a timer to stop tracking after things stabilize
	_start_stability_timer()


## Start or restart the stability timer
func _start_stability_timer() -> void:
	if not _ensure_stability_timer:
		_ensure_stability_timer = Timer.new()
		_ensure_stability_timer.one_shot = true
		_ensure_stability_timer.timeout.connect(_on_stability_timeout)
		add_child(_ensure_stability_timer)
	_ensure_stability_timer.start(0.6)  # Stop tracking after 600ms of no resize


## Called when stability timer expires - stop tracking resizes
func _on_stability_timeout() -> void:
	if resized.is_connected(_on_resized_for_ensure_continuous):
		resized.disconnect(_on_resized_for_ensure_continuous)
	_pending_ensure_control = null
	_last_ensure_size = Vector2.ZERO


## Called on every resize while tracking a control
func _on_resized_for_ensure_continuous() -> void:
	var current_size: Vector2 = size
	if current_size.x <= 0 or current_size.y <= 0: return
	
	if _pending_ensure_control and is_instance_valid(_pending_ensure_control):
		_execute_ensure_control_visible(_pending_ensure_control, true)
		_last_ensure_size = current_size
		_start_stability_timer()


## Actually execute the ensure_control_visible logic. [br]
## If [param instant] is true, set position directly without animation
func _execute_ensure_control_visible(control: Control, instant: bool) -> void:
	var control_rect: Rect2 = control.get_global_rect()
	var content_rect: Rect2 = content_node.get_global_rect()
	
	var control_in_content: Vector2 = control_rect.position - content_rect.position
	var visible_size := Vector2(
		ScrollLayout.get_spare_size_x(self, content_margins),
		ScrollLayout.get_spare_size_y(self, content_margins)
	)
	
	set_process(true)
	
	var target_x: float = pos.x
	var target_y: float = pos.y
	
	# Calculate where control currently appears relative to visible area
	var control_top_in_view: float = control_in_content.y + pos.y
	var control_bottom_in_view: float = control_top_in_view + control_rect.size.y
	var control_left_in_view: float = control_in_content.x + pos.x
	var control_right_in_view: float = control_left_in_view + control_rect.size.x
	
	# Horizontal scrolling
	if control_left_in_view < follow_focus_margin:
		target_x = -(control_in_content.x - follow_focus_margin)
	elif control_right_in_view > visible_size.x - follow_focus_margin:
		target_x = -(control_in_content.x + control_rect.size.x - visible_size.x + follow_focus_margin)
	
	# Vertical scrolling
	if control_top_in_view < follow_focus_margin:
		target_y = -(control_in_content.y - follow_focus_margin)
	elif control_bottom_in_view > visible_size.y - follow_focus_margin:
		target_y = -(control_in_content.y + control_rect.size.y - visible_size.y + follow_focus_margin)
	
	# Clamp targets
	var spare_size_x: float = ScrollLayout.get_spare_size_x(self, content_margins)
	var spare_size_y: float = ScrollLayout.get_spare_size_y(self, content_margins)
	var size_x_diff: float = ScrollLayout.get_child_size_x_diff(content_node, spare_size_x, true)
	var size_y_diff: float = ScrollLayout.get_child_size_y_diff(content_node, spare_size_y, true)
	
	target_x = clampf(target_x, -size_x_diff, 0.0)
	target_y = clampf(target_y, -size_y_diff, 0.0)
	
	# Set position directly, no animation
	if instant:
		scrollbar_animator.kill_scroll_tweens()
		pos.x = target_x
		pos.y = target_y
		content_node.position.x = _base_offset.x + target_x
		content_node.position.y = _base_offset.y + target_y
	
	# Use animated scroll
	else:
		if target_x != pos.x:
			_scroll_x_to_internal(target_x)
		if target_y != pos.y:
			_scroll_y_to_internal(target_y)
#endregion
