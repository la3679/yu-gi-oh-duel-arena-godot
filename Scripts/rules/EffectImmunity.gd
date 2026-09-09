class_name EffectImmunity
extends RefCounted

## "…it is unaffected by the effects of cards other than this card."
## RULES_SPEC.md 18, CARD_RULINGS.md R12.
##
## The generic gate for a monster that does not RECEIVE other cards' effects. It was written
## before `The Monarchs Awaken` existed and it names no card: the exempt source is passed in,
## so a future card worded "other than itself", or with no exemption at all, uses the same
## subsystem with a different exempt id.
##
## ---------------------------------------------------------------------------
## What "unaffected" means, and what it does NOT mean
## ---------------------------------------------------------------------------
##
## Taken from official Konami Q&A, not from the English phrase, which is much broader than
## the rule (CARD_RULINGS.md R12 Part B; the decisive entry is fid 13065, which answers the
## question on the very same card wording).
##
## **An effect applies to a card at a definite MOMENT. If the card is immune at that moment,
## that one application does not happen. Nothing else about the effect changes.**
##
## So the effect is still activated, still targets this card, still resolves, and every part
## of it that applies to some OTHER card still applies. Only the individual sub-process
## aimed at the immune card is skipped. One effect can therefore half-apply, and does:
## fid 13065 has an effect whose ATK-copy applies and whose ATK-zeroing does not.
##
## Blocked (each is an effect being applied to the card):
##   destruction by a card effect · being moved by an effect (bounce / banish / send to GY)
##   · a control change · an ATK or DEF modifier · having its effects negated · having a
##   restriction flag set on it · having a protection or benefit granted to it · having
##   counters put on or taken off it by an effect.
##
## NOT blocked, and each one is a deliberate hole with a source behind it:
##   * **targeting / selection** — fid 13065. That is `cannot_be_targeted()`, a different
##     flag with a different owner. Do not route targeting through this file.
##   * **activation and resolution** of the effect — fid 13065, fid 17304.
##   * **costs, and Tributes for a Summon procedure** — fid 298: "it is not treated as an
##     effect applied to the opponent's monster". The engine already keeps cost primitives
##     and effect primitives apart (batch 4); this gate goes only on the effect side.
##   * **battle** — fid 18199. An immune monster is destroyed by battle as normal.
##   * **the game rules** — a source id of -1 is never blocked.
##   * **an application that already COMPLETED** before the immunity began — fid 13085,
##     fid 16491. Nothing is undone retroactively. This falls out of the design rather than
##     being coded: continuous effects are re-applied on every recompute and so are gated,
##     while an obligation recorded once on the instance or in a lease is never re-applied
##     and so is never asked.
##
## **The immunity is a shield, not a blessing.** It refuses helpful effects too: fid 18199
## has an immune monster destroyed by battle precisely because it did not receive the
## "cannot be destroyed by battle" its opponent's card was handing out.
##
## ---------------------------------------------------------------------------
## Why the state lives on CardInstance and not in ContinuousEffects
## ---------------------------------------------------------------------------
##
## The official duration is "as long as it exists face-up in the Monster Zone" — a statement
## about the MONSTER, with no condition on the source at all, and `The Monarchs Awaken` is a
## Normal Trap that is already in the Graveyard when the state starts mattering
## (CARD_RULINGS.md R12 Part D/E). A `ContinuousEffects` restriction flag is wiped and
## rebuilt from the board on every recompute, so it would switch off the instant the Trap
## resolved. `CardInstance.unaffected_by_effects` is therefore a plain per-instance field,
## cleared by exactly the two things the ruling names: `on_leave_field()` and
## `on_flipped_face_down()`.


## Grant the immunity to `card`, exempting `source`.
##
## Returns false and writes nothing when the card is not face-up on the field. That is the
## resolution-time gate the supplement states outright — "if, at resolution, the target
## monster is face-down Defense Position, … the 'unaffected by the effects of cards other
## than this card' effect is not applied" (R12 Part E) — and it is enforced here rather than
## in the card so that every future card with this wording inherits it.
static func grant(card: CardInstance, source: CardInstance) -> bool:
	if card == null:
		return false
	if not card.is_on_field() or not card.is_face_up():
		return false
	card.unaffected_by_effects = true
	if source != null and not card.unaffected_exempt_source_ids.has(source.id):
		card.unaffected_exempt_source_ids.append(source.id)
	return true


## Is an effect sourced at instance `source_id` blocked from applying to `card`?
##
## The one predicate every gated call site asks. `source_id` -1 means the game rules, which
## are never blocked.
static func blocks(card: CardInstance, source_id: int) -> bool:
	if card == null:
		return false
	return card.is_unaffected_by_effect_of(source_id)


## The same question asked from a resolving effect, which knows its source as a card.
static func blocks_source(card: CardInstance, source: CardInstance) -> bool:
	if source == null:
		return false
	return blocks(card, source.id)


## The same question asked from an EffectContext. Card scripts should prefer this: it reads
## the source off the context so a clause cannot accidentally pass the wrong card and
## silently exempt itself.
static func blocks_ctx(ctx, card: CardInstance) -> bool:
	if ctx == null or ctx.source == null:
		return false
	return blocks(card, ctx.source.id)
