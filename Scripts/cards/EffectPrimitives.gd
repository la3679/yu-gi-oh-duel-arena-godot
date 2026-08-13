class_name EffectPrimitives
extends RefCounted

## Reusable building blocks shared by the card registry. Master prompt 43.
##
## Cards are grouped by MECHANIC, not alphabetically, and the mechanic lives here once.
## A primitive must be a faithful implementation of the rule, never a convenience that
## rounds a card's text off — a card whose text does not match a primitive gets its own
## code rather than the nearest primitive.
##
## Every primitive takes the EffectContext, so nothing reaches for global state.

## Memory key used by a Continuous Trap that Special Summoned a monster and stays linked
## to it (`Birthright`, `Call of the Haunted`). It lives in `GameState.card_memory`, not in
## `CardInstance.flags`, because the link has to be readable at the exact moment the Trap
## LEAVES the field — which is when `flags` has already been cleared. RULES_SPEC.md 15.
const REVIVED_MONSTER_KEY := "revived_monster"

## Memory key used by a Continuous card that stays attached to the monster it TARGETED at
## activation (`Fiendish Chain`). The Chain Link that carried the target is gone by the time
## the continuous clause runs, so the link has to outlive it. RULES_SPEC.md 15.
const AFFLICTED_MONSTER_KEY := "afflicted_monster"

## Cost payload key used by every cost in this file, so a resolution that is measured by
## what its cost consumed reads one well-known name. RULES_SPEC.md 10.
const COST_CARDS_KEY := "cost_cards"

## Memory keys used by a card that ATTACHED an Equip Card with its own effect and has to
## undo that later ("…but return that Equip Spell to the hand during the End Phase" —
## `Fairy Tail - Rella`). Two facts are needed and neither survives in `CardInstance.flags`:
## WHICH card was equipped, so a second Equip Card attached by other means is not dragged
## off, and on WHICH turn, so "during the End Phase" means the End Phase of that turn and
## not of every later one. RULES_SPEC.md 15.
const EQUIPPED_BY_EFFECT_KEY := "equipped_by_effect"
const EQUIPPED_BY_EFFECT_TURN_KEY := "equipped_by_effect_turn"


# ---------------------------------------------------------------------------
# Searching zones
# ---------------------------------------------------------------------------

## Cards in one of this effect's controller's own zones that satisfy `predicate`.
## `predicate` is func(card: CardInstance) -> bool.
static func own_cards_in(ctx: EffectContext, zone: Enums.Zone,
		predicate: Callable) -> Array:
	var out: Array = []
	for entry in _zone_list(ctx.me(), zone):
		var card: CardInstance = entry
		if card == null or card.definition == null:
			continue
		if predicate.is_valid() and not bool(predicate.call(card)):
			continue
		out.append(card)
	return out


## Cards in ONE named player's zone that satisfy `predicate`. `own_cards_in` is the
## common case; this is for clauses that reach across the table ("in either GY").
static func cards_in(ctx: EffectContext, pid: int, zone: Enums.Zone,
		predicate: Callable) -> Array:
	var out: Array = []
	for entry in _zone_list(ctx.state.player(pid), zone):
		var card: CardInstance = entry
		if card == null or card.definition == null:
			continue
		if predicate.is_valid() and not bool(predicate.call(card)):
			continue
		out.append(card)
	return out


## "in either GY" — this effect's controller first, then the opponent, so the option
## order a player is offered is stable and does not depend on iteration order.
static func cards_in_either_graveyard(ctx: EffectContext, predicate: Callable) -> Array:
	var out := cards_in(ctx, ctx.controller_id, Enums.Zone.GRAVEYARD, predicate)
	out.append_array(cards_in(ctx, ctx.opponent_id(), Enums.Zone.GRAVEYARD, predicate))
	return out


static func _zone_list(player: PlayerState, zone: Enums.Zone) -> Array:
	match zone:
		Enums.Zone.DECK:
			return player.deck
		Enums.Zone.HAND:
			return player.hand
		Enums.Zone.GRAVEYARD:
			return player.graveyard
		Enums.Zone.BANISHED:
			return player.banished
		Enums.Zone.MONSTER_ZONE:
			return player.monsters()
		_:
			return []


# ---------------------------------------------------------------------------
# Common predicates
# ---------------------------------------------------------------------------

## "1 LIGHT monster with 1500 or less ATK" and friends. Any argument left at its default
## is not tested, so one builder covers most of the pool's search clauses.
static func monster_filter(attribute: String = "", max_atk: int = -1,
		max_level: int = -1, race: String = "",
		normal_only: bool = false) -> Callable:
	return func(card: CardInstance) -> bool:
		if not card.is_monster():
			return false
		var def := card.definition
		if attribute != "" and def.attribute != attribute:
			return false
		# The printed ATK is what a search clause reads: a monster in the Deck or GY has
		# no continuous modifiers applying to it. Master prompt 35.
		if max_atk >= 0 and def.base_atk > max_atk:
			return false
		if max_level >= 0 and def.level > max_level:
			return false
		if race != "" and def.race != race:
			return false
		if normal_only and not def.is_normal_monster:
			return false
		return true


## "1 monster with 1500 ATK/200 DEF in your GY, except 'Ranryu'" — an exact printed
## ATK/DEF pair, optionally excluding one card name.
static func monster_with_stats(atk: int, def_value: int,
		except_name: String = "") -> Callable:
	return func(card: CardInstance) -> bool:
		if not card.is_monster():
			return false
		var d := card.definition
		# The PRINTED values: a monster in the GY carries no modifiers. Master prompt 35.
		if d.base_atk != atk or d.base_def != def_value:
			return false
		return except_name == "" or d.name != except_name


## "1 Level 1 monster", "1 Level 8 Dragon monster" — an exact Level rather than a cap.
static func monster_of_level(level: int, race: String = "") -> Callable:
	return func(card: CardInstance) -> bool:
		if not card.is_monster():
			return false
		if card.definition.level != level:
			return false
		return race == "" or card.definition.race == race


## "1 <name>" — a clause that names one specific card, e.g. Kaibaman's
## "1 'Blue-Eyes White Dragon'". Matched on the canonical card name, never on text.
static func monster_named(card_name: String) -> Callable:
	return func(card: CardInstance) -> bool:
		return card.is_monster() and card.card_name() == card_name


