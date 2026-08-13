extends RefCounted

## Gagagashield — Normal Trap that becomes an Equip Card.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "Target 1 Spellcaster monster you control; equip this card to that target. Twice per
##    turn, it cannot be destroyed by battle or card effects."
##
## Two official clauses, so two EffectDefs. Research/CARD_RULINGS.md R10.
##
##   1. "Equipped Traps remain Trap Cards" [S1 p.53] — this card does not become a Spell.
##      What changes is that it is now an Equip Card, occupying one of its controller's
##      Spell & Trap Zones and tied to one face-up monster. Because it is Set in a
##      Spell & Trap Zone already, equipping needs no new zone.
##   2. It TARGETS, so the Spellcaster is fixed at activation. If the target is no longer
##      a face-up monster you control when the card resolves, it does not equip — and a
##      Normal Trap that fails to equip goes to the Graveyard like any other resolved
##      Normal Trap [S1 p.30].
##   3. "TWICE per turn, IT cannot be destroyed" — "it" is the EQUIPPED MONSTER, not this
##      card. The protection is counted, so it is not an ordinary continuous "cannot be
##      destroyed" flag: it is a rules QUERY that the destruction gate asks, and the
##      rules layer spends one of the two uses each time the answer is yes.
##      `EffectDef.uses_per_turn` is what bounds it, and the count self-expires with the
##      turn (`CardInstance.uses_this_turn`). RULES_SPEC.md 17.
##   4. "by battle OR card effects" — both, which is why the query does not filter on the
##      MoveReason at all. It deliberately does NOT cover `DESTROYED_BY_RULE`: an Equip
##      Card losing its host is destroyed by the game rules, not by a card.
##   5. If the equipped monster leaves the field or is flipped face-down, this card is
##      destroyed by the rules [S1 p.29, p.55]. Nothing here implements that — it is
##      generic Equip behaviour and lives in `GameState`.

const CARD_NAME := "Gagagashield"

const CLAUSE_EQUIP := "Target 1 Spellcaster monster you control; equip this card to " \
	+ "that target."
const CLAUSE_PROTECT := "Twice per turn, it cannot be destroyed by battle or card effects."

const USES_PER_TURN := 2


func effects() -> Array:
	return [_equip(), _protection()]


func _equip() -> EffectDef:
	var e := EffectDef.new("equip_to_a_spellcaster_you_control", CLAUSE_EQUIP)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in ctx.me().face_up_monsters():
			var card: CardInstance = entry
			if card.definition != null and card.definition.race == "Spellcaster":
				out.append(card)
		return out

	e.resolve = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equip_source_to_target(ctx)
		if host != null:
			ctx.log_note("equipped to %s" % host.card_name())

	return e


func _protection() -> EffectDef:
	var e := EffectDef.new(GameState.DESTRUCTION_PREVENTION_EFFECT_ID, CLAUSE_PROTECT)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.uses_per_turn = USES_PER_TURN

	# A PURE query: it answers "does this clause stop that destruction?" and never spends
	# anything itself. Spending a use is the rules layer's job, which is what keeps the
	# two uses countable and the query free of side effects.
	e.condition = func(ctx: EffectContext) -> bool:
		var victim = ctx.params.get("card", null)
		if victim == null:
			return false
		var host := EffectPrimitives.equipped_host(ctx)
		if host == null:
			# Not equipped to anything: "it" refers to nothing, so nothing is protected.
			return false
		if (victim as CardInstance).id != host.id:
			return false
		var reason = ctx.params.get("reason", null)
		return reason == Enums.MoveReason.DESTROYED_BY_BATTLE \
			or reason == Enums.MoveReason.DESTROYED_BY_EFFECT

	return e
