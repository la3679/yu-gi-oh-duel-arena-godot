class_name CardAliases
extends RefCounted

## Phase 7 unit B, step B0 — the identifiers a viewer is shown for cards. ADR-0002 in
## docs/ARCHITECTURE.md ("Card identifiers at the session boundary"). One per `EngineSession`
## core; used on its worker thread only (the test-only reads run while the worker is parked).
##
## THE LEAK IT CLOSES. The engine names every card by its instance `id`, and `setup_duel()` assigns
## ids in each Deck's pre-shuffle LIST order — which is public. So the id shown for a face-down card,
## or for a card in the opponent's hand, named it: measured, 4708 of 4708 such identifiers over the
## six scripted duels (`HiddenIdentityTests`). The engine's own ids stay exactly as they are —
## replay, determinism, triggers and every existing assertion read them — and everything that
## leaves the session is translated here instead.
##
## THE RULE. Each viewer has their own alias book. A card's STINT is one stay in one zone; a new
## one begins at every move (`CARD_MOVED`, `CARD_DRAWN`). A viewer is shown:
##   * for a card they cannot identify that is in a Deck or a hand — where a physical observer
##     loses track of it — a SINGLE-USE alias, fresh at every mention;
##   * for any other card, one alias per stint, issued the first time they are shown it: a
##     face-down card keeps one alias from its Set until it moves, and a card that moves is shown
##     under a new alias.
## Every alias comes from one per-viewer counter, in the order that viewer is shown them, so an
## alias is a function of what the viewer's own channel has carried — never of registration order,
## Deck order, or anything the other player did out of sight.
##
## AN EVENT names a card that moved by the end the viewer could see: the new stint's alias when
## they can identify the card where it went, else the old stint's when they could where it came
## from, else a single-use alias. A face-up card returned to the opponent's hand is therefore named
## by its old field alias, never by the stub it has become. Which end a player could see is the
## engine's own rule (`GameState.identity_visible_to()`), sampled when the event is emitted.
##
## THE WAY BACK. A submission names cards by the aliases its player was shown. An alias that is
## unknown, another player's, or from a stint that has ended translates to 0 — never to an instance
## id — so the engine's own validation refuses it exactly as it refuses any forged id.

## Data keys whose values are card instance ids (an int, or an array of them), at any depth.
const CARD_ID_KEYS := ["card_id", "card_ids", "attacker_id", "defender_id", "target_id",
	"target_ids", "source_id", "by_card_id", "for_card_id", "equipped_to_id", "negated_by",
	"destroyed", "tribute_ids", "substituted_by_card_id", "source_card_id",
	# Cost payloads (`EffectPrimitives.record_cost()` and `Honest`), nested under "payload".
	"cost_cards", "discarded", "sent", "tributed", "honest_boosted_monster"]
## Data keys whose integer values are NOT card ids. An int-valued key in neither list is dropped
## from what the viewer receives — fail-closed — and counted in `unclassified`.
const NOT_CARD_ID_KEYS := ["amount", "applies_from_turn", "atk", "attacker_atk", "battle_step",
	"by", "by_player", "chain_size", "controller", "count", "damage", "damage_substep", "damage_to",
	"def", "defender_atk", "defender_def", "delta", "event_seq", "first_player", "from",
	"from_controller", "from_player", "from_zone", "group_index", "index",
	"kurenai_tributed_original_atk", "last_turn", "level", "life_points", "life_points_paid",
	"link_number", "links", "max_count", "min_count", "origin_zone", "owner", "phase", "player",
	"position", "reason", "remaining", "requested", "result", "return_controller",
	"return_position", "return_zone", "seed", "seq", "spell_speed", "step", "substep",
	"summon_kind", "timing", "to", "to_controller", "to_player", "to_zone", "total", "turn",
	"turn_player", "winner", "zone", "zone_index"]