## "a monster that can be Special Summoned" — the filter a revival clause needs.
##
## The V1 pool contains no Extra Deck monsters, no Ritual Monsters and no Nomi /
## Semi-Nomi monsters (verified against Data/cards/cards.json: every monster is either a
## Normal Monster or an Effect Monster whose text adds a PERMISSIVE Special Summon
## procedure, never a restrictive one). So for this pool the correct answer really is
## "any monster card". This is a named predicate rather than an inline `is_monster()`
## precisely so that a later card which does carry such a restriction has one place to
## extend, instead of the restriction being silently absent. RULES_SPEC.md 5.5.
static func revivable_monster() -> Callable:
	return func(card: CardInstance) -> bool:
		return card.is_monster()


# ---------------------------------------------------------------------------
# Choosing
# ---------------------------------------------------------------------------

## Ask this effect's controller to pick exactly one of `candidates` at RESOLUTION.
## Used by clauses that do NOT target: PSCT reserves "target" for choices locked in at
## activation, so a clause without that word chooses here instead. RULES_SPEC.md 10.
##
## Returns null when there is nothing to choose or no decider is attached.
static func choose_one(ctx: EffectContext, candidates: Array,
		prompt: String) -> CardInstance:
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	var options: Array = []
	for entry in candidates:
		var card: CardInstance = entry
		options.append(card.id)
	var request := DecisionRequest.select(Enums.DecisionKind.SELECT_EXACTLY,
		ctx.controller_id, prompt, options, 1, 1, ctx.source, ctx.effect)
	var answer = ctx.ask(request)
	if not request.validate(answer):
		# A controller that cannot answer must not silently change which card is picked.
		push_error("EffectPrimitives.choose_one: invalid selection for %s"
			% ctx.source.card_name())
		return candidates[0]
	return ctx.state.instance((answer as Array)[0])


## Ask for exactly `n` of `candidates`. Used by costs that consume several cards
## ("Tribute 2 Dragon monsters"). Returns [] when there are not enough candidates, so a
## caller can never pay a cost partially.
##
## When exactly `n` candidates exist there is nothing to decide and no question is asked.
static func choose_n(ctx: EffectContext, candidates: Array, n: int,
		kind: Enums.DecisionKind, prompt: String) -> Array:
	if n <= 0 or candidates.size() < n:
		return []
	if candidates.size() == n:
		return candidates.duplicate()
	var options: Array = []
	for entry in candidates:
		var card: CardInstance = entry
		options.append(card.id)
	var request := DecisionRequest.select(kind, ctx.controller_id, prompt, options, n, n,
		ctx.source, ctx.effect)
	var answer = ctx.ask(request)
	if not request.validate(answer):
		push_error("EffectPrimitives.choose_n: invalid selection for %s"
			% ctx.source.card_name())
		return candidates.slice(0, n)
	var out: Array = []
	for value in (answer as Array):
		out.append(ctx.state.instance(int(value)))
	return out


## "The summoning player chooses face-up Attack Position or face-up Defense Position"
## — the default whenever a Special Summon clause does not name a position.
## RULES_SPEC.md 5.5 [S1 p.24].
##
## Face-down is deliberately NOT offered: a Special Summon is face-up unless the card
## says otherwise (`Apprentice Magician` does, and states it explicitly).
static func choose_face_up_position(ctx: EffectContext,
		prompt: String) -> Enums.Position:
	var options: Array = [Enums.Position.FACE_UP_ATTACK, Enums.Position.FACE_UP_DEFENSE]
	var request := DecisionRequest.select(Enums.DecisionKind.CHOOSE_POSITION,
		ctx.controller_id, prompt, options, 1, 1, ctx.source, ctx.effect)
	var answer = ctx.ask(request)
	if request.validate(answer):
		return (answer as Array)[0]
	if answer != null:
		# An attached controller that answers illegally is a defect, not a default.
		push_error("EffectPrimitives.choose_face_up_position: invalid answer for %s"
			% ctx.source.card_name())
	# No decider attached (a pure-legality evaluation) — Attack Position is the
	# conventional default and nothing observable depends on it in that path.
	return Enums.Position.FACE_UP_ATTACK


# ---------------------------------------------------------------------------
# Special Summoning
# ---------------------------------------------------------------------------

## Special Summon exactly one of `candidates`, chosen at resolution, in `position`.
## Returns the monster that was Summoned, or null if none was.
##
## Called during a Chain resolution, so it goes through DuelEngine.special_summon(),
## which declares and completes in one step (no new Chain starts mid-resolution).
## RULES_SPEC.md 5.5, PROJECT_STATE.md design decision 9.
static func special_summon_one(ctx: EffectContext, candidates: Array,
		position: Enums.Position, prompt: String) -> CardInstance:
	if ctx.engine == null:
		push_error("EffectPrimitives.special_summon_one: no engine attached")
		return null
	# The board can change between activation and resolution, so the room for the monster
	# is re-checked here rather than trusted from the activation check.
	if not ctx.me().has_free_monster_zone():
		ctx.log_note("no free Monster Zone")
		return null
	var chosen := choose_one(ctx, candidates, prompt)
	if chosen == null:
		ctx.log_note("no legal monster to Special Summon")
		return null
	if not ctx.engine.special_summon(chosen, ctx.controller_id, position, ctx.source.id):
		ctx.log_note("the Special Summon did not happen")
		return null
	return chosen


## Special Summon one of `candidates`, chosen at resolution, in the position the
## SUMMONING PLAYER picks. For every clause that says "Special Summon 1 ..." without
## naming a position. The card is chosen first and the position second, so the player
## knows what they are placing before they decide how.
static func special_summon_one_any_position(ctx: EffectContext, candidates: Array,
		prompt: String) -> CardInstance:
	if ctx.engine == null:
		push_error("EffectPrimitives.special_summon_one_any_position: no engine attached")
		return null
	if not ctx.me().has_free_monster_zone():
		ctx.log_note("no free Monster Zone")
		return null
	var chosen := choose_one(ctx, candidates, prompt)
	if chosen == null:
		ctx.log_note("no legal monster to Special Summon")
		return null
	var position := choose_face_up_position(ctx,
		"Special Summon %s in which position?" % chosen.card_name())
	if not ctx.engine.special_summon(chosen, ctx.controller_id, position, ctx.source.id):
		ctx.log_note("the Special Summon did not happen")
		return null
	return chosen


