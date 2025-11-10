class_name ScrollPhysics
extends RefCounted
## Static utility class for [SmoothScrollContainer] physics calculations.
##
## This will handle overdrag forces, snapping to boundaries, and velocity calculations.


## Drag damping factor applied when content is pulled beyond boundaries
const OVERDRAG_DAMPING: float = 0.00001


## Applies counterforces when content is dragged beyond boundaries.
## Returns the modified velocity after applying bounce/attract forces.
## [param scroll_damper] - The scroll damper to use for calculations
## [param axis_pos] - Current position on the axis
## [param axis_velocity] - Current velocity on the axis
## [param size_diff] - Size difference between container and content
## [param delta] - Time elapsed since last frame
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


## Snaps content to boundary if velocity and distance are both below threshold.
## Returns [velocity, position] array with potentially snapped values.
## [param axis_velocity] - Current velocity on the axis
## [param axis_pos] - Current position on the axis
## [param size_diff] - Size difference between container and content
## [param snap_threshold] - Distance/velocity threshold for snapping
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
		dist_to_start > 0.0
		and abs(dist_to_start) < snap_threshold
		and abs(axis_velocity) < snap_threshold
	):
		axis_pos = 0.0
		axis_velocity = 0.0
	# Snap to end boundary
	elif (
		dist_to_end < 0.0
		and abs(dist_to_end) < snap_threshold
		and abs(axis_velocity) < snap_threshold
	):
		axis_pos = -size_diff
		axis_velocity = 0.0
	
	return [axis_velocity, axis_pos]


## Calculates the destination position when dragging with overdrag damping.
## Returns the damped displacement.
## [param delta] - Distance being dragged
## [param damping_factor] - The damping factor to apply
static func calculate_overdrag_dest(delta: float, damping_factor: float) -> float:
	if delta >= 0.0:
		return delta / (1.0 + delta * damping_factor * OVERDRAG_DAMPING)
	else:
		return delta


## Calculates the position when dragging content with boundary overdrag resistance.
## Returns the final position after applying overdrag calculations.
## [param temp_dist_start] - Distance to start boundary
## [param temp_dist_end] - Distance to end boundary
## [param temp_relative] - Accumulated relative movement during drag
## [param drag_start_pos] - Position where dragging started
## [param damping_factor] - The damping factor for overdrag
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
