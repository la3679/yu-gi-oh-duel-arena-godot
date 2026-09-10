class_name DeckLists
extends RefCounted

## The two real decks, loaded for a duel outside the test suite. Phase 7 unit A.
##
## The same expansion `TestFixtures.real_deck()` performs — each `quantity` entry in JSON order —
## kept separate so nothing under Scripts/ depends on Tests/. `EngineSessionTests` asserts the
## two produce identical Deck lists.

const PATHS := ["res://Data/decks/deck1.json", "res://Data/decks/deck2.json"]


## {"decks": [Array[CardDef], Array[CardDef]], "names": [String, String], "errors": Array}.
## A card name the library does not know is an error, never a silent skip.
static func load_two_real_decks() -> Dictionary:
	var out := {"decks": [], "names": [], "errors": []}
	var lib := CardRegistry.load_library()
	(out["errors"] as Array).append_array(lib["errors"])
	var defs: Dictionary = lib["cards"]
	for path in PATHS:
		var cards: Array = []
		var deck_name := ""
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			(out["errors"] as Array).append("%s did not parse" % path)
		else:
			deck_name = str(parsed.get("deck_name", ""))
			for entry in parsed.get("main_deck", []):
				var card_name := str(entry.get("name", ""))
				if not defs.has(card_name):
					(out["errors"] as Array).append("%s names unknown card '%s'" % [path, card_name])
					continue
				for i in range(int(entry.get("quantity", 0))):
					cards.append(defs[card_name])
		(out["decks"] as Array).append(cards)
		(out["names"] as Array).append(deck_name)
	return out