## Special Summon the single card this effect TARGETED, in the position its controller
## picks. Returns null — and does nothing — when the target is no longer where the clause
## needs it.
static func special_summon_target(ctx: EffectContext,
		required_zone: Enums.Zone) -> CardInstance:
	if ctx.engine == null:
		push_error("EffectPrimitives.special_summon_target: no engine attached")
		return null
	var target := surviving_target(ctx, required_zone)
	if target == null:
		ctx.log_note("the target is no longer a legal target")
		return null
	if not ctx.me().has_free_monster_zone():
		ctx.log_note("no free Monster Zone")
		return null
	var position := choose_face_up_position(ctx,
		"Special Summon %s in which position?" % target.card_name())
	if not ctx.engine.special_summon(target, ctx.controller_id, position, ctx.source.id):
		ctx.log_note("the Special Summon did not happen")
		return null
	return target


# ---------------------------------------------------------------------------
# Targets at resolution
# ---------------------------------------------------------------------------

## The single card this effect targeted, but only if it is still in `required_zone`.
##
## Targets are locked in at activation (RULES_SPEC.md 10); by the time the link resolves
## the target may have been removed, and an effect must then do nothing to it rather than
## chase it into its new zone. Master prompt 44.
static func surviving_target(ctx: EffectContext,
		required_zone: Enums.Zone) -> CardInstance:
	var chosen = ctx.first_target()
	if chosen == null:
		return null
	var card: CardInstance = chosen
	if card.zone != required_zone:
		return null
	return card


# ---------------------------------------------------------------------------
# Control. RULES_SPEC.md 5.6 [S1 p.52]
#
# "Take control of that monster" changes the CONTROLLER and never the OWNER. The owner is
# what decides where the card goes when it leaves the field, and `GameState.move_card()`
# already forces every owner-bound zone to the owner, so a card taken by one of these
# primitives still goes to ITS OWN Graveyard when it dies under the other player's control.
# ---------------------------------------------------------------------------

## "Target 1 <ATTRIBUTE> monster your opponent controls" — the candidate set the three
## Charmers publish, and the shape `Enemy Controller` uses with `face_up_only`.
##
## Face-down monsters are excluded when `face_up_only` is set, because a face-down monster's
## Attribute is not a property either player may act on — the same reading
## `Champion's Vigilance` uses for "a Level 7 or higher Normal Monster".
static func opponent_monsters(ctx: EffectContext, attribute: String = "",
		face_up_only: bool = true) -> Array:
	var out: Array = []
	for entry in ctx.state.player(ctx.opponent_id()).monsters():
		var card: CardInstance = entry
		if card == null or card.definition == null:
			continue
		if face_up_only and not card.is_face_up():
			continue
		if attribute != "" and card.definition.attribute != attribute:
			continue
		out.append(card)
	return out


## "Take control of that target." Re-checks the target at RESOLUTION: activation legality is
## never carried forward, so a target that left the field, was flipped face-down, or already
## changed control is dropped here rather than acted on. Design decision 16.
##
## Returns true only if control actually changed. It legitimately returns false when the
## taker has no free Monster Zone — a monster can only be controlled from a Monster Zone.
static func take_control_of_target(ctx: EffectContext,
		duration: Enums.ControlDuration, face_up_only: bool = true) -> bool:
	var target := surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
	if target == null:
		ctx.log_note("the target is no longer on the field")
		return false
	if face_up_only and not target.is_face_up():
		ctx.log_note("the target is no longer face-up")
		return false
	if target.controller_id == ctx.controller_id:
		ctx.log_note("the target is already under this player's control")
		return false
	if not ctx.state.can_change_control(target, ctx.controller_id):
		ctx.log_note("there is no Monster Zone to take %s into" % target.card_name())
		return false
	return ctx.state.change_control(target, ctx.controller_id, ctx.source.id, duration)


## The Charmer clause, whole: "FLIP: Target 1 <ATTRIBUTE> monster your opponent controls;
## take control of that monster while this card is face-up on the field."
##
## `Aussa the Earth Charmer`, `Eria the Water Charmer` and `Wynn the Wind Charmer` carry this
## text WORD FOR WORD apart from the Attribute — verified against the official database, not
## remembered (`Research/CARD_RULINGS.md` §2.1: the current wording of all three targets, and
## Eria's older "face-up" wording is gone). Sharing the mechanics is therefore correct rather
## than an over-generalisation; each card still declares its own name, Attribute and text, and
## each has its own suite. If any of the three is ever errata'd apart from the others, it
## stops calling this and writes its own clause.
static func charmer_take_control(attribute: String, clause_text: String) -> EffectDef:
	var e := EffectDef.new("charmer_take_control", clause_text)
	e.of_type(Enums.EffectType.FLIP)
	# No "you can": the effect is MANDATORY. With no legal target it simply cannot activate,
	# which is not the same thing as being optional.
	e.mandatory()
	# A FLIP effect fires whenever the monster is turned face-up — by Flip Summon, by an
	# attack, or by a card effect — so it keys on the flip itself, never on
	# FLIP_SUMMON_SUCCEEDED. RULES_SPEC.md 5.4 [S1 p.28].
	e.trigger_events = [GameEvent.Kind.CARD_FLIPPED_FACE_UP]
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	# Flipped by an attacker, the Flip effect becomes a Chain Link in Damage Step sub-step 4,
	# so the Damage Step permission is the rules-mandated TIMING. RULES_SPEC.md 7.2.
	e.damage_step_permission = Enums.DamageStepPermission.MANDATORY_TRIGGER
	e.targeting(1)

	e.condition = func(ctx: EffectContext) -> bool:
		# THIS card being flipped face-up, not any card.
		var ev: GameEvent = ctx.trigger_event
		return ev != null and int(ev.data.get("card_id", -1)) == ctx.source.id

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return opponent_monsters(ctx, attribute, true)

	e.resolve = func(ctx: EffectContext) -> void:
		# "while this card is face-up on the field" — a lease on the Charmer, so control
		# returns the instant the Charmer is flipped face-down or leaves the field.
		if take_control_of_target(ctx, Enums.ControlDuration.WHILE_SOURCE_FACE_UP):
			ctx.log_note("took control of %s" % ctx.first_target().card_name())

	return e


# ---------------------------------------------------------------------------
# Costs. Paid at ACTIVATION, never at resolution. RULES_SPEC.md 10, master prompt 16.
# ---------------------------------------------------------------------------

