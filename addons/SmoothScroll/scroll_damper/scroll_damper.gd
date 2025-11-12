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


## Abstract method. Calculates velocity at the given [param time] value.
func _calculate_velocity_by_time(time: float) -> float:
	return 0.0


## Abstract method. Calculates time needed to reach the given [param velocity].
func _calculate_time_by_velocity(velocity: float) -> float:
	return 0.0


## Abstract method. Calculates offset traveled at the given [param time] value.
func _calculate_offset_by_time(time: float) -> float:
	return 0.0


## Abstract method. Calculates time needed to travel the given [param offset] distance.
func _calculate_time_by_offset(offset: float) -> float:
	return 0.0


## Calculates the velocity needed to reach a destination. [br]
## Computes required velocity to move from [param from] position to [param to] position.
func _calculate_velocity_to_dest(from: float, to: float) -> float:
	var dist: float = to - from
	var time: float = _calculate_time_by_offset(abs(dist))
	var vel: float = _calculate_velocity_by_time(time) * sign(dist)
	return vel


## Calculates the next velocity after advancing time. [br]
## Returns velocity at [param present_time] minus [param delta_time].
func _calculate_next_velocity(present_time: float, delta_time: float) -> float:
	return _calculate_velocity_by_time(present_time - delta_time)


## Calculates the position change over a time step. [br]
## Returns offset difference between [param present_time] and [param present_time] minus [param delta_time].
func _calculate_next_offset(present_time: float, delta_time: float) -> float:
	return _calculate_offset_by_time(present_time) \
		 - _calculate_offset_by_time(present_time - delta_time)


## Applies damping to [param velocity] over [param delta_time]. [br]
## Returns array: [code][next_velocity, position_change][/code].
func slide(velocity: float, delta_time: float) -> Array:
	var present_time: float = _calculate_time_by_velocity(velocity)
	return [
		_calculate_next_velocity(present_time, delta_time) * sign(velocity),
		_calculate_next_offset(present_time, delta_time) * sign(velocity)
	]


## Applies attraction force toward a destination when overdragging. [br]
## Pulls content from [param from] position toward [param to] position, modifying [param velocity]
## over [param delta_time]. Returns the modified velocity.
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
