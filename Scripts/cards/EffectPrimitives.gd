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