## "Tribute 2 Dragon monsters" / "Tribute this card" as an activation COST.
##
## A Tribute is NOT a destruction, and it IS "sent to the Graveyard" [S1 p.53], which is
## exactly what `MoveReason.TRIBUTED` encodes. Returns the cards actually Tributed, or []
## if the full cost could not be paid — a cost is all-or-nothing.
static func pay_tribute_cost(ctx: EffectContext, candidates: Array, count: int,
		prompt: String) -> Array:
	var chosen := choose_n(ctx, candidates, count, Enums.DecisionKind.CHOOSE_TRIBUTES,
		prompt)
	if chosen.size() != count:
		return []
	var paid: Array = []
	for entry in chosen:
		var card: CardInstance = entry
		if not ctx.state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.TRIBUTED,
				{"source_id": ctx.source.id}):
			push_error("EffectPrimitives.pay_tribute_cost: could not Tribute %s"
				% card.card_name())
			return paid
		paid.append(card)
	return paid


## "Send 1 monster from your hand to the GY" as an activation COST.
##
## `MoveReason.SENT_AS_COST` rather than `DISCARDED`: PSCT distinguishes "discard" from
## "send from your hand to the GY", and a future card that triggers on a DISCARD must not
## see this. [S1 p.52-53]
static func pay_send_to_gy_cost(ctx: EffectContext, candidates: Array, count: int,
		prompt: String) -> Array:
	var chosen := choose_n(ctx, candidates, count, Enums.DecisionKind.CHOOSE_COST, prompt)
	if chosen.size() != count:
		return []
	var paid: Array = []
	for entry in chosen:
		var card: CardInstance = entry
		if not ctx.state.move_card(card, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.SENT_AS_COST, {"source_id": ctx.source.id}):
			push_error("EffectPrimitives.pay_send_to_gy_cost: could not send %s"
				% card.card_name())
			return paid
		paid.append(card)
	return paid


## "Discard 1 Spell" as an activation COST.
##
## `MoveReason.DISCARDED` rather than `SENT_AS_COST`, and the distinction is the one PSCT
## already draws: "discard" is specifically a card leaving the HAND for the Graveyard, while
## "send from your hand to the GY" is the wider wording `pay_send_to_gy_cost()` implements
## [S1 p.52-53]. `One for One` says "send", `Fairy Tail - Rella` says "discard", and a future
## card that triggers on one must not see the other. A cost is all-or-nothing.
static func pay_discard_cost(ctx: EffectContext, candidates: Array, count: int,
		prompt: String) -> Array:
	var chosen := choose_n(ctx, candidates, count, Enums.DecisionKind.CHOOSE_DISCARD, prompt)
	if chosen.size() != count:
		return []
	var paid: Array = []
	for entry in chosen:
		var card: CardInstance = entry
		if card.zone != Enums.Zone.HAND:
			push_error("EffectPrimitives.pay_discard_cost: %s is not in the hand"
				% card.card_name())
			return paid
		if not ctx.state.move_card(card, Enums.Zone.GRAVEYARD, Enums.MoveReason.DISCARDED,
				{"source_id": ctx.source.id}):
			push_error("EffectPrimitives.pay_discard_cost: could not discard %s"
				% card.card_name())
			return paid
		paid.append(card)
	return paid


## "Banish 1 Dragon monster from your GY" as an activation COST.
##
## Deliberately NOT `pay_send_to_gy_cost` with a different zone: banishing is not sending
## to the Graveyard [S1 p.53], it emits `CARD_BANISHED` rather than `CARD_SENT_TO_GY`, and a
## banished card is reachable by the clauses that say "banished" and by nothing else. A cost
## is all-or-nothing, so this returns [] rather than a partial payment.
static func pay_banish_cost(ctx: EffectContext, candidates: Array, count: int,
		prompt: String) -> Array:
	var chosen := choose_n(ctx, candidates, count, Enums.DecisionKind.CHOOSE_COST, prompt)
	if chosen.size() != count:
		return []
	var paid: Array = []
	for entry in chosen:
		var card: CardInstance = entry
		if not ctx.state.move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
				{"source_id": ctx.source.id}):
			push_error("EffectPrimitives.pay_banish_cost: could not banish %s"
				% card.card_name())
			return paid
		paid.append(card)
	return paid


## "Send ANY NUMBER of cards from your hand to the GY" as an activation COST.
##
## `choose_n` cannot express this: the count is the player's, not the card's. The minimum is
## ONE, not zero — "any number" still has to send something for the clause to have been
## paid, and `Wonder Balloons` measures its own effect by how many were sent, so a payment
## of nothing would resolve to nothing. Returns [] when the cost could not be paid at all.
static func pay_send_any_number_to_gy_cost(ctx: EffectContext, candidates: Array,
		prompt: String) -> Array:
	if candidates.is_empty():
		return []
	var options: Array = []
	for entry in candidates:
		var card: CardInstance = entry
		options.append(card.id)

	var chosen: Array = []
	if options.size() == 1:
		# One candidate and a minimum of one: there is nothing to decide.
		chosen = candidates.duplicate()
	else:
		var request := DecisionRequest.select(Enums.DecisionKind.CHOOSE_COST,
			ctx.controller_id, prompt, options, 1, options.size(), ctx.source, ctx.effect)
		var answer = ctx.ask(request)
		if not request.validate(answer):
			push_error("EffectPrimitives.pay_send_any_number_to_gy_cost: invalid selection for %s"
				% ctx.source.card_name())
			return []
		for value in (answer as Array):
			chosen.append(ctx.state.instance(int(value)))

	var paid: Array = []
	for entry in chosen:
		var card: CardInstance = entry
		if not ctx.state.move_card(card, Enums.Zone.GRAVEYARD,
				Enums.MoveReason.SENT_AS_COST, {"source_id": ctx.source.id}):
			push_error("EffectPrimitives.pay_send_any_number_to_gy_cost: could not send %s"
				% card.card_name())
			return paid
		paid.append(card)
	return paid


## How many cards a cost recorded under `COST_CARDS_KEY` actually consumed, read at
## RESOLUTION from the Chain Link's payload. Never recomputed from the board: the cards are
## already in the Graveyard and indistinguishable from anything else there.
static func cost_card_count(ctx: EffectContext) -> int:
	var ids = ctx.cost_payload.get(COST_CARDS_KEY, null)
	return (ids as Array).size() if ids is Array else 0


