## Developer tool (not exported): plays the scripted bot many times, with and
## without the newer content, and prints how quickly each pays off the debt.
##   godot --headless --script res://tools/balance.gd [-- <planet> <difficulty> <games>]
## With no arguments it plays 10 games on each planet at Normal.
extends SceneTree

const NewGame = preload("res://scripts/sim/new_game.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Bot = preload("res://tests/bot.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var planets: Array = [args[0]] if args.size() > 0 else ["brume", "cinder", "hollow"]
	var difficulty: String = args[1] if args.size() > 1 else "normal"
	var games: int = int(args[2]) if args.size() > 2 else 10
	for planet in planets:
		for mode in [false, true]:
			Bot.advanced = mode
			var wins := 0
			var turns := 0
			var pop := 0.0
			var used := {}
			for seed_value in range(1, games + 1):
				var s := NewGame.create(seed_value, "Margin", {"planet": planet, "difficulty": difficulty})
				for _i in 300:
					if s["ending"] != "":
						break
					Bot.act(s)
					Turn.end_turn(s)
				if s["ending"] == "free":
					wins += 1
					turns += int(s["turn"])
				pop += Turn.population(s)
				for id in s["structures"]:
					var t: String = s["structures"][id]["type"]
					used[t] = int(used.get(t, 0)) + 1
				used["drones"] = int(used.get("drones", 0)) + Fleet.drones_total(s)
				used["satellites"] = int(used.get("satellites", 0)) + Fleet.sats(s, "relay")
			var extras := PackedStringArray()
			for t in ["fab", "dronebay", "drones", "academy", "mast", "rescue", "fusion", "lounge", "satellites", "reclaimer"]:
				if used.has(t):
					extras.append("%s %d" % [t, int(used[t])])
			print("%-7s %-6s %-9s wins %2d/%d, avg %5.1f turns to buy out, avg end pop %5.1f   [%s]" % [planet, difficulty, "advanced" if mode else "basic", wins, games, float(turns) / maxf(1.0, wins), pop / float(games), ", ".join(extras)])
	quit()
