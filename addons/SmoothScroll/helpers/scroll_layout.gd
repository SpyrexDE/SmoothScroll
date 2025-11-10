class_name ScrollLayout
extends RefCounted
## Static utility class for [SmoothScrollContainer] layout and boundary calculations.
##
## Provides functions to calculate container sizes, content dimensions,
## distances to boundaries, and handle margin/layout management.


## Calculates container size on X axis without vertical scrollbar's width.
## [param container] - The scroll container
## [param content_margins] - StyleBox margins (left, top, right, bottom)
static func get_spare_size_x(container: Control, content_margins: Vector4) -> float:
	var v_scroll_bar: ScrollBar = container.get_v_scroll_bar()
	var size_x: float = container.size.x
	
	if v_scroll_bar.visible:
		size_x -= v_scroll_bar.size.x
	
	size_x -= content_margins.x + content_margins.z
	return max(size_x, 0.0)


## Calculates container size on Y axis without horizontal scrollbar's height.
## [param container] - The scroll container
## [param content_margins] - StyleBox margins (left, top, right, bottom)
static func get_spare_size_y(container: Control, content_margins: Vector4) -> float:
	var h_scroll_bar: ScrollBar = container.get_h_scroll_bar()
	var size_y: float = container.size.y
	
	if h_scroll_bar.visible:
		size_y -= h_scroll_bar.size.y
	
	size_y -= content_margins.y + content_margins.w
	return max(size_y, 0.0)


## Calculates container size without scrollbar sizes.
## [param container] - The scroll container
## [param content_margins] - StyleBox margins (left, top, right, bottom)
static func get_spare_size(container: Control, content_margins: Vector4) -> Vector2:
	return Vector2(
		get_spare_size_x(container, content_margins),
		get_spare_size_y(container, content_margins)
	)


## Calculates the size difference between container and child node on X axis.
## [param child] - The child control to measure
## [param spare_size_x] - Available container width
## [param clamp] - Whether to clamp child size to minimum of container size
static func get_child_size_x_diff(child: Control, spare_size_x: float, clamp: bool) -> float:
	var child_size_x: float = child.size.x * child.scale.x
	
	if clamp:
		child_size_x = max(child_size_x, spare_size_x)
	
	return child_size_x - spare_size_x


## Calculates the size difference between container and child node on Y axis.
## [param child] - The child control to measure
## [param spare_size_y] - Available container height
## [param clamp] - Whether to clamp child size to minimum of container size
static func get_child_size_y_diff(child: Control, spare_size_y: float, clamp: bool) -> float:
	var child_size_y: float = child.size.y * child.scale.y
	
	if clamp:
		child_size_y = max(child_size_y, spare_size_y)
	
	return child_size_y - spare_size_y


## Calculates the size difference between container and child node on both axes.
## [param child] - The child control to measure
## [param spare_size] - Available container size
## [param clamp_x] - Whether to clamp child X size to minimum of container size
## [param clamp_y] - Whether to clamp child Y size to minimum of container size
static func get_child_size_diff(
	child: Control,
	spare_size: Vector2,
	clamp_x: bool,
	clamp_y: bool
) -> Vector2:
	return Vector2(
		get_child_size_x_diff(child, spare_size.x, clamp_x),
		get_child_size_y_diff(child, spare_size.y, clamp_y)
	)


## Calculates distance to left boundary.
## [param child_pos_x] - Current X position of child
static func get_left_dist(child_pos_x: float) -> float:
	return child_pos_x


## Calculates distance to right boundary.
## [param child_pos_x] - Current X position of child
## [param child_size_diff_x] - Size difference between container and child on X axis
static func get_right_dist(child_pos_x: float, child_size_diff_x: float) -> float:
	return child_pos_x + child_size_diff_x


## Calculates distance to top boundary.
## [param child_pos_y] - Current Y position of child
static func get_top_dist(child_pos_y: float) -> float:
	return child_pos_y


## Calculates distance to bottom boundary.
## [param child_pos_y] - Current Y position of child
## [param child_size_diff_y] - Size difference between container and child on Y axis
static func get_bottom_dist(child_pos_y: float, child_size_diff_y: float) -> float:
	return child_pos_y + child_size_diff_y


## Calculates distance to all four boundaries (left, right, top, bottom).
## [param child_pos] - Current position of child
## [param child_size_diff] - Size difference between container and child
static func get_boundary_dist(child_pos: Vector2, child_size_diff: Vector2) -> Vector4:
	return Vector4(
		get_left_dist(child_pos.x),
		get_right_dist(child_pos.x, child_size_diff.x),
		get_top_dist(child_pos.y),
		get_bottom_dist(child_pos.y, child_size_diff.y)
	)


## Checks if content is currently beyond the top boundary.
## [param pos_y] - Y position to check
static func is_outside_top_boundary(pos_y: float) -> bool:
	return pos_y > 0.0


## Checks if content is currently beyond the bottom boundary.
## [param pos_y] - Y position to check
## [param size_diff_y] - Size difference on Y axis
static func is_outside_bottom_boundary(pos_y: float, size_diff_y: float) -> bool:
	return pos_y < -size_diff_y


## Checks if content is currently beyond the left boundary.
## [param pos_x] - X position to check
static func is_outside_left_boundary(pos_x: float) -> bool:
	return pos_x > 0.0


## Checks if content is currently beyond the right boundary.
## [param pos_x] - X position to check
## [param size_diff_x] - Size difference on X axis
static func is_outside_right_boundary(pos_x: float, size_diff_x: float) -> bool:
	return pos_x < -size_diff_x


## Updates and retrieves content margins from container's StyleBox.
## [param container] - The scroll container
## Returns Vector4 with margins (left, top, right, bottom)
static func get_content_margins(container: Control) -> Vector4:
	var style_box: StyleBox = container.get_theme_stylebox("panel")
	if style_box:
		return Vector4(
			style_box.content_margin_left,
			style_box.content_margin_top,
			style_box.content_margin_right,
			style_box.content_margin_bottom
		)
	else:
		return Vector4.ZERO


## Calculates the baseline offset for content positioning.
## This captures the layout offset applied by StyleBox and content positioning.
## [param content_node] - The content control node
## [param current_scroll_pos] - Current scroll position
## Returns the baseline offset as Vector2
static func calculate_base_offset(content_node: Control, current_scroll_pos: Vector2) -> Vector2:
	if not content_node:
		return Vector2.ZERO
	return content_node.position - current_scroll_pos


## Calculates the initial base offset from margins.
## [param content_margins] - StyleBox margins (left, top, right, bottom)
## Returns the baseline offset as Vector2
static func calculate_initial_offset(content_margins: Vector4) -> Vector2:
	return Vector2(content_margins.x, content_margins.y)
