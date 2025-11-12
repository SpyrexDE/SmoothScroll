class_name CubicScrollDamper
extends ScrollDamper
## Cubic scroll damping.
##
## Applies cubic deceleration curve (x³). This have a stronger
## easing with faster deceleration than quadratic or exponential curves.


#region Variables
const CUBIC_POWER: float = 3.0
const QUARTIC_POWER: float = 4.0
const CUBIC_COEFFICIENT: float = 0.25
const FRICTION_BASE: float = 10.0
const FRICTION_OFFSET: float = 1.0
const MIN_FRICTION: float = 0.001
const MIN_FACTOR: float = 0.000000000001

## Friction coefficient for deceleration.
## Higher values create more aggressive deceleration.
@export_range(0.001, 10000.0, 0.001, "or_greater", "hide_slider")
var friction: float = 4.0: set = _set_friction

## Internal cubic factor derived from friction.
var _factor: float = 10000.0: set = _set_factor
#endregion


## Calculates velocity at the given [param time] using cubic curve.
func _calculate_velocity_by_time(time: float) -> float:
	if time <= 0.0:
		return 0.0
	return pow(time, CUBIC_POWER) * _factor


## Calculates time needed to reach the given [param velocity].
func _calculate_time_by_velocity(velocity: float) -> float:
	return pow(abs(velocity) / _factor, 1.0 / CUBIC_POWER)


## Calculates offset traveled at the given [param time].
func _calculate_offset_by_time(time: float) -> float:
	time = max(time, 0.0)
	return CUBIC_COEFFICIENT * _factor * pow(time, QUARTIC_POWER)


## Calculates time needed to travel the given [param offset] distance.
func _calculate_time_by_offset(offset: float) -> float:
	return pow(abs(offset) * QUARTIC_POWER / _factor, 1.0 / QUARTIC_POWER)


func _set_friction(value: float) -> void:
	friction = max(value, MIN_FRICTION)
	_factor = pow(FRICTION_BASE, friction) - FRICTION_OFFSET


func _set_factor(value: float) -> void:
	_factor = max(value, MIN_FACTOR)
