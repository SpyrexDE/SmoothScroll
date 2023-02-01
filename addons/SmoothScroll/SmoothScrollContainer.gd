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
# If it bounce in X axis last frame
var bounce_x = true
# If it bounce in Y axis last frame
var bounce_y = true
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

func scroll_x():
	# If no scroll needed, don't apply forces
	if not should_scroll_horizontal():
		return
	
	# How long it will take to stop scrolling
	var stop_frame = log(just_stop_under/abs(velocity.x+0.001))/log(friction*0.999)
	stop_frame = floor(max(stop_frame, 0.0))
	
	# If velocity is too low, just set it to 0
	if abs(velocity.x) <= just_stop_under:
		velocity.x = 0.0
	
	# Applies counterforces when overdragging
	if not content_dragging:
		
		if right_distance < 0:
			var a = over_bounce(-velocity.x, -right_distance, stop_frame, bounce_x)
			velocity.x = -a[0]
			bounce_x = a[1]
			if a[2]: pos.x -= right_distance
		
		if left_distance > 0:
			var a = over_bounce(velocity.x, left_distance, stop_frame, bounce_x)
			velocity.x = a[0]
			bounce_x = a[1]
			if a[2]: pos.x -= left_distance
	
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
	
	# How long it will take to stop scrolling
	var stop_frame = log(just_stop_under/abs(velocity.y+0.001))/log(friction*0.999)
	stop_frame = floor(max(stop_frame, 0.0))
	
	# If velocity is too low, just set it to 0
	if abs(velocity.y) <= just_stop_under:
		velocity.y = 0.0
	
	# Applies counterforces when overdragging
	if not content_dragging:
		
		if bottom_distance < 0:
			var a = over_bounce(-velocity.y, -bottom_distance, stop_frame, bounce_y)
			velocity.y = -a[0]
			bounce_y = a[1]
			if a[2]: pos.y -= bottom_distance
		
		if top_distance > 0:
			var a = over_bounce(velocity.y, top_distance, stop_frame, bounce_y)
			velocity.y = a[0]
			bounce_y = a[1]
			if a[2]: pos.y -= top_distance
	
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

func over_bounce(vel:float, distance:float, stop_frame:float, bounce:bool)->Array:
	var stop_distance = 0.0 # Distance it takes to stop
	var over_bounce = 0.0 # To see whether it is over bounce
	var vel_temp = vel # Store velocity temporarily
	var snap = false
	
	if vel <= 0:
		# Calculate dist
		for i in stop_frame+1:
			stop_distance -= vel_temp
			vel_temp *= friction
			over_bounce = stop_distance - distance
			if over_bounce > 0.0: break
		# Just snap to the boundary if close enough
		if distance < 0.4:
			vel = 0.0
			snap = true
	# How it bounce
	if vel >= 0 or over_bounce < 0.0 :
		vel = lerp(vel, -distance/8, damping)
		bounce = true
	elif bounce: vel = (friction-1) * distance
	
	return [vel, bounce, snap]

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
						bounce_x = false
					else:
						velocity.y -= speed
						bounce_y = false
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					if event.shift_pressed:
						velocity.x += speed
						bounce_x = false
					else:
						velocity.y += speed
						bounce_y = false
			_:                  scrolled = false
			
		if scrolled: 
			friction = friction_scroll
			damping = damping_scroll
	
	if event is InputEventScreenDrag:
		if content_dragging:
			
			if top_distance > 0.0: 
				velocity.y = event.relative.y/(1+top_distance*damping_drag)
			elif bottom_distance < 0.0:
				velocity.y = event.relative.y/(1-bottom_distance*damping_drag)
			else: velocity.y = event.relative.y
			
			if left_distance > 0.0: 
				velocity.x = event.relative.x/(1+left_distance*damping_drag)
			elif right_distance < 0.0:
				velocity.x = event.relative.x/(1-right_distance*damping_drag)
			else: velocity.x = event.relative.x
	
	if event is InputEventScreenTouch:
		if event.pressed:
			content_dragging = true
			friction = 0.0
		else:
			content_dragging = false
			friction = friction_drag
			bounce_x = false
			bounce_y = false
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
