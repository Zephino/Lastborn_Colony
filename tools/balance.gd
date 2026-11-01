## Developer tool (not exported): plays the scripted bot many times, with and
## without the newer content, and prints how quickly each pays off the debt.
##   godot --headless --script res://tools/balance.gd
extends SceneTree

const NewGame = preload("res://scripts/sim/new_game.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Bot = preload("res://tests/bot.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")


func _init() -> void:
	for planet in ["brume", "cinder", "hollow"]:
		for mode in [false, true]:
			Bot.advanced = mode
			var wins := 0
			var turns := 0
			var pop := 0.0
			var used := {}
			for seed_value in range(1, 11):
				var s := NewGame.create(seed_value, "Margin", {"planet": planet})
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
			print("%-7s %-9s wins %2d/10, avg %5.1f turns to buy out, avg end pop %5.1f   [%s]" % [planet, "advanced" if mode else "basic", wins, float(turns) / maxf(1.0, wins), pop / 10.0, ", ".join(extras)])
	quit()
