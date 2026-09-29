extends RefCounted
## Atlas regions preserve transparent PNGs; source files remain unmodified.
static var cache: Dictionary = {}
const REGIONS := {
	"hat": Rect2(45, 97, 465, 360),
	"basket": Rect2(537, 106, 470, 333),
	"cloud": Rect2(1027, 99, 480, 348),
	"tuk": Rect2(34, 566, 505, 374),
	"pong": Rect2(548, 567, 438, 383),
	"star": Rect2(1056, 539, 411, 395)
}
static func sprite(key: String) -> Texture2D:
	if not cache.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = load("res://Assets/Arcade/sprites-driver-v2.png" if key == "tuk" else "res://Assets/Arcade/sprites-source.png")
		texture.region = REGIONS[key]
		texture.filter_clip = true
		cache[key] = texture
	return cache[key]

static func background(key: String = "hat") -> Texture2D:
	var files := {"hat": "twilight-garden", "basket": "orchard-v2", "cloud": "garden-v2", "tuk": "canyon-v2", "pong": "arena-v2"}
	return load("res://Assets/Arcade/" + str(files.get(key, "twilight-garden")) + ".png")

static func plant(stage: int) -> Texture2D:
	var key := "plant" + str(stage)
	if not cache.has(key):
		var regions := [Rect2(48, 754, 215, 123), Rect2(328, 669, 208, 207), Rect2(590, 519, 265, 357), Rect2(884, 252, 281, 625), Rect2(1164, 189, 350, 688)]
		var texture := AtlasTexture.new()
		texture.atlas = load("res://Assets/Arcade/plant-stages.png")
		texture.region = regions[stage]
		texture.filter_clip = true
		cache[key] = texture
	return cache[key]