## Record what a cost consumed on the context, so the Chain Link carries it and the duel
## log can show what was actually paid.
static func record_cost(ctx: EffectContext, key: String, cards: Array) -> void:
	var ids: Array = []
	var names: Array = []
	for entry in cards:
		var card: CardInstance = entry
		ids.append(card.id)
		names.append(card.card_name())
	ctx.cost_payload[key] = ids
	ctx.cost_payload["%s_names" % key] = names


# ---------------------------------------------------------------------------
# Trigger conditions
# ---------------------------------------------------------------------------

## "When this card is destroyed by battle and sent to the GY".
##
## The semantic move reason is what makes this correct: a copy that was Tributed, or
## destroyed by an effect, must not fire it. [S1 p.52-53]
static func destroyed_by_battle_condition() -> Callable:
	return func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null:
			return false
		if int(ev.data.get("card_id", -1)) != ctx.source.id:
			return false
		return ev.data.get("reason") == Enums.MoveReason.DESTROYED_BY_BATTLE


## Did `event` report `card_id` LEAVING the field? "Leaves the field" is about the zones
## the card moved between, not about why, so this deliberately ignores the MoveReason:
## destroyed, banished, returned to the hand and Tributed all leave the field.
static func event_is_leaving_the_field(event: GameEvent, card_id: int) -> bool:
	if event == null or event.kind != GameEvent.Kind.CARD_MOVED:
		return false
	if int(event.data.get("card_id", -1)) != card_id:
		return false
	var from_zone: Enums.Zone = event.data.get("from_zone", Enums.Zone.DECK)
	var to_zone: Enums.Zone = event.data.get("to_zone", Enums.Zone.DECK)
	return Enums.is_on_field_zone(from_zone) and not Enums.is_on_field_zone(to_zone)


## Did `event` report `card_id` being DESTROYED (by battle or by a card effect)?
## Strictly narrower than leaving the field: a banished or Tributed monster is not
## destroyed [S1 p.52-53], and neither is an Equip Card that lost its host
## (`MoveReason.DESTROYED_BY_RULE`), which is a rules destruction rather than a card's.
static func event_is_destruction_of(event: GameEvent, card_id: int) -> bool:
	if event == null or event.kind != GameEvent.Kind.CARD_DESTROYED:
		return false
	if int(event.data.get("card_id", -1)) != card_id:
		return false
	var reason = event.data.get("reason", null)
	return reason == Enums.MoveReason.DESTROYED_BY_BATTLE \
		or reason == Enums.MoveReason.DESTROYED_BY_EFFECT


## "When this FACE-UP card ON THE FIELD is sent to the GY" — `Castle of Dragon Souls`,
## `Five Brothers Explosion`.
##
## Three separate requirements, and dropping any one of them widens the clause:
##   * it must be a "sent to the GY" movement, which `CARD_SENT_TO_GY` already encodes
##     (a BANISHED card is not sent to the GY [S1 p.53], and neither is a bounced one);
##   * it must have come FROM the field, so a copy discarded from the hand does not fire it;
##   * it must have been FACE-UP, which is only answerable from `CardInstance.last_move_*`
##     because the move itself turns a card in the Graveyard face-up. RULES_SPEC.md 15.
static func event_is_sent_to_gy_from_face_up_field(event: GameEvent,
		card: CardInstance) -> bool:
	if event == null or event.kind != GameEvent.Kind.CARD_SENT_TO_GY:
		return false
	if card == null or int(event.data.get("card_id", -1)) != card.id:
		return false
	var from_zone: Enums.Zone = event.data.get("from_zone", Enums.Zone.DECK)
	if not Enums.is_on_field_zone(from_zone):
		return false
	return card.last_move_was_face_up


## Was the movement `event` reports caused by a card effect belonging to `pid`?
##
## "by your OPPONENT'S CARD EFFECT" (`Five Brothers Explosion`) is two questions, not one:
## the movement has to be an EFFECT — battle destruction and a rules destruction are not —
## and the card that caused it has to be one that player controls. The agent is read from
## the move's `source_id`; a movement with no source (a rules movement) belongs to nobody.
static func event_caused_by_effect_of(state: GameState, event: GameEvent,
		pid: int) -> bool:
	if event == null:
		return false
	var reason = event.data.get("reason", null)
	if reason != Enums.MoveReason.DESTROYED_BY_EFFECT \
			and reason != Enums.MoveReason.SENT_TO_GY_BY_EFFECT:
		return false
	var source_id := int(event.data.get("source_id", -1))
	if source_id == -1:
		return false
	var agent = state.instance(source_id)
	if agent == null:
		return false
	return (agent as CardInstance).controller_id == pid


# ---------------------------------------------------------------------------
# Temporary stat changes
# ---------------------------------------------------------------------------

## "It gains N ATK until the end of this turn (even if this card leaves the field)."
##
## This is NOT a continuous modifier. A continuous modifier is state-derived and vanishes
## the instant its source stops applying, which is the exact opposite of what this clause
## says. It is a one-off modifier with the turn-scoped `"end_of_turn"` duration, which
## `TurnFlow._end_of_turn_cleanup()` removes from every instance when the turn ends —
## whoever's turn it was, and whether or not the source is still on the field.
## RULES_SPEC.md 8.
static func gain_atk_until_end_of_turn(ctx: EffectContext, card: CardInstance,
		amount: int) -> bool:
	if card == null or amount == 0:
		return false
	card.add_atk_modifier(ctx.source.id, amount, "end_of_turn",
		"%d:%s:end_of_turn:%d" % [ctx.source.id, ctx.effect.effect_id,
			ctx.state.turn_number])
	return true


# ---------------------------------------------------------------------------
# Banishing as an EFFECT (not as a cost — see pay_banish_cost)
# ---------------------------------------------------------------------------

## "Banish that target." Resolution-time, so the target is re-checked first: a card that
## already left `required_zone` is no longer a legal thing to banish and the clause simply
## does nothing to it. Master prompt 44.
static func banish_target(ctx: EffectContext, required_zone: Enums.Zone) -> CardInstance:
	var target := surviving_target(ctx, required_zone)
	if target == null:
		ctx.log_note("the target is no longer where the clause needs it")
		return null
	if not ctx.state.move_card(target, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED,
			{"source_id": ctx.source.id}):
		ctx.log_note("the banish did not happen")
		return null
	return target


# ---------------------------------------------------------------------------
# Counting Continuous Spell/Trap Cards. `Five Brothers Explosion`.
# ---------------------------------------------------------------------------