## Decision kinds whose integer options are not card ids (a Battle Position; a zone number).
const NON_CARD_OPTION_KINDS := ["CHOOSE_POSITION", "CHOOSE_ZONE"]
## The id-bearing fields of an offered action (`EngineSession.offer_view()`).
const OFFER_ID_KEYS := ["card_id", "target_ids", "tribute_ids", "attack_target_id",
	"target_candidates", "tribute_candidates", "tribute_combinations", "attack_target_candidates"]
## The id-bearing fields of a Chain Link (`ChainLink.to_visible_dict()`).
const CHAIN_ID_KEYS := ["card_id", "target_ids", "substituted_by_card_id"]
## The card lists of a player's view (`GameState._visible_player()`); "field_zone" is one card.
const VIEW_CARD_LISTS := ["hand", "graveyard", "banished", "monster_zones", "spell_trap_zones",
	"excavated"]
## Where an observer who cannot identify a card loses track of it.
const UNTRACKABLE := [Enums.Zone.DECK, Enums.Zone.HAND, Enums.Zone.EXTRA_DECK]

var _state: GameState = null
## Per instance id: its current stint number; who could identify it as of the last event naming
## it; and the record of its latest move.
var _stint := {}
var _seen := {}
var _moves := {}
## Per event index: {instance id: [stint before, zone before, knowers before, stint after,
## zone after, knowers after]} — sampled when the event was emitted.
var _refs := {}
## Per viewer: "id:stint" -> the stint's alias; "id:stint" -> the latest alias issued for it
## (single-use ones too); alias -> [id, stint]; the counter.
var _book: Array = [{}, {}]
var _latest: Array = [{}, {}]
var _back: Array = [{}, {}]
var _next: Array = [0, 0]
## Int-valued data keys met in neither list, with how often: dropped, never passed through.
var unclassified := {}


## Start following `state`'s events. Called on the owner thread before the worker starts, so every
## event the worker emits is sampled as it happens.
func attach(state: GameState) -> void:
	_state = state
	for c in state.all_instances():
		_seen[(c as CardInstance).id] = state.identity_visible_to(c)
	state.event_emitted.connect(_on_event)


## Stop following events. The state stays readable, for the test-only accessors.
func detach() -> void:
	if _state != null and _state.event_emitted.is_connected(_on_event):
		_state.event_emitted.disconnect(_on_event)


func _on_event(ev: GameEvent) -> void:
	var index: int = _state.events.size() - 1
	var moved := -1
	var from_zone: int = Enums.Zone.DECK
	if ev.kind == GameEvent.Kind.CARD_MOVED:
		moved = int(ev.data.get("card_id", -1))
		from_zone = int(ev.data.get("from_zone", Enums.Zone.DECK))
	elif ev.kind == GameEvent.Kind.CARD_DRAWN:
		moved = int(ev.data.get("card_id", -1))
	# The events a move emits after its CARD_MOVED (sent to the GY, destroyed, returned…) carry
	# the same payload and describe the SAME move: they are named exactly as it was.
	var follow_up := ev.data.has("from_zone") and ev.data.has("to_zone")
	var refs := {}
	for id in _ids_in(ev.data):
		if refs.has(id):
			continue
		var card = _state.instance(id)
		if card == null:
			continue
		var now: Array = _state.identity_visible_to(card)
		var s := int(_stint.get(id, 0))
		var rec: Array
		if id == moved:
			rec = [s, from_zone, _seen.get(id, []), s + 1, int(card.zone), now]
			_stint[id] = s + 1
			_moves[id] = rec
		elif follow_up and id == int(ev.data.get("card_id", -1)) and _moves.has(id) \
				and int(_moves[id][3]) == s:
			rec = _moves[id]
		else:
			rec = [s, int(card.zone), now, s, int(card.zone), now]
		_seen[id] = now
		refs[id] = rec
	if not refs.is_empty():
		_refs[index] = refs


# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

