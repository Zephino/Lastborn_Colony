## Developer tool (not exported): starts a game on each planet and saves a
## screenshot of the surface, to compare the planets' looks. Run under a display:
##   godot --script res://tools/planet_shot.gd -- <outdir>
extends SceneTree

const GameData = preload("res://scripts/sim/game_data.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for p in GameData.planets():
		main._start_new({"planet": p["id"]}, 4, "Margin")
		main.close_modal()
		for _i in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/planet_%s.png" % [out, p["id"]])
	quit()
