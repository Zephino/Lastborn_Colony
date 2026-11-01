## Cleaning rules for anything a player types (colony and player names, form
## text), and escaping for text shown in rich-text labels. Every text input in
## the game goes through here before it is stored, shown or sent.
## The online service checks everything again on its side (leaderboard-api/).
extends RefCounted

const MAX_COLONY_NAME := 24
const MAX_PLAYER_NAME := 16
const DEFAULT_COLONY := "Colony"

## Invisible characters that can hide or reorder text: zero-width characters
## and bidirectional overrides/isolates.
const INVISIBLE := [0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2060, 0xFEFF,
	0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069]


static func _is_control(c: int) -> bool:
	return c < 0x20 or (c >= 0x7F and c <= 0x9F)


## Names: keeps A-Z, a-z, 0-9, space, - and _ only; squeezes spaces; trims;
## cuts to max_length. Matches the leaderboard's rules, so a name is never
## changed or refused later.
static func clean_name(raw: String, max_length: int) -> String:
	var out := ""
	var last_space := true
	for i in raw.length():
		var c := raw.unicode_at(i)
		var ok := (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or c == 0x2D or c == 0x5F
		if ok:
			out += char(c)
			last_space = false
		elif c == 0x20 or c == 0x09 or c == 0x0A or c == 0x0D:
			if not last_space:
				out += " "
				last_space = true
	out = out.strip_edges()
	if out.length() > max_length:
		out = out.substr(0, max_length).strip_edges()
	return out


static func clean_colony_name(raw: String) -> String:
	var cleaned := clean_name(raw, MAX_COLONY_NAME)
	return cleaned if cleaned != "" else DEFAULT_COLONY


## Free text (for example a suggestion): removes control and invisible
## characters, keeps line breaks only when `multiline`, trims, and cuts to
## max_length. Ordinary punctuation (quotes, semicolons and so on) is kept as
## plain text: it is never run as code or as a database query anywhere.
static func clean_text(raw: String, max_length: int, multiline: bool = false) -> String:
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c in INVISIBLE:
			continue
		if c == 0x0A and multiline:
			out += "\n"
		elif c == 0x09 or c == 0x0A or c == 0x0D:
			out += " "
		elif not _is_control(c):
			out += char(c)
	out = out.strip_edges()
	if out.length() > max_length:
		out = out.substr(0, max_length).strip_edges()
	return out


## Makes text safe to show in a RichTextLabel with BBCode on: an opening
## bracket can't start a tag, so typed text can't add links, images or colour.
static func escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")
