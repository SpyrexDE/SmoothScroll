class_name ScrollPhysics
extends RefCounted
## Static utility class for [SmoothScrollContainer] physics calculations.
##
## This will handle overdrag forces, snapping to boundaries, and velocity calculations.


## Drag damping factor applied when content is pulled beyond boundaries
const OVERDRAG_DAMPING: float = 0.00001


## Applies counterforces when content is dragged beyond boundaries using [param scroll_damper]. [br]
## Calculates bounce and attract forces based on [param axis_pos], [param axis_velocity],
## [param size_diff], and [param delta] time. Returns the modified velocity.
static func apply_overdrag(
	scroll_damper: ScrollDamper,
	axis_pos: float,
	axis_velocity: float,
	size_diff: float,
	delta: float
) -> float:
	if not scroll_damper:
		return axis_velocity
	
	# Calculate distances to boundaries
	var dist_to_start: float = axis_pos
	var dist_to_end: float = axis_pos + size_diff
	
	# Calculate target velocities to return to boundaries
	var target_vel_start: float = scroll_damper._calculate_velocity_to_dest(dist_to_start, 0.0)
	var target_vel_end: float = scroll_damper._calculate_velocity_to_dest(dist_to_end, 0.0)
	
	# Apply attract force when out of boundary and velocity isn't sufficient to return
	if axis_pos > 0.0 and axis_velocity > target_vel_start:
		axis_velocity = scroll_damper.attract(dist_to_start, 0.0, axis_velocity, delta)
	elif axis_pos < -size_diff and axis_velocity < target_vel_end:
		axis_velocity = scroll_damper.attract(dist_to_end, 0.0, axis_velocity, delta)
	
	return axis_velocity


## Snaps content to boundary when velocity and distance are both below [param snap_threshold]. [br]
## Evaluates [param axis_velocity], [param axis_pos], and [param size_diff] to determine snapping. [br]
## Returns [code][velocity, position][/code] array with potentially snapped values.
static func apply_snap(
	axis_velocity: float,
	axis_pos: float,
	size_diff: float,
	snap_threshold: float
) -> Array:
	var dist_to_start: float = axis_pos
	var dist_to_end: float = axis_pos + size_diff
	
	# Snap to start boundary
	if (
		abs(dist_to_start) < snap_threshold
		and abs(axis_velocity) < snap_threshold
	):
		axis_pos = 0.0
		axis_velocity = 0.0
	# Snap to end boundary
	elif (
		abs(dist_to_end) < snap_threshold
		and abs(axis_velocity) < snap_threshold
	):
		axis_pos = -size_diff
		axis_velocity = 0.0
	
	return [axis_velocity, axis_pos]


## Calculates the destination position when dragging with overdrag damping. [br]
## Applies [param damping_factor] to the [param delta] distance being dragged.
static func calculate_overdrag_dest(delta: float, damping_factor: float) -> float:
	if delta >= 0.0:
		return delta / (1.0 + delta * damping_factor * OVERDRAG_DAMPING)
	else:
		return delta


## Calculates the position when dragging content with boundary overdrag resistance. [br]
## Uses [param temp_dist_start], [param temp_dist_end], [param temp_relative], [param drag_start_pos],
## and [param damping_factor] to compute the final position after applying overdrag calculations.
static func calculate_drag_position(
	temp_dist_start: float,
	temp_dist_end: float,
	temp_relative: float,
	drag_start_pos: float,
	damping_factor: float
) -> float:
	# Dragging beyond start boundary
	if temp_relative + temp_dist_start > 0.0:
		var delta: float = min(temp_relative, temp_relative + temp_dist_start)
		var dest: float = calculate_overdrag_dest(delta, damping_factor)
		return dest - min(0.0, temp_dist_start) + drag_start_pos
	# Dragging beyond end boundary
	elif temp_relative + temp_dist_end < 0.0:
		var delta: float = max(temp_relative, temp_relative + temp_dist_end)
		var dest: float = -calculate_overdrag_dest(-delta, damping_factor)
		return dest - max(0.0, temp_dist_end) + drag_start_pos
	# Within boundaries
	else:
		return temp_relative + drag_start_pos
