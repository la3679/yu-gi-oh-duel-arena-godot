extends RefCounted

## Rider of the Storm Winds — Level 1 LIGHT Dragon Tuner Effect Monster, 500 / 200.
##
## Official text (verified against the Konami card database, see
## Data/generated/konami_cards.json):
##
##   "You can target 1 Dragon Normal Monster you control; equip this monster from your
##    hand or field to that target. If a monster equipped with this card attacks a
##    Defense Position monster, inflict piercing battle damage to your opponent. If a
##    monster equipped with this card would be destroyed, destroy this card instead."
##
## Three official clauses, so three EffectDefs. Research/CARD_RULINGS.md R9.
##
##   1. "equipped monsters are considered to be Equip Spells" and "The term 'Equip Card'
##      includes … monsters equipped to other monsters" [S1 p.53]. So this monster becomes
##      an Equip Card and occupies one of its controller's Spell & Trap Zones, whether it
##      came from the hand or from a Monster Zone. If there is no free Spell & Trap Zone
##      there is nowhere for it to go and the effect cannot be activated.
##   2. It is an IGNITION effect — activated by its controller in an open game state
##      during a Main Phase, Spell Speed 1, never usable as a response [S1 p.44].
##      Unusually, it may be activated from the HAND as well as from the field, because
##      the clause says "from your hand or field".
##   3. It TARGETS, so the Dragon Normal Monster is fixed at activation. "Dragon Normal
##      Monster" is both halves — a Dragon EFFECT Monster is not a legal target.
##   4. The piercing clause is CONTINUOUS and applies to the EQUIPPED MONSTER, not to
##      this card. The engine already implements and tests piercing itself
##      (`BattleRules.step_damage_calculation`, `RulesQuestionTests`), so this clause only
##      has to point the existing flag at the right monster.
##   5. "If a monster equipped with this card WOULD BE destroyed, destroy this card
##      INSTEAD" is a destruction REPLACEMENT, not a prevention: something is still
##      destroyed, and it is this card. It is asked at the moment the destruction is
##      carried out, so for battle destruction the equipped monster is still determined
##      to be destroyed during damage calculation and battle damage is unaffected.
##      RULES_SPEC.md 17.
##   6. Once it IS equipped, it "remains equipped to that monster and cannot be moved to
##      a different target" [S1 p.53] — enforced generically by `GameState.equip_to()`,
##      which refuses to re-equip an already-equipped card.

const CARD_NAME := "Rider of the Storm Winds"

const CLAUSE_EQUIP := "You can target 1 Dragon Normal Monster you control; equip this " \
	+ "monster from your hand or field to that target."
const CLAUSE_PIERCING := "If a monster equipped with this card attacks a Defense " \
	+ "Position monster, inflict piercing battle damage to your opponent."
const CLAUSE_REPLACEMENT := "If a monster equipped with this card would be destroyed, " \
	+ "destroy this card instead."


func effects() -> Array:
	return [_equip(), _piercing(), _replacement()]


func _equip() -> EffectDef:
	var e := EffectDef.new("equip_self_to_a_dragon_normal_monster", CLAUSE_EQUIP)
	e.of_type(Enums.EffectType.IGNITION)
	e.from_locations([Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_UP])
	e.in_phases([Enums.Phase.MAIN_1, Enums.Phase.MAIN_2])
	e.targeting(1)
	e.ruling("R9")

	var dragon_normal := EffectPrimitives.monster_filter("", -1, -1, "Dragon", true)

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in ctx.me().monsters():
			var card: CardInstance = entry
			# "1 Dragon Normal Monster YOU CONTROL" — a face-down monster's identity is
			# not something a player may act on, so only face-up monsters qualify.
			if card.is_face_up() and dragon_normal.call(card):
				out.append(card)
		return out

	e.condition = func(ctx: EffectContext) -> bool:
		# The Equip Card needs a Spell & Trap Zone to occupy [S1 p.29]. This card is
		# either in the hand or in a Monster Zone at this point, so it always needs one.
		return ctx.me().has_free_spell_trap_zone()

	e.resolve = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equip_source_to_target(ctx)
		if host != null:
			ctx.log_note("equipped itself to %s" % host.card_name())

	return e


func _piercing() -> EffectDef:
	var e := EffectDef.new("equipped_monster_has_piercing", CLAUSE_PIERCING)
	e.of_type(Enums.EffectType.CONTINUOUS)

	e.apply_continuous = func(ctx: EffectContext) -> void:
		var host := EffectPrimitives.equipped_host(ctx)
		if host != null:
			ContinuousEffects.restrict(host, "piercing")

	return e


func _replacement() -> EffectDef:
	var e := EffectDef.new(GameState.DESTRUCTION_REPLACEMENT_EFFECT_ID, CLAUSE_REPLACEMENT)
	e.of_type(Enums.EffectType.CONTINUOUS)

	e.destruction_substitute = func(ctx: EffectContext):
		var victim = ctx.params.get("card", null)
		if victim == null:
			return null
		var host := EffectPrimitives.equipped_host(ctx)
		if host == null or (victim as CardInstance).id != host.id:
			return null
		return ctx.source

	return e
