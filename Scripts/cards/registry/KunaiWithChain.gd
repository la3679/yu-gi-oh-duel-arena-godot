extends RefCounted

## Kunai with Chain — Normal Trap that offers a CHOICE of effects and may become an
## Equip Card.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Activate 1 or both of these effects (simultaneously);
##    ●When an opponent's monster declares an attack: Target the attacking monster;
##      change that target to Defense Position.
##    ●Target 1 face-up monster you control; equip this card to that target.
##      It gains 500 ATK."
##
## This is NOT "a generic Equip Trap". Three things make it different, and each of them is
## a legal choice the player actually gets to make:
##
##   1. **"Activate 1 or BOTH".** There are three legal activations, not one, and they are
##      genuinely different plays: the first bullet alone, the second bullet alone, or both
##      at once. They are three CARD_ACTIVATION EffectDefs rather than one clause with a
##      hidden mode flag, because the engine publishes the legal actions and re-validates the
##      submitted one (PROJECT_STATE.md design decision 1) — a mode that is not part of an
##      action is a mode the engine cannot check.
##   2. **The two bullets have different timings.** The first is "When an opponent's monster
##      declares an attack", so it — and therefore the "both" activation — is only legal in
##      the response window an attack declaration opens. The second bullet carries no timing
##      requirement and may be activated whenever a Set Normal Trap may be [S1 p.30].
##   3. **"(simultaneously)".** Both bullets are ONE activation and ONE Chain Link, so both
##      targets are fixed at that moment and both resolve together. There is one copy of the
##      card, so activating it twice is not an alternative.
##
## Four EffectDefs for two printed bullets, and the fourth is not padding: "It gains 500
## ATK" is a CONTINUOUS effect the Equip Card grants its host for as long as it is equipped
## [S1 p.55], which is a different lifetime from the activation that equipped it — the same
## split `Gagagashield` uses for its protection clause. PROJECT_STATE.md design decision 29.
##
## Research/CARD_RULINGS.md R22 records the one ruling this card needs: changing the
## ATTACKING monster to Defense Position does not cancel the attack.

const CARD_NAME := "Kunai with Chain"

const ATK_BONUS := 500

const CLAUSE_HEADER := "Activate 1 or both of these effects (simultaneously);"
const BULLET_DEFENSE := "When an opponent's monster declares an attack: Target the " \
	+ "attacking monster; change that target to Defense Position."
const BULLET_EQUIP := "Target 1 face-up monster you control; equip this card to that " \
	+ "target. It gains 500 ATK."


func effects() -> Array:
	# The two bullets' shared reads are built once and captured, the same way
	# `ShiningAngel` captures its search predicate. A registry file declares no
	# `class_name` (77 of them would pollute the global class list), so a lambda cannot
	# reach a static method of its own file by name.

	## "the attacking monster", and only when it is an OPPONENT's monster. There is at most
	## one attacking monster at a time, so this clause's target has exactly one candidate —
	## the player chooses whether to activate, not what to hit.
	var attacking_monster := func(ctx: EffectContext) -> CardInstance:
		var attacker = ctx.state.current_attacker
		if attacker == null:
			return null
		var card: CardInstance = attacker
		if card.controller_id == ctx.controller_id:
			return null
		if card.zone != Enums.Zone.MONSTER_ZONE or not card.is_face_up():
			return null
		return card

	## "1 face-up monster you control" — the host this card would equip itself to.
	var own_face_up := func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in ctx.me().face_up_monsters():
			out.append(entry)
		return out

	## "change that target to Defense Position."
	##
	## A card effect, not a manual position change: it neither spends nor is blocked by the
	## once-per-turn manual-change allowance [S1 p.26], and it applies to a monster that has
	## already attacked. A monster already in face-up Defense Position is left alone.
	var change_to_defense := func(ctx: EffectContext, target) -> bool:
		if target == null:
			ctx.log_note("there is no attacking monster left to change")
			return false
		var card: CardInstance = target
		if card.zone != Enums.Zone.MONSTER_ZONE or not card.is_face_up():
			ctx.log_note("the attacking monster is no longer face-up on the field")
			return false
		if card.position == Enums.Position.FACE_UP_DEFENSE:
			ctx.log_note("%s is already in Defense Position" % card.card_name())
			return false
		ctx.state.set_battle_position(card, Enums.Position.FACE_UP_DEFENSE, true,
			ctx.source.id)
		ctx.log_note("changed %s to Defense Position" % card.card_name())
		return true

	return [
		_defense_only(attacking_monster, change_to_defense),
		_equip_only(own_face_up),
		_both(attacking_monster, own_face_up, change_to_defense),
		_atk_bonus(),
	]


