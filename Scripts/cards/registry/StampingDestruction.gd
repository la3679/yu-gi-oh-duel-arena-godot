extends RefCounted

## Stamping Destruction — Normal Spell.
##
## Official text (verified against the Konami card database, cid 5345; see
## `Data/cards/cards.json`):
##
##   "If you control a Dragon monster: Target 1 Spell/Trap on the field; destroy that
##    target, and if you do, inflict 500 damage to its controller."
##
## Three PSCT regions, and RULES_SPEC.md 10 maps each to a different engine stage:
##
##   * before the colon — "If you control a Dragon monster" is the **activation condition**;
##   * between colon and semicolon — "Target 1 Spell/Trap on the field" is **targeting**,
##     locked in at activation;
##   * after the semicolon — "destroy that target, and if you do, inflict 500 damage to its
##     controller" is **resolution**.
##
## `CARD_RULINGS.md` **R41 Part A**, from the official supplement (cid 5345, 2015-02-12),
## settles the three things that are easy to get wrong, and one of them is the opposite of
## what this engine's usual habit would have produced:
##
##   1. **The Dragon is NOT re-checked at resolution.** 効果処理時に自分フィールドにドラゴン族
##      モンスターが存在しなくなっている場合でも、効果処理は通常通り適用されます — "even if you no
##      longer control a Dragon monster at resolution, the effect is applied as normal".
##      Tributing the Dragon in response does **not** stop this card. Design decision 16 says a
##      TARGET is re-checked; it does not say an activation condition is, and here the official
##      answer is explicit.
##   2. **"and if you do" makes the damage strictly conditional on the destruction.** A target
##      that could not be destroyed — protected by `Gagagashield`'s counted prevention, or gone
##      from the field by resolution — inflicts **no damage at all**. This is the load-bearing
##      branch of the card.
##   3. **The destruction and the damage are treated as simultaneous.** Nothing in the V1 pool
##      can observe a window between them, so this is recorded rather than modelled: one
##      resolution, no `ctx.ask()`, no intervening Chain.
##
## Two more details this implementation encodes:
##
##   * **"its controller" is read BEFORE the destruction.** Once the card is in the Graveyard it
##     is controlled by nobody, and the text names the controller of the card that was
##     destroyed — which is not necessarily the opponent, because the target may be your own.
##   * **"1 Spell/Trap on the field" is EITHER player's, and face-down Set cards are legal.**
##     The text names no property a face-down card lacks, exactly as `Phoenix Wing Wind Blast`
##     does not. Deliberately destroying your own Set card to burn yourself is legal and is
##     asserted, because refusing it would be a rule this card does not print.
##
## **It cannot target itself.** A Normal Spell activated from the hand occupies a Spell & Trap
## Zone from the moment of activation, so it really is "1 Spell/Trap on the field" while its own
## targets are chosen. `CARD_RULINGS.md` **R41 Part G** implements this as NO, at MEDIUM
## confidence and explicitly as reasoned-from-precedent rather than an official ruling: R28
## already decided the non-targeting form of the same question for `A Wingbeat of Giant Dragon`,
## and the published `Mystical Space Typhoon` rulings — the identical clause — say the same.
##
## A **Trap Monster** is the one target that can stop being a legal target without leaving the
## field. `The Phantom Knights of Shadow Veil`, Set in a Spell & Trap Zone, is a legal target;
## if it Special Summons itself into a Monster Zone in response it is a monster and no longer a
## Spell/Trap, and this card drops it. RULES_SPEC.md 5.8. That is why the resolution re-check
## asks the same predicate the target list did, and not merely `is_on_field()`.

const CARD_NAME := "Stamping Destruction"

const CLAUSE := "If you control a Dragon monster: Target 1 Spell/Trap on the field; " \
	+ "destroy that target, and if you do, inflict 500 damage to its controller."

const REQUIRED_RACE := "Dragon"
const DAMAGE := 500


## "1 Spell/Trap on the field" — a card sitting in a Spell & Trap Zone or the Field Zone.
##
## Asked by the ZONE rather than by `is_spell() or is_trap()`, and the difference is real: a
## Trap Monster in a Monster Zone is on the field and is printed as a Trap, but it is not a
## Spell/Trap **on the field** in the sense this clause means — RULES_SPEC.md 5.8 and the same
## distinction `Straight Flush`'s official supplement draws. Reading the zone also makes a
## face-down Set card legal without asking it anything it does not present.
static func _is_spell_trap_on_field(card: CardInstance) -> bool:
	if card == null or card.definition == null:
		return false
	return card.zone == Enums.Zone.SPELL_TRAP_ZONE or card.zone == Enums.Zone.FIELD_ZONE


func effects() -> Array:
	var e := EffectDef.new("destroy_spell_trap_and_burn", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.targeting(1)
	e.ruling("R41")

	# "a Dragon monster" is matched on the RACE, never on the name — the same reading
	# `Divine Dragon Apocralyph` uses, and for the same reason: deck 1 holds `Ranryu`,
	# `Kaiser Glider`, `Flamvell Guard` and `The White Stone of Legend`, none of which a name
	# test would match. Face-down monsters are excluded: Type is a property a face-down
	# monster does not present, which is how `A Wingbeat of Giant Dragon` and
	# `Champion's Vigilance` already read the same shape of clause.
	var dragon := EffectPrimitives.monster_filter("", -1, -1, REQUIRED_RACE)

	e.condition = func(ctx: EffectContext) -> bool:
		for entry in ctx.me().face_up_monsters():
			if dragon.call(entry as CardInstance):
				return true
		return false

	e.legal_targets = func(ctx: EffectContext) -> Array:
		var out: Array = []
		for entry in EffectPrimitives.cards_on_field(ctx):
			var card: CardInstance = entry
			# R41 Part G — it is never among its own targets.
			if card == ctx.source:
				continue
			if _is_spell_trap_on_field(card):
				out.append(card)
		return out

	e.resolve = func(ctx: EffectContext) -> void:
		var target := EffectPrimitives.surviving_field_target(ctx)
		if target == null or not _is_spell_trap_on_field(target):
			ctx.log_note("the target is no longer a Spell/Trap on the field")
			return
		# Read the controller BEFORE the destruction: a destroyed card is in a Graveyard and
		# is controlled by nobody.
		var controller_id := target.controller_id
		var target_name := target.card_name()
		if not ctx.state.destroy(target, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id):
			# "and if you do" — the destruction did not happen, so nothing else does.
			ctx.log_note("%s could not be destroyed; no damage is inflicted" % target_name)
			return
		ctx.state.change_life_points(controller_id, -DAMAGE, CARD_NAME, ctx.source.id)
		# Effect damage can end the Duel, and `change_life_points()` deliberately does not
		# decide that.
		ctx.state.check_life_point_loss()
		ctx.log_note("destroyed %s and inflicted %d damage on its controller"
			% [target_name, DAMAGE])

	return [e]
