## Smooth scroll functionality for ScrollContainer
##
## Applies velocity based momentum and "overdrag"
## functionality to a ScrollContainer
extends ScrollContainer

# Drag impact for one scroll input
@export_range(0, 10, 0.01, "or_greater")
var speed := 5.0
# Softness of damping when "overdragging"
@export_range(0, 1)
var damping := 0.1
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
var friction_drag := 0.97

# Current velocity of the `content_node`
var velocity := Vector2(0,0)
# Below this value, velocity is set to `0`
var just_stop_under := 0.01
# Current counterforce for "overdragging" on the top
var over_drag_multiplicator_top := 1
# Current counterforce for "overdragging" on the bottom
var over_drag_multiplicator_bottom := 1
# Control node to move when scrolling
var content_node : Control
# Current position of `content_node`
var pos := Vector2(0, 0)
# When true, `content_node`'s position is only set by dragging the scroll bar
var scrollbar_dragging := false
# Current friction
var friction := 0.9
# When ture, `content_node` follows drag position
var content_dragging = false
# If it bounce last frame
var bounce = true


func _ready() -> void:
	get_v_scroll_bar().scrolling.connect(_on_VScrollBar_scrolling)
	get_v_scroll_bar().scrolling.connect(_on_HScrollBar_scrolling)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	for c in get_children():
		if not c is ScrollBar:
			content_node = c

func _process(delta: float) -> void:
	# If no scroll needed, don't apply forces
	if not should_scroll_vertical():
		return
	
	var d := delta
	# Distance between content_node's bottom and bottom of the scroll box 
	var bottom_distance : float = content_node.position.y + content_node.size.y - self.size.y
	# Distance between content_node and top of the scroll box
	var top_distance : float = content_node.position.y
	# How long it will take to stop scrolling
	var stop_frame = log(just_stop_under/abs(velocity.y+0.001))/log(friction*0.999)
	stop_frame = floor(max(stop_frame, 0.0))
	
	# If overdragged on bottom:
	if bottom_distance < 0:
		over_drag_multiplicator_bottom = 1/abs(bottom_distance)*10
	else:
		over_drag_multiplicator_bottom = 1
	
	# If overdragged on top:
	if top_distance > 0:
		over_drag_multiplicator_top = 1/abs(top_distance)*10
	else:
		over_drag_multiplicator_top = 1
	
	# If velocity is too low, just set it to 0
	if velocity.length() <= just_stop_under:
		velocity = Vector2(0,0)
	
	# Applies counterforces when overdragging
	if not content_dragging:
		var stop_distance = 0.0 # Distance it takes to stop
		var dist = 0.0 # To see whether it is over bounce
		var vel_y = velocity.y # Store velocity.y
	
		if bottom_distance < 0:
			if velocity.y >= 0:
				# Calculate dist
				for i in stop_frame+1:
					stop_distance += abs(vel_y)
					vel_y *= friction
					dist = stop_distance - abs(bottom_distance)
					if dist > 0.0: break
				# Just snap to the boundary if close enough
				if abs(bottom_distance) < 0.4:
					velocity.y = 0.0
					pos.y = self.size.y - content_node.size.y
			# How it bounce
			if velocity.y <= 0 or dist < 0.0 :
				velocity.y = lerp(velocity.y, -bottom_distance/8, damping)
				bounce = true
			elif bounce: velocity.y = (friction-1) * bottom_distance
		
		if top_distance > 0:
			if velocity.y <= 0:
				# Calculate dist
				for i in stop_frame+1:
					stop_distance += abs(vel_y)
					vel_y *= friction
					dist = stop_distance - abs(top_distance)
					if dist > 0.0: break
				# Just snap to the boundary if close enough
				if abs(top_distance) < 0.4:
					velocity.y = 0.0
					pos.y = 0.0
			# How it bounce
			if velocity.y >= 0 or dist < 0.0 :
				velocity.y = lerp(velocity.y, -top_distance/8, damping)
				bounce = true
			elif bounce: velocity.y = (friction-1) * top_distance
	
	# If using scroll bar dragging, set the content_node's
	# position by using the scrollbar position
	if scrollbar_dragging:
		pos = content_node.position
		return
	
	# Move content node by applying velocity
	pos += velocity
	content_node.position = pos
	
	# Update vertical scroll bar
	set_v_scroll(-pos.y)
	
	# Simulate friction
	velocity *= friction


func _gui_input(event: InputEvent) -> void:
	if not any_scroll_bar_dragged():
		scrollbar_dragging = false
	
	if event is InputEventMouseButton:
		
		var scrolled = true
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					velocity.y -= speed
					bounce = false
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					velocity.y += speed
					bounce = false
			_:                  scrolled = false
			
		if scrolled: friction = friction_scroll
	
	if event is InputEventScreenDrag:
		if content_dragging:
			velocity.y = event.relative.y
	
	if event is InputEventScreenTouch:
		if event.pressed:
			content_dragging = true
			friction = 0.0
		else:
			content_dragging = false
			friction = friction_drag
			bounce = false
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
	
	var focus_size = control.size.y
	var focus_top = control.global_position.y - self.global_position.y
	
	if focus_top < 0.0:
		scroll_to(content_node.position.y - focus_top)
	
	if focus_top + focus_size > self.size.y:
		scroll_to(content_node.position.y - focus_top - focus_size + self.size.y)

func _on_VScrollBar_scrolling() -> void:
	scrollbar_dragging = true

func _on_HScrollBar_scrolling() -> void:
	scrollbar_dragging = true

# Scrolls to specific position
func scroll_to(y_pos: float) -> void:
	velocity.y = 0.0
	var tween = create_tween()
	tween.tween_property(self, "pos:y", y_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

# Scrolls up a page
func scroll_page_up() -> void:
	velocity.y += self.size.y / 10


# Scrolls down a page
func scroll_page_down() -> void:
	velocity.y -= self.size.y / 10


# Adds velocity to the vertical scroll
func scroll_vertically(amount: float) -> void:
	velocity.y -= amount

# Scrolls to top
func scroll_to_top() -> void:
	# Reset velocity
	velocity.y = 0
	# Move content node to top
	pos.y = 0
	content_node.position = pos
	# Update vertical scroll bar
	set_v_scroll(-pos.y)


# Scrolls to bottom
func scroll_to_bottom() -> void:
	# Reset velocity
	velocity.y = 0
	# Move content node to bottom
	pos.y = -content_node.size.y + self.size.y
	content_node.position = pos
	# Update vertical scroll bar
	set_v_scroll(-pos.y)

func any_scroll_bar_dragged() -> bool:
	if get_v_scroll_bar():
		return get_v_scroll_bar().has_focus()
	if get_h_scroll_bar():
		return get_h_scroll_bar().has_focus()
	return false

func should_scroll_vertical() -> bool:
	if content_node.size.y - self.size.y < 1:
		return false
	return allow_vertical_scroll

func should_scroll_horizontal() -> bool:
	if content_node.size.x - self.size.x < 1:
		return false
	return allow_horizontal_scroll