## Common activation shape: a Set Normal Trap, Spell Speed 2.
func _as_trap_activation(e: EffectDef) -> EffectDef:
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	return e


# ---------------------------------------------------------------------------
# Bullet 1 alone
# ---------------------------------------------------------------------------

func _defense_only(attacking_monster: Callable, change_to_defense: Callable) -> EffectDef:
	var e := _as_trap_activation(EffectDef.new("change_attacker_to_defense",
		CLAUSE_HEADER + " " + BULLET_DEFENSE))
	e.trigger_events = [GameEvent.Kind.ATTACK_DECLARED]
	e.targeting(1)
	e.ruling("R22")

	e.condition = func(ctx: EffectContext) -> bool:
		return attacking_monster.call(ctx) != null

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var attacker = attacking_monster.call(ctx)
		return [] if attacker == null else [attacker]

	e.resolve = func(ctx: EffectContext) -> void:
		change_to_defense.call(ctx, ctx.first_target())

	return e


# ---------------------------------------------------------------------------
# Bullet 2 alone
# ---------------------------------------------------------------------------

func _equip_only(own_face_up: Callable) -> EffectDef:
	var e := _as_trap_activation(EffectDef.new("equip_to_your_monster",
		CLAUSE_HEADER + " " + BULLET_EQUIP))
	e.targeting(1)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		return own_face_up.call(ctx)

	e.resolve = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equip_source_to_target(ctx)
		if host != null:
			ctx.log_note("equipped to %s" % host.card_name())

	return e


# ---------------------------------------------------------------------------
# Both bullets, simultaneously
# ---------------------------------------------------------------------------

func _both(attacking_monster: Callable, own_face_up: Callable,
		change_to_defense: Callable) -> EffectDef:
	var e := _as_trap_activation(EffectDef.new("both_effects",
		CLAUSE_HEADER + " " + BULLET_DEFENSE + " " + BULLET_EQUIP))
	e.trigger_events = [GameEvent.Kind.ATTACK_DECLARED]
	e.targeting(2)
	e.ruling("R22")

	e.condition = func(ctx: EffectContext) -> bool:
		if attacking_monster.call(ctx) == null:
			return false
		return not (own_face_up.call(ctx) as Array).is_empty()

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		var attacker = attacking_monster.call(ctx)
		if attacker != null:
			out.append(attacker)
		out.append_array(own_face_up.call(ctx))
		return out

	# The candidate list is the UNION of two different clauses' candidates, so membership
	# plus the count is not enough: two of your own monsters would satisfy both while being
	# an illegal selection. Exactly one of the two has to be the attacking monster.
	e.targets_valid = func(ctx: EffectContext, chosen: Array) -> bool:
		if chosen.size() != 2:
			return false
		var attacker = attacking_monster.call(ctx)
		if attacker == null:
			return false
		var attackers := 0
		var own := 0
		for entry in chosen:
			var card: CardInstance = entry
			if card == attacker:
				attackers += 1
			elif card.controller_id == ctx.controller_id and card.is_face_up() \
					and card.zone == Enums.Zone.MONSTER_ZONE:
				own += 1
		return attackers == 1 and own == 1

	e.resolve = func(ctx: EffectContext) -> void:
		# "(simultaneously)" — one resolution, both bullets, in the printed order. Each
		# half re-checks its own target: either may have become illegal since activation.
		var attacker: CardInstance = null
		var host: CardInstance = null
		for entry in ctx.targets():
			var card: CardInstance = entry
			if card.controller_id == ctx.controller_id:
				host = card
			else:
				attacker = card
		change_to_defense.call(ctx, attacker)
		if host == null or host.zone != Enums.Zone.MONSTER_ZONE or not host.is_face_up():
			ctx.log_note("the equip target is no longer a face-up monster you control")
			return
		if ctx.state.equip_to(ctx.source, host, ctx.source.id):
			ctx.log_note("changed the attacker to Defense Position and equipped to %s"
				% host.card_name())

	return e


# ---------------------------------------------------------------------------
# The granted continuous effect
# ---------------------------------------------------------------------------

func _atk_bonus() -> EffectDef:
	var e := EffectDef.new("equipped_monster_gains_500_atk", "It gains 500 ATK.")
	e.of_type(Enums.EffectType.CONTINUOUS)

	# State-derived: it applies exactly while this card is equipped and disappears by itself
	# the moment it is not. The printed and ORIGINAL ATK are untouched [S1 p.55].
	e.apply_continuous = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equipped_host(ctx)
		if host != null:
			ContinuousEffects.add_atk(ctx.source, host, ATK_BONUS)

	return e
