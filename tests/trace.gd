## Prints a turn-by-turn summary of a scripted game, for tuning and debugging.
##   godot --headless --script res://tests/trace.gd -- <seed> <turns> <every> [planet]
extends SceneTree

const NewGame = preload("res://scripts/sim/new_game.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Bot = preload("res://tests/bot.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var turns := int(args[1]) if args.size() > 1 else 100
	var every := int(args[2]) if args.size() > 2 else 5
	var planet := args[3] if args.size() > 3 else "brume"
	var s := NewGame.create(seed_value, "Margin", {"planet": planet})
	for _i in turns:
		if s["ending"] != "":
			break
		Bot.act(s)
		Turn.end_turn(s)
		if int(s["turn"]) % every == 1 or s["ending"] != "":
			var r: Dictionary = s["report"]
			var counts := {}
			for id in s["structures"]:
				var t: String = s["structures"][id]["type"]
				counts[t] = int(counts.get(t, 0)) + 1
			var st: Dictionary = s["stock"]
			print("T%d pop %d mor %d debt %d cr %d | food %d oxy %d wat %d ore %d alloy %d | pw %.1f/%.1f ht %.1f/%.1f wk %d/%d idle %d | %s" % [
				int(s["turn"]) - 1, int(s["adults"] + s["children"] + s["elders"]), int(s["morale"]), int(s["debt"]), int(st["credits"]),
				int(st["food"]), int(st["oxygen"]), int(st["water"]), int(st["ore"]), int(st["alloy"]),
				float(r["power_free"]), float(r["power_gen"]), float(r["heat_free"]), float(r["heat_gen"]),
				int(r["workers_free"]), int(r["workers_total"]), int(r["idle"]), counts])
	print("ending: ", s["ending"])
	quit()
