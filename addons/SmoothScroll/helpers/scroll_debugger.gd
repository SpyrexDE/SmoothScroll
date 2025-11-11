class_name ScrollDebugger
extends RefCounted
## Static utility class for [SmoothScrollContainer] debug visualization.
##
## This class will progvide debug drawing functions for dev use.


## Debug gradient for visual debugging (green = safe, red = overdrag)
static var debug_gradient: Gradient = null


## Sets up the gradient for debug visualization.
static func setup_debug_drawing() -> void:
	if debug_gradient == null:
		debug_gradient = Gradient.new()
		debug_gradient.set_color(0.0, Color.GREEN)
		debug_gradient.set_color(1.0, Color.RED)


## Draws debug visualization for the specified [param container]. [br]
## Shows overdrag distances and velocity indicators using colored lines.
static func draw_debug(container: SmoothScrollContainer) -> void:
	if not container.content_node: return
	
	# Calculate the size difference between container and content_node
	var spare_size: Vector2 = ScrollLayout.get_spare_size(container, container.content_margins)
	var size_diff: Vector2 = ScrollLayout.get_child_size_diff(
		container.content_node,
		spare_size,
		false,
		false
	)
	
	# Calculate distance to left, right, top and bottom
	var boundary_dist: Vector4 = ScrollLayout.get_boundary_dist(
		container.pos,
		size_diff
	)
	var bottom_distance: float = boundary_dist.w
	var top_distance: float = boundary_dist.z
	var right_distance: float = boundary_dist.y
	var left_distance: float = boundary_dist.x
	
	# Overdrag lines
	# Top + Bottom
	container.draw_line(
		Vector2(0.0, 0.0),
		Vector2(0.0, top_distance),
		debug_gradient.sample(clamp(top_distance / container.size.y, 0.0, 1.0)),
		5.0
	)
	container.draw_line(
		Vector2(0.0, container.size.y),
		Vector2(0.0, container.size.y + bottom_distance),
		debug_gradient.sample(clamp(-bottom_distance / container.size.y, 0.0, 1.0)),
		5.0
	)
	
	# Left + Right
	container.draw_line(
		Vector2(0.0, container.size.y),
		Vector2(left_distance, container.size.y),
		debug_gradient.sample(clamp(left_distance / container.size.y, 0.0, 1.0)),
		5.0
	)
	container.draw_line(
		Vector2(container.size.x, container.size.y),
		Vector2(container.size.x + right_distance, container.size.y),
		debug_gradient.sample(clamp(-right_distance / container.size.y, 0.0, 1.0)),
		5.0
	)
	
	# Velocity lines
	var origin := Vector2(5.0, container.size.y / 2)
	container.draw_line(
		origin,
		origin + Vector2(0.0, container.velocity.y * 0.01),
		debug_gradient.sample(clamp(container.velocity.y * 2 / container.size.y, 0.0, 1.0)),
		5.0
	)
	container.draw_line(
		origin,
		origin + Vector2(0.0, container.velocity.x * 0.01),
		debug_gradient.sample(clamp(container.velocity.x * 2 / container.size.x, 0.0, 1.0)),
		5.0
	)
