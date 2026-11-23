extends Control
## The bunny that holds the target basket up. It shows one of 8 pose frames
## (assets/bunny/bunny_1..8.png: same scale, feet on the bottom edge, hands at the right edge):
##   0 ready / happy      1-4 straining harder as the fruit gets closer
##   5 panic (wrong basket)   6 frantic   7 dizzy (fruit hit the ground)
## `mirrored` flips the bunny so it can stand on the other side of the basket.

const FRAME_DIR := "res://game/FRUIT_BASKET/assets/bunny/bunny_%d.png"
const FRAME_COUNT := 8

static var _frames: Array = []

var frame := 0:
	set(value):
		value = clampi(value, 0, FRAME_COUNT - 1)
		if value != frame:
			frame = value
			queue_redraw()
var mirrored := false

static func _load_frames() -> void:
	if not _frames.is_empty():
		return
	for i in FRAME_COUNT:
		var path := FRAME_DIR % (i + 1)
		_frames.append(load(path) if ResourceLoader.exists(path) else null)

## Width / height of one frame, so the game can size the control without distortion.
static func frame_aspect() -> float:
	_load_frames()
	var tex := _frames[0] as Texture2D
	return tex.get_width() / float(tex.get_height()) if tex else 0.83

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_frames()
	queue_redraw()

func _draw() -> void:
	var tex := _frames[frame] as Texture2D if frame < _frames.size() else null
	if tex == null:
		return
	var ts := tex.get_size()
	var k := minf(size.x / ts.x, size.y / ts.y)
	var drawn := ts * k
	var rect := Rect2(Vector2(size.x - drawn.x, size.y - drawn.y), drawn)   # bottom-right aligned
	if mirrored:
		draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(tex, rect, false)
	draw_set_transform(Vector2.ZERO)
