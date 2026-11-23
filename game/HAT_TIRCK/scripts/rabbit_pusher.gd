extends Control
## A rabbit that pushes the hat along. Purely visual: it follows the hat and never changes the
## hat's movement or the scoring.
##   hat moving right -> rabbit stands on its left and PUSHES
##   hat moving left  -> rabbit stands on its right and PULLS
##   hat standing still -> rabbit stands ready (idle); before the game it sits and waits
##   ball caught -> catch reaction, then a short celebration
## Frames: game/HAT_TIRCK/assets/rabbit/*.png (all the same scale; feet on the bottom edge and the
## paws flush with the edge of the picture that faces the hat).

const FRAME_PATH := "res://game/HAT_TIRCK/assets/rabbit/%s.png"
const CLIPS := {
	"wait":  ["prep_4"],
	"idle":  ["prep_1", "prep_2", "prep_3", "prep_2"],
	# only the frames whose paws reach forward (push_4/5 are a running pose with the arms down)
	"push":  ["push_1", "push_2", "push_3", "push_2"],
	"pull":  ["pull_1", "pull_2", "pull_3", "pull_4"],
	"catch": ["catch_1"],
	"cheer": ["cheer_1", "cheer_2", "cheer_3", "cheer_2"],
}
## Clips whose rabbit faces left (the picture's paws are on its left edge).
const FACES_LEFT := ["pull"]

const HEIGHT := 150.0          # drawn height of the rabbit
const FEET_Y := 628.0          # ground line (bottom of the hat)
const OVERLAP := 14.0          # paws reach this far in behind the hat, so they always touch it
const MOVE_THRESHOLD := 35.0   # px/s of hat speed that counts as "moving"

static var _textures := {}

var game: Control              # the Hat-Trick game (reads _hat_x, _state)
var hat_half := 90.0
var _clip := "wait"
var _time := 0.0
var _side := -1                # -1 rabbit stands left of the hat, +1 right of it
var _blend := 0.0              # 0 = on the hat's left, 1 = on its right (eases when it switches sides)
var _prev_hat_x := 583.0
var _vx := 0.0
var _cheer_left := 0.0

static func _load() -> void:
	if not _textures.is_empty():
		return
	for clip in CLIPS:
		for frame in CLIPS[clip]:
			if not _textures.has(frame):
				var path: String = FRAME_PATH % frame
				_textures[frame] = load(path) if ResourceLoader.exists(path) else null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load()
	var aspect := 1.0
	var sample := _textures.get("prep_1") as Texture2D
	if sample:
		aspect = sample.get_width() / float(sample.get_height())
	size = Vector2(HEIGHT * aspect, HEIGHT)
	position.y = FEET_Y - HEIGHT
	if game:
		_prev_hat_x = float(game.get("_hat_x"))

## Call when the ball is caught.
func cheer() -> void:
	_cheer_left = 1.1

func _paused() -> bool:
	return game != null and game.get("_state") == game.State.PAUSED

## Rabbit position for a given hat position and side blend. The edge of the picture that faces the
## hat (where the paws are) is pinned to the hat's edge, so it stays in contact however fast the hat
## moves; only the switch from one side to the other is eased.
func _rabbit_x(hat_x: float, blend: float) -> float:
	var left_x := hat_x - hat_half + OVERLAP - size.x
	var right_x := hat_x + hat_half - OVERLAP
	return lerpf(left_x, right_x, blend)

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game) or _paused():
		return
	var hat_x := float(game.get("_hat_x"))
	var raw_vx := (hat_x - _prev_hat_x) / maxf(delta, 0.0001)
	_prev_hat_x = hat_x
	_vx = lerpf(_vx, raw_vx, 1.0 - exp(-10.0 * delta))
	_cheer_left = maxf(_cheer_left - delta, 0.0)

	var waiting: bool = game.get("_state") == game.State.WAITING
	var clip := "idle"
	if waiting:
		clip = "wait"
	elif _cheer_left > 0.0:
		clip = "catch" if _cheer_left > 0.95 else "cheer"
	elif _vx > MOVE_THRESHOLD:
		clip = "push"
	elif _vx < -MOVE_THRESHOLD:
		clip = "pull"
	if clip != _clip:
		_clip = clip
		_time = 0.0
	if clip == "push":
		_side = -1
	elif clip == "pull":
		_side = 1

	var fps := 3.0
	match clip:
		"push", "pull": fps = clampf(absf(_vx) / 45.0, 5.0, 14.0)
		"cheer": fps = 8.0
	if not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
		_time += delta * fps

	# ease between the two sides (the rabbit slips behind the hat when switching), but never lag
	_blend = move_toward(_blend, 1.0 if _side > 0 else 0.0, delta * 7.0)
	position.x = clampf(_rabbit_x(hat_x, _blend), -size.x * 0.4, 1166.0 - size.x * 0.6)
	queue_redraw()

func _draw() -> void:
	var frames: Array = CLIPS[_clip]
	var tex := _textures.get(frames[int(_time) % frames.size()]) as Texture2D
	if tex == null:
		return
	# Right-facing pictures are mirrored when the rabbit stands on the hat's right-hand side.
	var faces_left := _clip in FACES_LEFT
	var mirrored := (_side > 0) != faces_left
	if mirrored:
		draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	draw_set_transform(Vector2.ZERO)
