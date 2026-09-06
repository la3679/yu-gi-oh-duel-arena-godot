extends RefCounted

## Straight Flush — Normal Trap.
##
## Official text (verified against the Konami card database, cid 6911; see
## `Data/cards/cards.json`):
##
##   "If your opponent controls a card in each of their Spell & Trap Zones: Destroy all
##    cards in their Spell & Trap Zones."
##
## Two PSCT regions, no semicolon and no "target": everything before the colon is the
## **activation condition**, everything after it is **resolution**, and nothing at all happens
## at activation. RULES_SPEC.md 10.
##
## The whole card is one question asked twice with two different answers — *what is a card in
## a Spell & Trap Zone?* — and `CARD_RULINGS.md` **R41 Part B**, from the official supplement
## (cid 6911, 2015-02-05), settles every case this pool can reach:
##
##   1. **It does not target.** 対象を取る効果ではありません. So the set of cards destroyed is
##      whatever is in those zones at RESOLUTION, not a list fixed at activation.
##   2. **It is illegal in the Damage Step.** ダメージステップに発動する事はできません — which is
##      the engine default (`DamageStepPermission.NONE`), so this is asserted rather than
##      implemented.
##   3. **An Equip Card equipped to a monster IS a card in a Spell & Trap Zone.** It fills one
##      of the five for the condition and is destroyed by the resolution. `GameState.equip_to()`
##      already puts every Equip Card in a Spell & Trap Zone, so this needs no special code —
##      but `Gagagashield`, `Kunai with Chain` and `Castle of Dragon Souls` are all in the pool,
##      so it is live and is asserted.
##   4. **A Trap Monster in a Monster Zone is NOT.** 自身の効果によってモンスターゾーンに存在する
##      「アポピスの化神」は魔法＆罠ゾーンに存在するカードではありません — and the supplement adds,
##      in as many words, that `Straight Flush` then **cannot be activated at all**. This is
##      RULES_SPEC.md 5.8's "one Monster Zone, no Spell & Trap Zone" observed from outside, and
##      `The Phantom Knights of Shadow Veil` is the pool's card that does it.
##
## **The Field Zone is not a Spell & Trap Zone**, in either half. It is not counted by the
## condition and it is not destroyed by the resolution. That distinction is **live**: deck 2
## holds `Hidden Springs of the Far East`, a Field Spell. Note that the sister card
## `Stamping Destruction` says "on the field" instead and therefore **does** reach the Field
## Zone — the two cards print different words and behave differently, which is the point.
##
## **The condition is not re-checked at resolution.** It is before the colon, so it gates the
## activation and nothing else (RULES_SPEC.md 10); a card that leaves one of those zones in
## response does not stop the card, and the four that remain are still destroyed. That is the
## same reading `Stamping Destruction`'s supplement states outright for its own condition.
##
## Nothing here reaches the controller's own Spell & Trap Zones, so this card can never destroy
## itself: it is Set in its OWN controller's zone while it resolves.

const CARD_NAME := "Straight Flush"

const CLAUSE := "If your opponent controls a card in each of their Spell & Trap Zones: " \
	+ "Destroy all cards in their Spell & Trap Zones."


## Every card currently sitting in `pid`'s five Spell & Trap Zones.
##
## Deliberately `PlayerState.spell_traps()` rather than `controlled_cards()`: that one also
## returns the Monster Zones and the **Field Zone**, and this clause names neither.
static func _spell_trap_zone_cards(state: GameState, pid: int) -> Array:
	return state.player(pid).spell_traps()


func effects() -> Array:
	var e := EffectDef.new("destroy_all_opponent_spell_trap_zones", CLAUSE)
	e.of_type(Enums.EffectType.CARD_ACTIVATION)
	# A Normal Trap is Spell Speed 2 [S1 p.44-45]; `of_type()` cannot derive it.
	e.with_spell_speed(Enums.SpellSpeed.SS2)
	e.activation_locations = [Enums.ActivationLocation.FIELD_FACE_DOWN]
	e.ruling("R41")

	e.condition = func(ctx: EffectContext) -> bool:
		# "a card in EACH of their Spell & Trap Zones" — every one of the five is occupied.
		# Counting cards would be wrong the moment a Trap Monster leaves one of them empty
		# while still being a card the opponent controls.
		return _spell_trap_zone_cards(ctx.state, ctx.opponent_id()).size() \
			== PlayerState.SPELL_TRAP_ZONE_COUNT

	e.resolve = func(ctx: EffectContext) -> void:
		# Snapshot before destroying anything: destroying one card can move another (a
		# destruction REPLACEMENT can redirect), and iterating a live zone array while it is
		# being emptied is not safe.
		var doomed := _spell_trap_zone_cards(ctx.state, ctx.opponent_id())
		var destroyed := 0
		for entry in doomed:
			var card: CardInstance = entry
			if card == null or card.zone != Enums.Zone.SPELL_TRAP_ZONE:
				continue
			if ctx.state.destroy(card, Enums.MoveReason.DESTROYED_BY_EFFECT, ctx.source.id):
				destroyed += 1
		ctx.log_note("destroyed %d card(s) from the opponent's Spell & Trap Zones" % destroyed)

	return [e]