static func is_continuous_spell_or_trap(card: CardInstance) -> bool:
	if card == null or card.definition == null:
		return false
	var kind: Enums.STKind = card.definition.st_kind
	return kind == Enums.STKind.CONTINUOUS_SPELL or kind == Enums.STKind.CONTINUOUS_TRAP


## "Each Continuous Spell/Trap Card you control."
##
## FACE-UP only. A Set Spell/Trap Card is face-down, and a face-down card's specific
## subtype is not a property either player may act on — the same reasoning that stops a
## clause reading "1 Effect Monster on the field" from reaching a face-down monster. A card
## activated this turn counts: activation is what put it face-up on the field [S1 p.28-30],
## which is why `Five Brothers Explosion` counts ITSELF when its own activation resolves.
## Recorded as a decision in Research/CARD_RULINGS.md R16.
static func continuous_spell_traps_controlled(state: GameState, pid: int) -> Array:
	var out: Array = []
	for entry in state.player(pid).controlled_cards():
		var card: CardInstance = entry
		if not card.is_face_up():
			continue
		if is_continuous_spell_or_trap(card):
			out.append(card)
	return out


## "Each Continuous Spell/Trap Card in your Graveyard." Every card in a Graveyard is public
## and face-up, so unlike the field version there is nothing to filter on visibility.
static func continuous_spell_traps_in_graveyard(state: GameState, pid: int) -> Array:
	var out: Array = []
	for entry in state.player(pid).graveyard:
		var card: CardInstance = entry
		if is_continuous_spell_or_trap(card):
			out.append(card)
	return out


# ---------------------------------------------------------------------------
# Continuous-Trap revival links. RULES_SPEC.md 15.
#
# `Birthright` and `Call of the Haunted` share the first two of their three clauses and
# differ on the third, so what is shared lives here and the difference stays in the two
# registry files. Nothing here decides WHICH event breaks the link.
# ---------------------------------------------------------------------------

## Record that this card Special Summoned `monster` and is now linked to it.
static func link_revived_monster(ctx: EffectContext, monster: CardInstance) -> void:
	ctx.state.remember(ctx.source, REVIVED_MONSTER_KEY, monster.id)


## The monster this card Special Summoned, or null. Readable after the card left the field.
static func revived_monster(ctx: EffectContext) -> CardInstance:
	var linked = ctx.state.recall_card(ctx.source, REVIVED_MONSTER_KEY)
	return linked as CardInstance if linked != null else null


static func clear_revival_link(ctx: EffectContext) -> void:
	ctx.state.forget(ctx.source, REVIVED_MONSTER_KEY)


## The monster a Continuous card TARGETED at activation and stays attached to
## (`Fiendish Chain`). Separate from the revival link on purpose: this card did not Summon
## the monster and must never be confused with one that did.
static func link_afflicted_monster(ctx: EffectContext, monster: CardInstance) -> void:
	ctx.state.remember(ctx.source, AFFLICTED_MONSTER_KEY, monster.id)


static func afflicted_monster(ctx: EffectContext) -> CardInstance:
	var linked = ctx.state.recall_card(ctx.source, AFFLICTED_MONSTER_KEY)
	return linked as CardInstance if linked != null else null


static func clear_afflicted_link(ctx: EffectContext) -> void:
	ctx.state.forget(ctx.source, AFFLICTED_MONSTER_KEY)


## "Activate this card by targeting 1 <...> in your GY; Special Summon that target in
## Attack Position." — the resolution shared by both Continuous Traps.
##
## The position is FIXED by the card text, so unlike `Monster Reborn` nobody is asked.
static func revive_target_in_attack_position(ctx: EffectContext) -> CardInstance:
	var target := surviving_target(ctx, Enums.Zone.GRAVEYARD)
	if target == null:
		ctx.log_note("the target is no longer in the Graveyard")
		return null
	if not ctx.me().has_free_monster_zone():
		ctx.log_note("no free Monster Zone")
		return null
	if ctx.engine == null:
		push_error("EffectPrimitives.revive_target_in_attack_position: no engine attached")
		return null
	if not ctx.engine.special_summon(target, ctx.controller_id,
			Enums.Position.FACE_UP_ATTACK, ctx.source.id):
		ctx.log_note("the Special Summon did not happen")
		return null
	link_revived_monster(ctx, target)
	return target


## "When this card leaves the field, destroy that monster." — shared verbatim by both
## Continuous Traps, so it is one implementation rather than two.
static func destroy_linked_monster(ctx: EffectContext) -> bool:
	var monster := revived_monster(ctx)
	clear_revival_link(ctx)
	if monster == null or not monster.is_on_field():
		ctx.log_note("the monster it Summoned is no longer on the field")
		return false
	var destroyed := ctx.state.destroy(monster, Enums.MoveReason.DESTROYED_BY_EFFECT,
		ctx.source.id)
	ctx.log_note("destroyed %s" % monster.card_name())
	return destroyed


## "…destroy this card." — the other half of the mutual link, from the monster's side.
static func destroy_self(ctx: EffectContext) -> bool:
	clear_revival_link(ctx)
	if not ctx.source.is_on_field():
		return false
	return ctx.state.destroy(ctx.source, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)


# ---------------------------------------------------------------------------
# Summoning procedures
# ---------------------------------------------------------------------------

## "You can only control 1 '<name>'." A hard limit on how many copies may be on the field
## at once [S1 p.53 "Control"].
##
## A face-down MONSTER counts. It occupies a Monster Zone, it is fully in play, and it is
## unambiguously a monster you control — which is why `Inari Fire` and `Ranryu` are blocked
## by a Set copy.
##
## A face-down SPELL/TRAP does not. A Set Spell/Trap has not been activated, applies none of
## its text and is not yet in play as that card; the same reasoning that keeps a face-down
## card out of every other clause worded by specific card type. The alternative reading
## makes the restriction incoherent for a Trap: holding two Set copies of
## `Castle of Dragon Souls` would forbid activating EITHER of them, and the card would
## become unplayable the moment you drew a second one. The limit is therefore re-tested at
## the moment a Spell/Trap is activated, which is when the second copy would actually reach
## the field face-up. Recorded as a decision in Research/CARD_RULINGS.md R19.
static func controls_no_other_copy(ctx: EffectContext) -> bool:
	for entry in ctx.me().controlled_cards():
		var card: CardInstance = entry
		if card == ctx.source or card.card_name() != ctx.source.card_name():
			continue
		if card.is_monster() or card.is_face_up():
			return false
	return true


