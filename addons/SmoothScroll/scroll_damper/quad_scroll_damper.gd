class_name QuadScrollDamper
extends ScrollDamper
## Quadratic scroll damping.
##
## Applies quadratic deceleration curve (x²). Medium easing curve,
## between linear and exponential curves.


#region Variables
const QUADRATIC_POWER: float = 2.0
const CUBIC_POWER: float = 3.0
const CUBIC_COEFFICIENT: float = 1.0 / 3.0
const FRICTION_BASE: float = 10.0
const FRICTION_OFFSET: float = 1.0
const MIN_FRICTION: float = 0.001
const MIN_FACTOR: float = 0.000000000001

## Friction coefficient for deceleration.
## Higher values create more aggressive deceleration.
@export_range(0.001, 10000.0, 0.001, "or_greater", "hide_slider")
var friction: float = 4.0: set = _set_friction

## Internal quadratic factor derived from friction.
var _factor: float = 10000.0: set = _set_factor
#endregion


## Calculates velocity at the given [param time] using quadratic curve.
func _calculate_velocity_by_time(time: float) -> float:
	if time <= 0.0:
		return 0.0
	return pow(time, QUADRATIC_POWER) * _factor


## Calculates time needed to reach the given [param velocity].
func _calculate_time_by_velocity(velocity: float) -> float:
	return sqrt(abs(velocity) / _factor)


## Calculates offset traveled at the given [param time].
func _calculate_offset_by_time(time: float) -> float:
	time = max(time, 0.0)
	return CUBIC_COEFFICIENT * _factor * pow(time, CUBIC_POWER)


## Calculates time needed to travel the given [param offset] distance.
func _calculate_time_by_offset(offset: float) -> float:
	return pow(abs(offset) * CUBIC_POWER / _factor, 1.0 / CUBIC_POWER)


#region Setters
func _set_friction(value: float) -> void:
	friction = max(value, MIN_FRICTION)
	_factor = pow(FRICTION_BASE, friction) - FRICTION_OFFSET


func _set_factor(value: float) -> void:
	_factor = max(value, MIN_FACTOR)
#endregion
