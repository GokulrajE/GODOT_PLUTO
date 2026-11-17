extends Control
## Reads existing assessment cursor positions; never changes measurements or ROM.
var source: Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	var radius := minf(size.x * .42,size.y * .80)
	var center := Vector2(size.x * .5,size.y * .90)
	draw_arc(center,radius,PI,TAU,96,Color("d1e7e9"),12,true)
	if source == null: return
	var reading = source.get_parent().get_node_or_null("AngleLabel")
	if reading != null and not reading.text.is_valid_float(): return
	var track = source.get_node_or_null("SliderTrack")
	var cursor = source.get_node_or_null("CurrentCursor")
	if track == null or cursor == null or track.size.x <= 0: return
	var fraction := clampf((cursor.position.x - track.position.x) / track.size.x,0,1)
	draw_arc(center,radius,PI,PI + PI * fraction,96,Color("087f83"),12,true)
	var endpoint := center + Vector2.from_angle(PI + PI * fraction) * radius
	draw_circle(endpoint,8,Color("087f83"))