## "If you control a <race> monster, you can Special Summon this card (from your hand)."
## A face-DOWN monster's race is not something either player may act on, so the monster
## must be face-up — the clause describes a board state that is public.
static func controls_face_up_monster_of_race(ctx: EffectContext, race: String) -> bool:
	for entry in ctx.me().face_up_monsters():
		var card: CardInstance = entry
		if card.definition != null and card.definition.race == race:
			return true
	return false


## Special Summon the effect's OWN source from `required_zone`, in the position its
## controller picks. The shape of every "Special Summon it/this card" self-revival.
static func special_summon_self(ctx: EffectContext,
		required_zone: Enums.Zone) -> bool:
	if ctx.engine == null:
		push_error("EffectPrimitives.special_summon_self: no engine attached")
		return false
	if ctx.source.zone != required_zone:
		ctx.log_note("this card is no longer where the clause needs it")
		return false
	if not ctx.me().has_free_monster_zone():
		ctx.log_note("no free Monster Zone")
		return false
	var position := choose_face_up_position(ctx,
		"Special Summon %s in which position?" % ctx.source.card_name())
	return ctx.engine.special_summon(ctx.source, ctx.controller_id, position, ctx.source.id)


## "…and make its ATK/DEF 0." An OVERRIDE of the printed values rather than a modifier:
## the printed ATK stays what it is, which is what "original ATK" reads [S1 p.55].
static func set_atk_and_def(card: CardInstance, value: int) -> void:
	if card == null:
		return
	card.atk_override = value
	card.def_override = value


## Did the phase just change to `phase`, on the turn of `turn_player_id`?
static func event_is_phase_change_to(event: GameEvent, phase: Enums.Phase,
		turn_player_id: int) -> bool:
	if event == null or event.kind != GameEvent.Kind.PHASE_CHANGED:
		return false
	if event.data.get("to", null) != phase:
		return false
	return int(event.data.get("turn_player", -1)) == turn_player_id


## Was this monster Special Summoned by its OWN procedure `effect_id` this turn?
## "Special Summoned this way" is narrower than "Special Summoned" (CARD_RULINGS.md §2.1).
static func summoned_this_way_this_turn(ctx: EffectContext, effect_id: String) -> bool:
	var card := ctx.source
	return card.summoned_by_procedure_id == effect_id \
		and card.turn_summoned == ctx.state.turn_number


# ---------------------------------------------------------------------------
# Equipping. RULES_SPEC.md 16 [S1 p.29, p.53, p.55]
# ---------------------------------------------------------------------------

## "…equip this card to that target." Equips the effect's SOURCE to its target, which is
## the shape both `Gagagashield` and `Rider of the Storm Winds` use.
##
## Returns the monster it was equipped to, or null. A target that is no longer a face-up
## monster on the field at resolution is not equipped to — the card simply fails to equip.
static func equip_source_to_target(ctx: EffectContext) -> CardInstance:
	var target := surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
	if target == null or not target.is_face_up():
		ctx.log_note("the target is no longer a face-up monster on the field")
		return null
	if not ctx.state.equip_to(ctx.source, target, ctx.source.id):
		ctx.log_note("the equip did not happen")
		return null
	return target


## The monster this Equip Card is currently equipped to, or null.
static func equipped_host(ctx: EffectContext) -> CardInstance:
	if ctx.source.equipped_to_id == -1:
		return null
	var host = ctx.state.instance(ctx.source.equipped_to_id)
	return host as CardInstance if host != null else null


## Record that this card attached `equip` with its own effect, on the current turn.
static func link_equipped_by_effect(ctx: EffectContext, equip: CardInstance) -> void:
	ctx.state.remember(ctx.source, EQUIPPED_BY_EFFECT_KEY, equip.id)
	ctx.state.remember(ctx.source, EQUIPPED_BY_EFFECT_TURN_KEY, ctx.state.turn_number)


## The Equip Card this card attached with its own effect, or null.
static func equipped_by_effect(ctx: EffectContext) -> CardInstance:
	var linked = ctx.state.recall_card(ctx.source, EQUIPPED_BY_EFFECT_KEY)
	return linked as CardInstance if linked != null else null


## The turn on which it did so, or -1.
static func equipped_by_effect_turn(ctx: EffectContext) -> int:
	var turn = ctx.state.recall(ctx.source, EQUIPPED_BY_EFFECT_TURN_KEY, -1)
	return int(turn)


static func clear_equipped_by_effect_link(ctx: EffectContext) -> void:
	ctx.state.forget(ctx.source, EQUIPPED_BY_EFFECT_KEY)
	ctx.state.forget(ctx.source, EQUIPPED_BY_EFFECT_TURN_KEY)


## "…equip 1 Equip Spell from your hand, Deck, or GY to THIS CARD."
##
## The other direction from `equip_source_to_target()`: here the effect's source is the HOST
## and some other card becomes the Equip Card. `Fairy Tail - Rella` is the pool's only such
## clause. Returns the card that was equipped, or null.
static func equip_card_to_source(ctx: EffectContext, equip: CardInstance) -> CardInstance:
	if equip == null:
		return null
	if not ctx.source.is_on_field() or not ctx.source.is_face_up():
		ctx.log_note("this card is no longer a face-up monster on the field")
		return null
	if not ctx.state.equip_to(equip, ctx.source, ctx.source.id):
		ctx.log_note("the equip did not happen")
		return null
	return equip


# ---------------------------------------------------------------------------
# Negation. `Champion's Vigilance`. Master prompt 18 — the two kinds are different.
#
# The two response categories stay on separate timing paths on purpose. A Summon that has
# been DECLARED is not on the Chain at all: the monster waits in `Zone.IN_TRANSIT` and the
# negation goes through `DuelEngine.negate_pending_summon()`. An activated Spell/Trap IS a
# Chain Link and is negated through `ChainManager.negate_activation()`. An activated effect
# that WOULD Special Summon is the second case, never the first — its Summon has not been
# declared yet when the negation is activated. PROJECT_STATE.md design decision 9.
# ---------------------------------------------------------------------------

