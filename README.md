# <img src="./addons/SmoothScroll/class-icon.svg" alt="drawing" width="20" style="padding-top: 20px;"/>   SmoothScroll
A customizable `SmoothScrollContainer` node for Godot.

[Watch video footage on Youtube](https://www.youtube.com/watch?v=B3GjqV2c6yQ)

### How to use
Activate the addon in the project settings' **Addon** tab. Add a new
`SmoothScrollContainer` node, or right-click an existing `ScrollContainer`,
choose **Change Type**, and select `SmoothScrollContainer`.

Put one `Control` child inside the container as the scrollable content. The
container supports vertical and horizontal scrolling and automatically limits
scrolling to axes where the content overflows.

For smoother scrolling: In your project settings set _gui/common/snap_controls_to_pixels_ to _false_

### Features

- Momentum-based mouse-wheel scrolling with configurable scroll dampers.
- Mouse and touch content dragging with configurable drag dampers.
- Optional overdragging and boundary snapping.
- Smooth scrollbar scrolling and optional scrollbar auto-hide/fade.
- Smooth scrolling to positions, pages, boundaries, and focused controls.
- Automatic child mouse-filter setup so content remains draggable.
- Optional vertical or horizontal alpha-gradient clipping at the container
  edges.

### Alpha clipping

Alpha clipping is disabled by default. Enable the `clipping_gradient` property
on `SmoothScrollContainer` and choose `Vertical` or `Horizontal`. Adjust
`clipping_gradient_size` to control the fade width in pixels.

The clipping is dynamic: the gradient at the starting edge is disabled while
the content is at the start, and the gradient at the ending edge is disabled
when the content reaches the end. This prevents content from appearing faded
while the scrollable area is at rest on either boundary.

```gdscript
@onready var scroll_container: SmoothScrollContainer = $SmoothScrollContainer

func _ready() -> void:
	scroll_container.clipping_gradient = 1 # Vertical
	scroll_container.clipping_gradient_size = 32.0
```

The alpha mask is implemented by
`addons/SmoothScroll/clipping_gradient.gdshader`. Existing content materials
are restored when clipping is disabled.

`Mouse scroll icon by Greg Fiske from the Noun Project`
