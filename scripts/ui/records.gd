## Your best results on each world and difficulty, kept on this device in
## user://records.cfg (not part of any save). Updated when a colony ends.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")

const PATH := "user://records.cfg"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


## Notes a finished game. Returns a line about a new best, or "".
static func note_game(state: Dictionary) -> String:
	var cfg := _load()
	var planet := str(state.get("planet", ""))
	var diff := str(state.get("difficulty", "normal"))
	var rec: Dictionary = cfg.get_value(planet, diff, {"games": 0, "wins": 0, "best_turns": 0, "best_paid": 0.0})
	rec["games"] = int(rec["games"]) + 1
	var turns := int(state["turn"]) - 1
	var paid := float(state.get("debt_total", 0.0)) - float(state["debt"])
	var news := ""
	var name: String = GameData.planet(planet).get("name", planet)
	var diff_name: String = GameData.difficulty(diff).get("name", diff)
	if state["ending"] == "free":
		rec["wins"] = int(rec["wins"]) + 1
		if int(rec["best_turns"]) == 0 or turns < int(rec["best_turns"]):
			rec["best_turns"] = turns
			news = "New record: your fastest buyout on %s (%s), in %d turns!" % [name, diff_name, turns]
	if paid > float(rec["best_paid"]):
		rec["best_paid"] = paid
		if news == "":
			news = "New record: the most debt you've paid off on %s (%s), %d marks." % [name, diff_name, int(paid)]
	cfg.set_value(planet, diff, rec)
	cfg.save(PATH)
	return news


## Your records, as text: this world first, then a line for every world.
static func summary(current_planet: String) -> String:
	var cfg := _load()
	var lines := PackedStringArray()
	lines.append("YOUR RECORDS (on this device)")
	var any := false
	for p in GameData.planets():
		var parts := PackedStringArray()
		for d in GameData.difficulties():
			if not cfg.has_section_key(p["id"], d["id"]):
				continue
			var rec: Dictionary = cfg.get_value(p["id"], d["id"])
			var bit := "%s: %d of %d won" % [d["name"], int(rec["wins"]), int(rec["games"])]
			if int(rec["best_turns"]) > 0:
				bit += ", fastest %d turns" % int(rec["best_turns"])
			else:
				bit += ", best %d marks paid" % int(rec["best_paid"])
			parts.append(bit)
		if parts.is_empty():
			continue
		any = true
		var mark := "  (this world)" if p["id"] == current_planet else ""
		lines.append("%s%s: %s" % [p["name"], mark, "; ".join(parts)])
	if not any:
		lines.append("No colonies finished yet. Your best results on each world will show here.")
	return "\n".join(lines)
