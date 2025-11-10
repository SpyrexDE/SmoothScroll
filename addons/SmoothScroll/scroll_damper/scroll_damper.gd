@icon("icon.svg")
class_name ScrollDamper
extends Resource
## Base class for scroll damping algorithms.
##
## This defines how scrolling slows down over time. Different dampers use different
## mathematical curves to create various scrolling feels
## Subclasses will implement the actual math for each style.


#region Variables
## Rebound strength when content is pulled beyond boundaries.
## Higher values cause faster attraction back to bounds.
@export_range(0.0, 1.0, 0.001, "or_greater", "hide_slider")
var rebound_strength: float = 7.0: set = _set_rebound_strength

## Internal factor used for attraction force calculations.
var _attract_factor: float = 400.0: set = _set_attract_factor
#endregion


## Abstract method. Calculates velocity at a given time.
## [param time] - Time value for velocity calculation
## Returns the velocity at the specified time
func _calculate_velocity_by_time(time: float) -> float:
	return 0.0


## Abstract method. Calculates time needed to reach a given velocity.
## [param velocity] - Target velocity
## Returns the time needed to reach the velocity
func _calculate_time_by_velocity(velocity: float) -> float:
	return 0.0


## Abstract method. Calculates offset traveled at a given time.
## [param time] - Time value for offset calculation
## Returns the offset at the specified time
func _calculate_offset_by_time(time: float) -> float:
	return 0.0


## Abstract method. Calculates time needed to travel a given offset.
## [param offset] - Target offset distance
## Returns the time needed to reach the offset
func _calculate_time_by_offset(offset: float) -> float:
	return 0.0


## Calculates the velocity needed to reach a destination.
## [param from] - Starting position
## [param to] - Target position
## Returns the required velocity to reach the target
func _calculate_velocity_to_dest(from: float, to: float) -> float:
	var dist: float = to - from
	var time: float = _calculate_time_by_offset(abs(dist))
	var vel: float = _calculate_velocity_by_time(time) * sign(dist)
	return vel


## Calculates the next velocity after a time step.
## [param present_time] - Current time in the damping curve
## [param delta_time] - Time step to advance
## Returns the velocity at the next time step
func _calculate_next_velocity(present_time: float, delta_time: float) -> float:
	return _calculate_velocity_by_time(present_time - delta_time)


## Calculates the position change over a time step.
## [param present_time] - Current time in the damping curve
## [param delta_time] - Time step to advance
## Returns the offset traveled during the time step
func _calculate_next_offset(present_time: float, delta_time: float) -> float:
	return _calculate_offset_by_time(present_time) \
		 - _calculate_offset_by_time(present_time - delta_time)


## Applies damping to velocity and calculates position change.
## [param velocity] - Current velocity
## [param delta_time] - Time elapsed since last frame
## Returns array [next_velocity, position_change]
func slide(velocity: float, delta_time: float) -> Array:
	var present_time: float = _calculate_time_by_velocity(velocity)
	return [
		_calculate_next_velocity(present_time, delta_time) * sign(velocity),
		_calculate_next_offset(present_time, delta_time) * sign(velocity)
	]


## Applies attraction force toward a destination.
## Used for pulling content back to bounds when overdragging.
## [param from] - Current position
## [param to] - Target position
## [param velocity] - Current velocity
## [param delta_time] - Time elapsed since last frame
## Returns the modified velocity after applying attraction
func attract(from: float, to: float, velocity: float, delta_time: float) -> float:
	var dist: float = to - from
	var target_vel: float = _calculate_velocity_to_dest(from, to)
	velocity += _attract_factor * dist * delta_time \
		 + _calculate_velocity_by_time(delta_time) * sign(dist)
	if (
		(dist > 0 and velocity >= target_vel) \
		or (dist < 0 and velocity <= target_vel) \
	):
		velocity = target_vel
	return velocity


#region Setters
func _set_rebound_strength(value: float) -> void:
	rebound_strength = max(value, 0.0)
	_attract_factor = rebound_strength * rebound_strength * rebound_strength


func _set_attract_factor(value: float) -> void:
	_attract_factor = max(value, 0.0)
#endregion
