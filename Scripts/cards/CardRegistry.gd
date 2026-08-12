class_name CardRegistry
extends RefCounted

## Loads the per-card effect registry and attaches it to the canonical CardDefs.
## Master prompt 43 / 86.
##
## One file per card in `Scripts/cards/registry/`, each declaring:
##
##   const CARD_NAME := "Shining Angel"
##   func effects() -> Array:            # one EffectDef.new(...) per official clause
##
## The directory is SCANNED rather than listed in a constant, on purpose:
## `Tools/build_matrix.py` computes the implementation matrix by reading the same files,
## so a scan makes it impossible for the matrix and the running game to disagree about
## which cards are implemented.
##
## `effects()` is an instance method rather than a static one so the loader can call it
## through `script.new()`, which behaves identically on every Godot build.
##
## Nothing here guesses. A registry file that does not declare `CARD_NAME`, or whose
## `CARD_NAME` is not a real card, is a loud error — master prompt 67 forbids silent
## fallbacks.

const REGISTRY_DIR := "res://Scripts/cards/registry"

## Errors found during the last load. Non-empty means the library is not trustworthy.
var errors: Array = []
## card name -> Array[EffectDef]
var by_card_name: Dictionary = {}


## Read every registry file. Returns the number of cards registered.
func load_registry() -> int:
	errors.clear()
	by_card_name.clear()

	var dir := DirAccess.open(REGISTRY_DIR)
	if dir == null:
		# An empty registry is a legitimate state before Phase 5 starts; a MISSING
		# directory is not something to paper over.
		errors.append("registry directory %s could not be opened" % REGISTRY_DIR)
		return 0

	for file_name in dir.get_files():
		# Godot exports .gd as .gdc/.remap; accept both so a build behaves like the editor.
		if not (file_name.ends_with(".gd") or file_name.ends_with(".gd.remap")):
			continue
		var path := "%s/%s" % [REGISTRY_DIR, file_name.trim_suffix(".remap")]
		_load_one(path)

	return by_card_name.size()


func _load_one(path: String) -> void:
	var script = load(path)
	if script == null:
		errors.append("%s could not be loaded" % path)
		return

	var constants: Dictionary = script.get_script_constant_map()
	if not constants.has("CARD_NAME"):
		errors.append("%s declares no CARD_NAME" % path)
		return
	var card_name := str(constants["CARD_NAME"])
	if card_name == "":
		errors.append("%s has an empty CARD_NAME" % path)
		return
	if by_card_name.has(card_name):
		errors.append("'%s' is registered more than once (%s)" % [card_name, path])
		return

	var instance = script.new()
	if not instance.has_method("effects"):
		errors.append("%s ('%s') has no effects()" % [path, card_name])
		return

	var effects = instance.effects()
	if not (effects is Array) or (effects as Array).is_empty():
		errors.append("'%s' registered no effect clauses" % card_name)
		return

	for entry in effects:
		if not (entry is EffectDef):
			errors.append("'%s' returned something that is not an EffectDef" % card_name)
			return
		var effect: EffectDef = entry
		effect.card_name = card_name
		if effect.effect_id == "":
			errors.append("'%s' has an effect with no effect_id" % card_name)
			return
		# Master prompt 67: an effect that starts a Chain must be able to resolve.
		if effect.starts_chain and not effect.resolve.is_valid():
			errors.append("'%s' effect '%s' starts a Chain but has no resolve()"
				% [card_name, effect.effect_id])
			return
		if effect.is_continuous() and not effect.apply_continuous.is_valid():
			errors.append("'%s' effect '%s' is continuous but has no apply_continuous()"
				% [card_name, effect.effect_id])
			return

	by_card_name[card_name] = effects


## Attach the registered effects to the CardDefs in `defs` (name -> CardDef).
## Returns the number of cards that received effects. A registered card name that is not
## in the canonical card database is an error, not a shrug.
func attach_to(defs: Dictionary) -> int:
	var attached := 0
	for card_name in by_card_name.keys():
		if not defs.has(card_name):
			errors.append("'%s' is registered but is not in the card database" % card_name)
			continue
		var def: CardDef = defs[card_name]
		def.effects = by_card_name[card_name]
		attached += 1
	return attached


## Cards in `defs` that need effects but have none yet. This is the honest
## "not implemented" list; it is reported, never hidden. Vanilla Normal Monsters are
## correctly excluded — an empty effect list IS their implementation.
static func unimplemented(defs: Dictionary) -> Array:
	var out: Array = []
	for card_name in defs.keys():
		var def: CardDef = defs[card_name]
		if def.is_vanilla():
			continue
		if def.effects.is_empty():
			out.append(card_name)
	out.sort()
	return out


# ---------------------------------------------------------------------------
# The canonical card database
# ---------------------------------------------------------------------------

const CARDS_JSON := "res://Data/cards/cards.json"


## Load Data/cards/cards.json into name -> CardDef, with the registry attached.
## Returns {"cards": Dictionary, "errors": Array}.
static func load_library() -> Dictionary:
	var out := {"cards": {}, "errors": []}

	var file := FileAccess.open(CARDS_JSON, FileAccess.READ)
	if file == null:
		out["errors"].append("could not open %s" % CARDS_JSON)
		return out
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("cards"):
		out["errors"].append("%s is not the expected card database" % CARDS_JSON)
		return out

	var defs := {}
	for entry in parsed["cards"]:
		var def := CardDef.from_dict(entry)
		if def.name == "":
			out["errors"].append("a card in the database has no name")
			continue
		defs[def.name] = def

	var registry := CardRegistry.new()
	registry.load_registry()
	registry.attach_to(defs)

	out["cards"] = defs
	out["errors"] = registry.errors
	return out
