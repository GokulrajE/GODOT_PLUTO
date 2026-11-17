extends RefCounted
## Arcade design tokens shared by all menus and game overlays.

# ── Core palette ──────────────────────────────────────────────────────────
const INK     := Color("1a2e44")   # primary text (5.8:1 on CANVAS)
const MUTED   := Color("4d6478")   # secondary / helper text (5.1:1 on CANVAS)
const ACCENT  := Color("087f83")   # teal CTA and highlights
const CANVAS  := Color("f1f8fc")   # page / card background
const BORDER  := Color("b8d3e3")   # subtle panel border
const GOLD    := Color("8f5c05")   # star counts / values (5.3:1 on CANVAS)
const SUCCESS := Color("1a7a4a")   # confirmed / connected / positive states
const ERROR   := Color("b92b2b")   # validation / connection error states
const SURFACE := Color("ffffff")   # white panel fill
const NIGHT   := SURFACE           # backward-compat alias; prefer SURFACE

# ── Typography scale (font sizes, px) ─────────────────────────────────────
const SIZE_XS   := 13   # captions, metadata
const SIZE_SM   := 16   # descriptions, helper text
const SIZE_BASE := 18   # body, secondary labels
const SIZE_MD   := 20   # section labels
const SIZE_LG   := 24   # card titles, CTAs
const SIZE_XL   := 30   # screen headings
const SIZE_2XL  := 38   # hero values (streak, goal)

# ── Spacing scale (pixels) ────────────────────────────────────────────────
const GAP_XS  :=  4
const GAP_SM  :=  8
const GAP_MD  := 12
const GAP_LG  := 18
const GAP_XL  := 24
const GAP_2XL := 32

const DISPLAY = preload("res://Assets/Arcade/Online/Outfit-Semibold.tres")

static func surface(color: Color = SURFACE, radius: int = 18, border: Color = BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.12, 0.25, 0.35, 0.10)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	return style

static func button(color: Color, border: Color = BORDER) -> StyleBoxFlat:
	var style := surface(color, 14, border)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = DISPLAY
	result.default_font_size = SIZE_SM
	result.set_color("font_color", "Label", INK)
	result.set_stylebox("background", "ProgressBar", surface(Color("e8f1f6"), 8))
	result.set_stylebox("fill", "ProgressBar", surface(Color("10a6a0"), 8, Color("10a6a0")))
	for type in ["HSlider", "VSlider"]:
		result.set_stylebox("slider", type, surface(Color("e8f1f6"), 5))
		result.set_stylebox("grabber_area", type, surface(Color("10a6a0"), 5))
		result.set_stylebox("grabber_area_highlight", type, surface(Color("3bbfb4"), 5))
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		result.set_icon(state, "HSlider", load("res://Assets/Arcade/slider-handle.svg"))
	return result

static func chrome(variant: String = "frame-blue") -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var files := {"frame-blue": "daylight-panel", "field-blue": "daylight-field", "button-lime": "daylight-primary", "button-purple": "daylight-secondary"}
	style.texture = load("res://Assets/Arcade/" + str(files.get(variant, variant)) + ".svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 24)
		style.set_content_margin(side, 16 if side in [SIDE_LEFT, SIDE_RIGHT] else 10)
	return style
