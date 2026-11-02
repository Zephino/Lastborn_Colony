## Developer tool (not exported): starts a small colony and saves a run of
## frames a tenth of a second apart, to check the map's animations (steam,
## lights, the lift, rovers, the Reclaimer's truck and the lander coming down).
## Run under a display:
##   godot --script res://tools/anim_shot.gd -- <outdir> [frames]
extends SceneTree

const NewGame = preload("res://scripts/sim/new_game.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const GameData = preload("res://scripts/sim/game_data.gd")
const Turn = preload("res://scripts/sim/turn.gd")


func _init() -> void:
	_run.call_deferred()


func _place(st: Dictionary, type: String) -> void:
	var hull: Dictionary = st["structures"]["1"]
	for radius in range(1, 7):
		for y in int(st["height"]):
			for x in int(st["width"]):
				if absi(x - int(hull["x"])) + absi(y - int(hull["y"])) != radius:
					continue
				var rot := Actions.auto_rot(st, type, x, y)
				if Actions.structure_at(st, x, y).is_empty() and rot >= 0 and Actions.terrain_at(st, x, y) in GameData.building(type)["terrain"]:
					NewGame.add_structure(st, type, x, y, true, 0, rot)
					return


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var frames: int = int(args[1]) if args.size() > 1 else 40
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new({"planet": "brume"}, 4, "Margin")
	main.close_modal()
	var st: Dictionary = main.state
	for type in ["main", "reclaimer", "shaft", "main", "fusion", "dronebay", "drill", "vent", "main", "rescue", "mirror"]:
		_place(st, type)
	st["drones"] = {"grader": 1, "prospector": 1, "hauler": 1, "sweeper": 1}
	st["report"]["drone_slots"] = 4
	for id in st["structures"]:
		st["structures"][id]["active"] = true
	main.set_animations(true)
	main.refresh()
	# Make the lander arrive now, so it comes down in the frames.
	main.map_view._land_turn = -1
	var mv: Control = main.map_view
	mv.tile_size = 150.0
	mv.center_on(Vector2i(int(st["structures"]["1"]["x"]), int(st["structures"]["1"]["y"])))
	for i in frames:
		mv.clock = 0.1 * i
		mv._since_draw = 0.0
		mv.queue_redraw()
		await process_frame
		await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/frame_%03d.png" % [out, i])
	quit()
