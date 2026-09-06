extends RefCounted

## Vampiric Koala — EARTH / Beast / Level 4 / 1800 ATK / 1500 DEF.
##
## Official text (verified against the Konami card database, cid 8858; see
## `Data/cards/cards.json`):
##
##   "If this card inflicts battle damage to your opponent by battle with a monster:
##    Gain LP equal to the battle damage inflicted."
##
## The official supplement (cid 8858, 2017-01-12) is short and settles everything;
## `CARD_RULINGS.md` **R41 Part F** records it:
##
##   ■「吸血コアラ」のモンスター効果は誘発効果です — a **TRIGGER** Effect.
##   ■対象を取る効果ではありません — it does **not** target.
##   ■「吸血コアラ」自身がモンスターと戦闘を行い、その戦闘で相手に戦闘ダメージを与えたダメージ計算後に
##     **必ず**発動する効果です — it activates **after damage calculation** of a battle in which
##     **this card itself** fought **a monster** and the **opponent** took battle damage, and
##     it is **MANDATORY**.
##
## **The subject is 自身 — "this card itself battles" — and NOT "when this card attacks".**
## That is the half the English text makes easy to miss, and it is the reason this card is a
## defensive threat as well as an offensive one:
##
## | Situation | Triggers? |
## |---|---|
## | Koala attacks a weaker Attack Position monster | **yes** |
## | Koala, in Attack Position, is attacked by a weaker monster | **yes** — the attacker's controller takes it |
## | Koala, in Defense Position, is attacked by a monster with less ATK than Koala's DEF | **yes** |
## | Koala attacks **directly** | **no** — 「モンスターとの戦闘」, a battle *with a monster* |
## | Koala attacks a Defense Position monster and no damage is inflicted | **no** |
## | Koala battles and **its own** controller takes the damage | **no** |
##
## Three implementation decisions follow from that, and none of them invents machinery:
##
##   1. **"This card itself battled a monster" is asked of the live battle**, through the
##      existing `EffectPrimitives.battle_opponent_of()`, which is null for a direct attack
##      and null for a card that is neither the attacker nor the defender. It reads
##      `GameState.current_attacker` / `current_attack_target`, which stay set from attack
##      declaration until `BattleRules.clear_battle()` — so they are live through sub-step 4,
##      which is where this trigger is collected. The event's own `direct` flag would be a
##      second, weaker way to ask the same question, so it is not asked twice.
##   2. **"To your opponent" is read from the event**, whose `player` field names who lost the
##      LP. That is the only thing in this clause that the live battle state does not already
##      say more directly.
##   3. **The amount is the damage that was actually dealt**, taken from `BattleRules`'
##      authoritative record via `battle_damage_just_inflicted_on()` — never recomputed from
##      ATK values, which a modifier applied inside the Damage Step would make disagree.
##
## **"After damage calculation" is Damage Step sub-step 4**, so the clause declares
## `DamageStepPermission.MANDATORY_TRIGGER` (RULES_SPEC.md 7.2). Without it a mandatory effect
## the rules require to happen inside the Damage Step would never be collected at all.
##
## Nothing here is a card-specific battle resolver: the whole battle goes through the ordinary
## pipeline and this clause only reads what that pipeline recorded.

const CARD_NAME := "Vampiric Koala"

const CLAUSE := "If this card inflicts battle damage to your opponent by battle with a " \
	+ "monster: Gain LP equal to the battle damage inflicted."


func effects() -> Array:
	var e := EffectDef.new("gain_lp_equal_to_battle_damage", CLAUSE)
	e.of_type(Enums.EffectType.TRIGGER)
	# 必ず発動する — mandatory. The controller is never asked whether to use it.
	e.mandatory()
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_UP]
	e.trigger_events = [GameEvent.Kind.BATTLE_DAMAGE_INFLICTED]
	e.damage_step(Enums.DamageStepPermission.MANDATORY_TRIGGER)
	e.ruling("R41")

	e.condition = func(ctx: EffectContext) -> bool:
		var ev: GameEvent = ctx.trigger_event
		if ev == null or ev.kind != GameEvent.Kind.BATTLE_DAMAGE_INFLICTED:
			return false
		# "to your OPPONENT" — a battle in which this card's own controller took the damage
		# does not trigger it.
		if int(ev.data.get("player", -1)) != ctx.opponent_id():
			return false
		if int(ev.data.get("amount", 0)) <= 0:
			return false
		# "THIS CARD, by battle WITH A MONSTER" — both halves in one question. Null for a
		# direct attack, and null for damage from a battle this card was not part of.
		return EffectPrimitives.battle_opponent_of(ctx.state, ctx.source) != null

	e.resolve = func(ctx: EffectContext) -> void:
		var amount := EffectPrimitives.battle_damage_just_inflicted_on(ctx, ctx.opponent_id())
		if amount <= 0:
			ctx.log_note("no battle damage was inflicted on the opponent")
			return
		ctx.state.change_life_points(ctx.controller_id, amount, CARD_NAME, ctx.source.id)
		ctx.log_note("gained %d LP, equal to the battle damage inflicted" % amount)

	return [e]