## Is a Summon currently declared and waiting for its window to close?
##
## Read from the STATE rather than from the engine, because a condition is also evaluated in
## pure-legality paths where `ctx.engine` is null. `GameState.pending_summon_card_id` is
## written by every `SummonRules.begin_*_summon()` and cleared on completion or negation.
##
## It is deliberately NOT "is a monster in `Zone.IN_TRANSIT`?", which was the earlier reading:
## that answers only for the Normal and Special routes. A **Flip Summon**'s monster never
## leaves its Monster Zone, so scanning `in_transit` reported "no Summon is pending" for a
## Flip Summon that had genuinely been declared.
static func summon_is_pending(ctx: EffectContext) -> CardInstance:
	if ctx.state.pending_summon_card_id == -1:
		return null
	var pending = ctx.state.instance(ctx.state.pending_summon_card_id)
	if pending == null or not pending.is_monster():
		return null
	return pending


## "Negate the Summon, and if you do, destroy that card."
##
## The monster is in `Zone.IN_TRANSIT`, so it never occupied a Monster Zone and no
## successful-summon event is emitted — `DuelEngine._close_window()` calls
## `SummonRules.abort_summon()` instead. Destroying it goes through the one destruction
## entry point; `abort_summon()` then finds nothing left in transit to send back.
static func negate_summon_and_destroy(ctx: EffectContext) -> bool:
	if ctx.engine == null:
		push_error("EffectPrimitives.negate_summon_and_destroy: no engine attached")
		return false
	var negated = ctx.engine.negate_pending_summon(ctx.source.id)
	if negated == null:
		ctx.log_note("there is no Summon left to negate")
		return false
	var monster: CardInstance = negated
	ctx.log_note("negated the Summon of %s" % monster.card_name())
	# "and IF YOU DO" — the destruction is conditional on the negation having happened,
	# which it has.
	return ctx.state.destroy(monster, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)


## The unresolved Chain Link this effect would be answering: the one immediately below it.
##
## `below_link_number` is the responding effect's own link number at resolution, or 0 while
## merely testing legality — in which case the top link is the one being answered, since the
## responder is not on the Chain yet. Returns null when that link is not a Spell/Trap CARD
## activation, which is what makes "a Spell/Trap Card is activated" narrower than
## "an effect is activated": a monster's Ignition or Quick Effect is neither.
static func spell_trap_activation_below(ctx: EffectContext,
		below_link_number: int = 0) -> ChainLink:
	var wanted := below_link_number - 1 if below_link_number > 0 else ctx.state.chain.size()
	if wanted < 1:
		return null
	for entry in ctx.state.chain:
		var link: ChainLink = entry
		if link.link_number != wanted:
			continue
		if link.resolved or link.activation_negated:
			return null
		if link.effect == null \
				or link.effect.effect_type != Enums.EffectType.CARD_ACTIVATION:
			return null
		if link.source_card == null or link.source_card.is_monster():
			return null
		return link
	return null


## "Negate the activation, and if you do, destroy that card."
##
## Negating the ACTIVATION, not the effect: the card is treated as not having been
## successfully activated, so a "when this card is activated" trigger has nothing to see.
## What it does NOT undo is the cost — a cost is paid at activation and is never refunded
## (RULES_SPEC.md 10), which is the same rule `KaibamanTests :: the Tribute is a COST` pins
## down from the other side.
static func negate_activation_and_destroy(ctx: EffectContext) -> bool:
	var link_number := ctx.link.link_number if ctx.link != null else 0
	var target_link := spell_trap_activation_below(ctx, link_number)
	if target_link == null:
		ctx.log_note("there is no Spell/Trap activation left to negate")
		return false
	if ctx.engine == null or ctx.engine.chain == null:
		push_error("EffectPrimitives.negate_activation_and_destroy: no chain attached")
		return false
	if not ctx.engine.chain.negate_activation(target_link.link_number, ctx.source):
		ctx.log_note("the activation could not be negated")
		return false
	var card: CardInstance = target_link.source_card
	ctx.log_note("negated the activation of %s" % card.card_name())
	# "and if you do, destroy that card" — a card activated from the hand is now face-up in
	# a Spell & Trap Zone, so this is an ordinary field destruction. It can still legitimately
	# fail (a prevention effect), and the negation stands either way.
	return ctx.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id)


# ---------------------------------------------------------------------------
# Predicates for Spell/Trap cards
# ---------------------------------------------------------------------------

## "1 Spell" — any Spell Card, whatever its subtype.
static func spell_card() -> Callable:
	return func(card: CardInstance) -> bool:
		return card.definition != null \
			and card.definition.category == Enums.Category.SPELL


## "1 Equip Spell" — an exact subtype, not "a Spell that happens to equip". An equipped
## TRAP (`Gagagashield`, `Kunai with Chain`) is an Equip CARD but is not an Equip SPELL
## [S1 p.53], so this deliberately reads `st_kind` rather than the equip relationship.
static func equip_spell_card() -> Callable:
	return func(card: CardInstance) -> bool:
		return card.definition != null \
			and card.definition.st_kind == Enums.STKind.EQUIP_SPELL


# ---------------------------------------------------------------------------
# Counters. RULES_SPEC.md 14.
# ---------------------------------------------------------------------------

## "1 face-up card on the field that you can place a <kind> Counter on" — either side of
## the field. The capacity question belongs to the rules layer
## (`GameState.can_place_counter()`), because it is a property of the TARGET rather than of
## the searching card.
static func counter_recipients(ctx: EffectContext, kind: String) -> Array:
	return ctx.state.cards_that_can_receive_counter(kind)


## "…place 1 <kind> Counter on that target." Resolution-time, so the target is re-checked:
## a card that is no longer a legal recipient simply does not receive one. Master prompt 44.
static func place_counter_on_target(ctx: EffectContext, kind: String,
		amount: int = 1) -> CardInstance:
	var target := surviving_target(ctx, Enums.Zone.MONSTER_ZONE)
	if target == null:
		# The clause says "1 face-up CARD on the field", not "1 monster", so a Spell/Trap
		# recipient is equally legal and lives in a different zone.
		var chosen = ctx.first_target()
		target = chosen as CardInstance if chosen != null else null
		if target == null or not target.is_on_field():
			ctx.log_note("the target is no longer on the field")
			return null
	if not ctx.state.can_place_counter(target, kind):
		ctx.log_note("the target can no longer receive a %s" % kind)
		return null
	if not ctx.state.place_counters(target, kind, amount, ctx.source.id):
		ctx.log_note("the counter was not placed")
		return null
	return target
