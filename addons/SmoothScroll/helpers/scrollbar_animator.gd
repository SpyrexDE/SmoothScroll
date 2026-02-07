class_name ScrollbarAnimator
extends RefCounted
## Handles scrollbar visibility animations with fade in/out effects.
##
## Manages tween animations for showing and hiding scrollbars,
## including timer management for auto-hide functionality.


#region Variables
## ScrollContainer reference
var _container: ScrollContainer = null
## Timer for auto-hiding scrollbars
var _hide_timer: Timer = null
## Tween for fade-in animation
var _show_tween: Tween = null
## Tween for fade-out animation
var _hide_tween: Tween = null
## Tween for horizontal scroll animation
var _scroll_x_tween: Tween = null
## Tween for vertical scroll animation
var _scroll_y_tween: Tween = null
## Duration before scrollbar starts to fade out
var hide_time: float = 5.0
## Duration of fade-in animation
var fade_in_time: float = 0.2
## Duration of fade-out animation
var fade_out_time: float = 0.5
#endregion


## Initializes the animator with a reference to the [param container].
func _init(container: ScrollContainer) -> void:
	_container = container
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	container.add_child(_hide_timer)


## Starts the auto-hide timer.
func start_hide_timer() -> void:
	if _hide_timer and _hide_timer.is_inside_tree():
		_hide_timer.start(hide_time)


## Stops the auto-hide timer.
func stop_hide_timer() -> void:
	if _hide_timer:
		_hide_timer.stop()


## Checks whether scrollbars should hide based on drag states. [br]
## Returns [code]true[/code] when neither [param h_scrollbar_dragging] nor [param v_scrollbar_dragging] is active.
func should_hide(h_scrollbar_dragging: bool, v_scrollbar_dragging: bool) -> bool:
	return not h_scrollbar_dragging and not v_scrollbar_dragging


## Fades in scrollbars over the specified [param time] duration. [br]
## When [param time] is negative, uses [member fade_in_time] instead.
func show_scrollbars(time: float = -1.0) -> void:
	if time < 0.0:
		time = fade_in_time
	
	# Restart hide timer
	start_hide_timer()
	
	# Kill conflicting animation
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	
	var v_scroll_bar: ScrollBar = _container.get_v_scroll_bar()
	var h_scroll_bar: ScrollBar = _container.get_h_scroll_bar()
	
	# Only create tween if scrollbars aren't already visible
	if v_scroll_bar.modulate != Color.WHITE or h_scroll_bar.modulate != Color.WHITE:
		if _show_tween and _show_tween.is_running():
			_show_tween.kill()
		
		_show_tween = _container.create_tween()
		_show_tween.set_parallel(true)
		_show_tween.tween_property(v_scroll_bar, "modulate", Color.WHITE, time)
		_show_tween.tween_property(h_scroll_bar, "modulate", Color.WHITE, time)


## Fades out scrollbars over the specified [param time] duration. [br]
## When [param time] is negative, uses [member fade_out_time] instead.
func hide_scrollbars(time: float = -1.0) -> void:
	if time < 0.0:
		time = fade_out_time
	
	# Kill conflicting animation
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	
	var v_scroll_bar: ScrollBar = _container.get_v_scroll_bar()
	var h_scroll_bar: ScrollBar = _container.get_h_scroll_bar()
	
	# Only create tween if scrollbars aren't already hidden
	if v_scroll_bar.modulate != Color.TRANSPARENT or h_scroll_bar.modulate != Color.TRANSPARENT:
		if _hide_tween and _hide_tween.is_running():
			_hide_tween.kill()
		
		_hide_tween = _container.create_tween()
		_hide_tween.set_parallel(true)
		_hide_tween.tween_property(v_scroll_bar, "modulate", Color.TRANSPARENT, time)
		_hide_tween.tween_property(h_scroll_bar, "modulate", Color.TRANSPARENT, time)


## Sets scrollbars to fully visible immediately without animation.
func show_scrollbars_immediate() -> void:
	if _show_tween: _show_tween.kill()
	if _hide_tween:	_hide_tween.kill()
	
	_container.get_v_scroll_bar().modulate = Color.WHITE
	_container.get_h_scroll_bar().modulate = Color.WHITE


## Cleans up tweens and timer.
func cleanup() -> void:
	if _show_tween: _show_tween.kill()
	if _hide_tween: _hide_tween.kill()
	
	if _scroll_x_tween:	_scroll_x_tween.kill()
	if _scroll_y_tween:	_scroll_y_tween.kill()
	if _hide_timer:	_hide_timer.queue_free()


## Animates horizontal scroll to [param target_pos] with the specified [param duration].
func scroll_x_to(target_pos: float, duration: float = 0.5) -> void:
	if _scroll_x_tween and _scroll_x_tween.is_valid():
		_scroll_x_tween.kill()
	
	_scroll_x_tween = _container.create_tween()
	_scroll_x_tween.set_parallel(true)
	var pos_tweener: PropertyTweener = _scroll_x_tween.tween_property(
		_container,
		"pos:x",
		target_pos,
		duration
	)
	pos_tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	
	# Also tween content_node position directly to ensure it moves even when scroll() early-returns
	if _container.content_node:
		var content_tweener: PropertyTweener = _scroll_x_tween.tween_property(
			_container.content_node,
			"position:x",
			_container._base_offset.x + target_pos,
			duration
		)
		content_tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)


## Animates vertical scroll to [param target_pos] with the specified [param duration].
func scroll_y_to(target_pos: float, duration: float = 0.5) -> void:
	if _scroll_y_tween and _scroll_y_tween.is_valid():
		_scroll_y_tween.kill()
	
	_scroll_y_tween = _container.create_tween()
	_scroll_y_tween.set_parallel(true)
	var pos_tweener: PropertyTweener = _scroll_y_tween.tween_property(
		_container,
		"pos:y",
		target_pos,
		duration
	)
	pos_tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	
	# Also tween content_node position directly to ensure it moves even when scroll() early-returns
	if _container.content_node:
		var target_content_pos = _container._base_offset.y + target_pos
		var content_tweener: PropertyTweener = _scroll_y_tween.tween_property(
			_container.content_node,
			"position:y",
			target_content_pos,
			duration
		)
		content_tweener.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)


## Kills horizontal scroll tween if it exists.
func kill_scroll_x_tween() -> void:
	if _scroll_x_tween and _scroll_x_tween.is_valid():
		_scroll_x_tween.kill()


## Kills vertical scroll tween if it exists.
func kill_scroll_y_tween() -> void:
	if _scroll_y_tween and _scroll_y_tween.is_valid():
		_scroll_y_tween.kill()


## Kills both horizontal and vertical scroll tweens.
func kill_scroll_tweens() -> void:
	kill_scroll_x_tween()
	kill_scroll_y_tween()


## Returns [code]true[/code] if any scroll tween is currently active.
func has_active_scroll_tween() -> bool:
	return (_scroll_x_tween and _scroll_x_tween.is_valid() and _scroll_x_tween.is_running()) \
		or (_scroll_y_tween and _scroll_y_tween.is_valid() and _scroll_y_tween.is_running())


## Called when hide timer times out.
func _on_hide_timer_timeout() -> void:
	hide_scrollbars()