func _issue(viewer: int, id: int, stint: int, single_use: bool) -> int:
	var key := "%d:%d" % [id, stint]
	var book: Dictionary = _book[viewer]
	if not single_use and book.has(key):
		return int(book[key])
	_next[viewer] = int(_next[viewer]) + 1
	var alias := int(_next[viewer])
	if not single_use:
		book[key] = alias
	(_back[viewer] as Dictionary)[alias] = [id, stint]
	(_latest[viewer] as Dictionary)[key] = alias
	return alias


func _name(viewer: int, id: int, stint: int, zone: int, knowers: Array) -> int:
	return _issue(viewer, id, stint, zone in UNTRACKABLE and not (viewer in knowers))


## The alias `viewer` is shown for card `id` as it is now. Non-positive ids (-1: "none") pass
## through; an id that names no card becomes 0.
func current(viewer: int, id: int) -> int:
	if id <= 0:
		return id
	var card = _state.instance(id)
	if card == null:
		return 0
	return _name(viewer, id, int(_stint.get(id, 0)), int(card.zone),
		_state.identity_visible_to(card))


func _event_name(viewer: int, id: int, rec) -> int:
	if rec == null:
		# An event from before the session attached: named as the card is now.
		return current(viewer, id)
	var sb := int(rec[0])
	var sa := int(rec[3])
	if sb == sa:
		return _name(viewer, id, sa, int(rec[4]), rec[5])
	if viewer in (rec[5] as Array):
		return _issue(viewer, id, sa, false)
	if viewer in (rec[2] as Array):
		return _issue(viewer, id, sb, false)
	return _issue(viewer, id, sa, true)


# ---------------------------------------------------------------------------
# Translating what leaves the session (every input is the session's own plain copy)
# ---------------------------------------------------------------------------

## An event's data as `viewer` receives it. `index` is the event's position in `state.events`.
func event_data(viewer: int, index: int, data: Dictionary) -> Dictionary:
	var refs: Dictionary = _refs.get(index, {})
	return _translate(data, func(id: int) -> int: return _event_name(viewer, id, refs.get(id)))


## A view from `get_visible_state(viewer)`, translated in place.
func view(viewer: int, v: Dictionary) -> Dictionary:
	for p in v.get("players", []):
		var pd: Dictionary = p
		for key in VIEW_CARD_LISTS:
			if pd.has(key):
				pd[key] = (pd[key] as Array).map(func(c): return _view_card(viewer, c))
		if pd.has("field_zone"):
			pd["field_zone"] = _view_card(viewer, pd["field_zone"])
	if v.has("chain"):
		v["chain"] = (v["chain"] as Array).map(func(link): return _fields(viewer, link,
			CHAIN_ID_KEYS))
	return v


func _view_card(viewer: int, c):
	if not (c is Dictionary):
		return c
	var d: Dictionary = c
	var id := int(d.get("id", -1))
	if id > 0:
		var card = _state.instance(id)
		d["id"] = 0 if card == null else _issue(viewer, id, int(_stint.get(id, 0)),
			int(card.zone) in UNTRACKABLE and bool(d.get("hidden", false)))
	if d.has("equipped_to"):
		d["equipped_to"] = current(viewer, int(d["equipped_to"]))
	if d.has("equipped_cards"):
		d["equipped_cards"] = (d["equipped_cards"] as Array).map(
			func(x): return current(viewer, int(x)))
	return d


## An offered action (`EngineSession.offer_view()`), translated in place.
func offer(viewer: int, o: Dictionary) -> Dictionary:
	return _fields(viewer, o, OFFER_ID_KEYS)


## A decision request (`DecisionRequest.to_dict()`), translated in place.
func request(viewer: int, r: Dictionary) -> Dictionary:
	var now := func(id: int) -> int: return current(viewer, id)
	r["source_card_id"] = _map_ids(r.get("source_card_id", -1), now)
	if not (str(r.get("kind", "")) in NON_CARD_OPTION_KINDS):
		r["options"] = (r.get("options", []) as Array).map(
			func(o): return _translate(o, now) if o is Dictionary else _map_ids(o, now))
	if r.get("context") is Dictionary:
		r["context"] = _translate(r["context"], now)
	return r


