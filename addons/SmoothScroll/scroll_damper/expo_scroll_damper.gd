class_name ExpoScrollDamper
extends ScrollDamper
## Exponential scroll damping.
##
## Starts fast and slows down gradually using exponential curve.


#region Variables
const FRICTION_BASE: float = 10.0
const MIN_FACTOR: float = 1.000000000001
const MIN_FRICTION: float = 0.001
const MIN_VELOCITY: float = 0.001

## Friction coefficient for deceleration.
## Higher values create more aggressive deceleration.
@export_range(0.001, 10000.0, 0.001, "or_greater", "hide_slider")
var friction: float = 4.0: set = _set_friction

## Minimum velocity threshold before stopping.
## Scrolling stops when velocity drops below this value.
@export_range(0.001, 100000.0, 0.001, "or_greater", "hide_slider")
var minimum_velocity: float = 0.4: set = _set_minimum_velocity

## Internal exponential factor derived from friction.
var _factor: float = 10000.0: set = _set_factor
#endregion


## Calculates velocity at the given [param time] using exponential curve.
func _calculate_velocity_by_time(time: float) -> float:
	var minimum_time: float = _calculate_time_by_velocity(minimum_velocity)
	if time <= minimum_time:
		return 0.0
	return pow(_factor, time)


## Calculates time needed to reach the given [param velocity].
func _calculate_time_by_velocity(velocity: float) -> float:
	return log(abs(velocity)) / log(_factor)


## Calculates offset traveled at the given [param time].
func _calculate_offset_by_time(time: float) -> float:
	return pow(_factor, time) / log(_factor)


## Calculates time needed to travel the given [param offset] distance.
func _calculate_time_by_offset(offset: float) -> float:
	return log(offset * log(_factor)) / log(_factor)


## Calculates the velocity needed to reach a destination. [br]
## Overrides base implementation to account for [member minimum_velocity]. [br]
## Computes required velocity to move from [param from] position to [param to] position.
func _calculate_velocity_to_dest(from: float, to: float) -> float:
	var dist: float = to - from
	var min_time: float = _calculate_time_by_velocity(minimum_velocity)
	var min_offset: float = _calculate_offset_by_time(min_time)
	var time: float = _calculate_time_by_offset(abs(dist) + min_offset)
	var vel: float = _calculate_velocity_by_time(time) * sign(dist)
	return vel


#region Setters
func _set_friction(value: float) -> void:
	friction = max(value, MIN_FRICTION)
	_factor = pow(FRICTION_BASE, friction)


func _set_factor(value: float) -> void:
	_factor = max(value, MIN_FACTOR)


func _set_minimum_velocity(value: float) -> void:
	minimum_velocity = max(value, MIN_VELOCITY)
#endregion
