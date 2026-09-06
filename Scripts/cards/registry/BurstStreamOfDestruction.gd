extends RefCounted

## Burst Stream of Destruction — Normal Spell.
##
## Official text (verified against the Konami card database, cid 5979; see
## `Data/cards/cards.json`):
##
##   "If you control 'Blue-Eyes White Dragon': Destroy all monsters your opponent controls.
##    'Blue-Eyes White Dragon' you control cannot attack the turn you activate this card."
##
## **Two clauses with two different lifetimes**, and the second one is why this card needed
## the only piece of new engine surface in batch 11.
##
## The official supplement (cid 5979, 2024-09-07) is the reason this card is not what its
## printed English text alone suggests. `CARD_RULINGS.md` **R41 Part C** records all four
## points; three of them would otherwise have been silent bugs:
##
##   1. **It is also an ACTIVATION RESTRICTION, backwards in time.**
##      既に「青眼の白龍」が１体でも攻撃を行っているターンには、このカードを発動できません — you
##      cannot activate it on a turn in which a `Blue-Eyes White Dragon` has **already**
##      attacked. Nothing in the printed English says this; it is derived from the lingering
##      sentence, and without it the card would be a free "attack, then wipe the board".
##   2. **The ban covers EVERY copy**, 全ての「青眼の白龍」, including one Summoned **later that
##      same turn** — `Kaibaman` and `Silver's Cry` both do exactly that in this deck. So it
##      cannot be a flag written onto the monsters that happened to be present; it is a
##      turn-scoped ban keyed by card NAME (RULES_SPEC.md 6.5).
##   3. **It attaches at ACTIVATION**, 実際に処理が行われたかどうかにかかわらず — "regardless of
##      whether the effect was actually carried out". So negating the EFFECT does not lift it.
##   4. **Negating the ACTIVATION does lift it**: 「青眼の白龍」が攻撃できる状態に戻ります.
##
## Points 3 and 4 together are exactly the existing
## `ActivationRules.ACTIVATION_CONDITION_EFFECT_ID` + `EffectDef.activation_confirmed` channel
## built for R39 and used by `Soul Exchange`: it fires only when `not link.activation_negated`,
## and it fires whether or not the effect resolved. **No new timing channel was needed** — only
## somewhere for the ban itself to live, because §6.4's two prevention channels are both
## continuous and this card is in the Graveyard before the first attack it forbids.
##
## Firing it as the Chain Link is processed rather than at the literal instant of activation is
## unobservable: no attack can be declared while a Chain is unresolved.
##
## **The `Blue-Eyes White Dragon` must be FACE-UP** — 自分フィールドに表側表示の「青眼の白龍」が
## 存在する場合. The supplement adds that a face-up copy in your **Spell & Trap Zone** would also
## satisfy it; nothing in the V1 pool can put a monster face-up in a Spell & Trap Zone, so that
## branch is **never live** and is asserted as unreachable rather than implemented as a branch
## that can never run — the R21 / R23 treatment.
##
## **The condition is not re-checked at resolution.** It is before the colon (RULES_SPEC.md 10),
## and `Stamping Destruction`'s own supplement states the general reading outright. Losing the
## `Blue-Eyes White Dragon` in response does not stop the board wipe.
##
## "All monsters your opponent controls" is non-targeting and includes **face-down** monsters:
## the clause names no property a face-down monster does not present.

const CARD_NAME := "Burst Stream of Destruction"
const BLUE_EYES := "Blue-Eyes White Dragon"

const CLAUSE_DESTROY := "If you control \"Blue-Eyes White Dragon\": Destroy all monsters " \
	+ "your opponent controls."
const CLAUSE_CANNOT_ATTACK := "\"Blue-Eyes White Dragon\" you control cannot attack the " \
	+ "turn you activate this card."


func effects() -> Array:
	return [_destroy(), _cannot_attack()]


func _destroy() -> EffectDef:
	var e := EffectDef.new("destroy_all_opponent_monsters", CLAUSE_DESTROY)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	e.activation_locations = [Enums.ActivationLocation.HAND,
		Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R41")

	e.condition = func(ctx: EffectContext) -> bool:
		# "a face-up 'Blue-Eyes White Dragon' on your field". Matched on the canonical card
		# NAME, never on text, and read from the Monster Zones only — the supplement's
		# Spell & Trap Zone case cannot arise in this pool.
		for entry in ctx.me().face_up_monsters():
			if (entry as CardInstance).card_name() == BLUE_EYES:
				return true
		return false

	e.resolve = func(ctx: EffectContext) -> void:
		# Snapshot before destroying anything: a destruction REPLACEMENT can redirect, and
		# iterating a live zone array while it is being emptied is not safe.
		var doomed := ctx.opponent().monsters()
		var destroyed := 0
		for entry in doomed:
			var card: CardInstance = entry
			if card == null or card.zone != Enums.Zone.MONSTER_ZONE:
				continue
			if ctx.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id):
				destroyed += 1
		ctx.log_note("destroyed %d monster(s) the opponent controlled" % destroyed)

	return e


## The lingering sentence, as an ACTIVATION-CONDITION clause rather than a resolving one.
##
## `condition` is the half the printed English does not say and cid 5979 does; the ban itself
## is applied by `activation_confirmed`, which the rules layer runs for a confirmed CARD
## activation whose ACTIVATION was not negated. R39 / RULES_SPEC.md 5.9 and 6.5.
func _cannot_attack() -> EffectDef:
	var e := EffectDef.new(ActivationRules.ACTIVATION_CONDITION_EFFECT_ID,
		CLAUSE_CANNOT_ATTACK)
	e.of_type(Enums.EffectType.CONTINUOUS)
	e.ruling("R41")

	e.condition = func(ctx: EffectContext) -> bool:
		return not EffectPrimitives.named_monster_attacked_this_turn(ctx, BLUE_EYES,
			ctx.controller_id)

	e.activation_confirmed = func(ctx: EffectContext) -> void:
		ctx.me().ban_attacks_by_name(BLUE_EYES, ctx.state.turn_number)

	return e