func _fields(viewer: int, d, keys: Array):
	if not (d is Dictionary):
		return d
	var now := func(id: int) -> int: return current(viewer, id)
	for k in keys:
		if (d as Dictionary).has(k):
			d[k] = _map_ids(d[k], now)
	return d


func _translate(data: Dictionary, namer: Callable) -> Dictionary:
	var out := {}
	for k in data.keys():
		out[k] = _translate_value(str(k), data[k], namer)
	return out


func _translate_value(key: String, v, namer: Callable):
	if key in CARD_ID_KEYS:
		return _map_ids(v, namer)
	if v is Dictionary:
		return _translate(v, namer)
	if v is Array:
		if key in NOT_CARD_ID_KEYS:
			return v
		return (v as Array).map(func(x): return _translate_value(key, x, namer))
	if typeof(v) == TYPE_INT and not (key in NOT_CARD_ID_KEYS):
		unclassified[key] = int(unclassified.get(key, 0)) + 1
		return null
	return v


static func _map_ids(v, namer: Callable):
	if typeof(v) == TYPE_INT:
		return namer.call(int(v)) if int(v) > 0 else v
	if v is Array:
		return (v as Array).map(func(x): return _map_ids(x, namer))
	return v


## Every positive int under a card-id key, at any depth.
static func _ids_in(v) -> Array:
	var out: Array = []
	if v is Dictionary:
		for k in v.keys():
			var x = v[k]
			if str(k) in CARD_ID_KEYS:
				_collect_ints(x, out)
			elif x is Dictionary or x is Array:
				out.append_array(_ids_in(x))
	elif v is Array:
		for x in v:
			if x is Dictionary or x is Array:
				out.append_array(_ids_in(x))
	return out


static func _collect_ints(x, out: Array) -> void:
	if typeof(x) == TYPE_INT:
		if int(x) > 0:
			out.append(int(x))
	elif x is Array:
		for y in x:
			_collect_ints(y, out)


# ---------------------------------------------------------------------------
# The way back
# ---------------------------------------------------------------------------

## The instance id `alias` names for `viewer` right now, or 0.
func real_id(viewer: int, alias: int) -> int:
	if viewer < 0 or viewer > 1 or _state == null:
		return 0
	var rec = (_back[viewer] as Dictionary).get(alias)
	if rec == null:
		return 0
	var id := int(rec[0])
	if _state.instance(id) == null or int(_stint.get(id, 0)) != int(rec[1]):
		return 0
	return id


## A submitted ACTION / RESPONSE value with its card choices translated to instance ids. Anything
## that is not a well-formed int is left as it is, for `EngineSession.action_from()` to refuse.
func choices_to_real(viewer: int, value):
	if not (value is Dictionary) or not ((value as Dictionary).get("choices") is Dictionary):
		return value
	var out: Dictionary = (value as Dictionary).duplicate(true)
	var c: Dictionary = out["choices"]
	for k in ["target_ids", "tribute_ids"]:
		if c.get(k) is Array:
			c[k] = (c[k] as Array).map(func(x):
				return real_id(viewer, int(x)) if typeof(x) == TYPE_INT and int(x) > 0 else x)
	if typeof(c.get("attack_target_id")) == TYPE_INT and int(c["attack_target_id"]) > 0:
		c["attack_target_id"] = real_id(viewer, int(c["attack_target_id"]))
	return out


## Test-only (through `EngineSession.debug_alias()`): the latest alias `viewer` was shown for card
## `id` in its current stint, or -1.
func latest_alias(viewer: int, id: int) -> int:
	if viewer < 0 or viewer > 1:
		return -1
	return int((_latest[viewer] as Dictionary).get("%d:%d" % [id, int(_stint.get(id, 0))], -1))
