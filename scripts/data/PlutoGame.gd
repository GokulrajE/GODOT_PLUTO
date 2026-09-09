class_name PlutoGame
extends RefCounted

var name:                 String = ""
var mech:                 String = ""
var current_targets:      int    = 0
var current_hits:         int    = 0
var current_misses:       int    = 0
var cumulative_targets:   int    = 0
var cumulative_hits:      int    = 0
var cumulative_misses:    int    = 0
var cumulative_stars:     int    = 0
var current_star:         int    = 0
var today_stars:          int    = 0

func _init(game_name: String, mech_name: String,
		cu_targets: int, cu_hits: int, cu_misses: int,
		cu_stars: int, today_star_count: int) -> void:
	name              = game_name.to_upper()
	mech              = mech_name.to_upper()
	cumulative_targets = cu_targets
	cumulative_hits    = cu_hits
	cumulative_misses  = cu_misses
	cumulative_stars   = cu_stars
	today_stars        = today_star_count

func update_targets_hits_misses(targets: int, hits: int, misses: int) -> void:
	current_targets   = targets
	current_hits      = hits
	current_misses    = misses
	cumulative_targets += targets
	cumulative_hits    += hits
	cumulative_misses  += misses

func update_cumulative_stars() -> void:
	cumulative_stars += 1
	current_star      = 1
	today_stars      += 1

func reset_star_count() -> void:
	current_star = 0

func is_achieved_today() -> bool:
	return today_stars > 0
