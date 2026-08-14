class_name BanishTests
extends RefCounted

## BANISHMENT and TEMPORARY REMOVAL. Rules under test: `RULES_SPEC.md §8`, `§8.3`, `§12`,
## `§15` [S1 p.52–53].
##
## This is the **banish gate**, written the way `EquipTests`, `ControlTests` and
## `MovementTests` were: a RULES suite built from synthetic cards, so what it proves is that
## the ENGINE is right rather than that one printed card happens to work. The batch-8 cards
## (`Interdimensional Matter Transporter`, `Judge of the Ice Barrier`, `Junk Blader`,
## `The Phantom Knights of Shadow Veil`, `Runick Flashing Fire`) are only implemented once it
## passes.
##
## Two load-bearing claims.
##
## **First: banishing is not one untyped movement call.** These differ in when they happen,
## what they can be undone by, what the players may know, and which clauses can reach the
## card afterwards, and every difference is asserted below in both directions:
##
##   banish as a COST · banish as an EFFECT · from the field · from the Graveyard ·
##   from the hand · from the Deck · the top N of a Deck · face-up · face-down ·
##   TEMPORARY, with a stated return
##
## **Second: a temporary banishment is a LEASE**, the same shape as a control change, held by
## `GameState.banish_leases` and expired by `GameState.expire_banish_leases()` at exactly the
## two cadences `expire_control_leases()` runs at. The authoritative state knows which card is
## away, what banished it, when it is due, where it goes and what happens if it cannot get
## there — none of that lives in a card script. RULES_SPEC.md 8.3, CARD_RULINGS.md R30.
##
## And a banished card is **not** destroyed, **not** sent to the Graveyard, and — on the way
## back — **not** Summoned.


static func run() -> TestCase:
	var t := TestCase.new("BanishTests")
	# The distinctions the subsystem exists for
	_test_banishing_is_not_destruction_and_not_a_send_to_gy(t)
	_test_cost_and_effect_are_two_different_moments(t)
	_test_a_cost_is_all_or_nothing_and_is_not_refunded_by_negation(t)
	# Source zones
	_test_banishing_from_every_source_zone(t)
	_test_banishing_the_top_n_of_a_deck(t)
	_test_top_of_deck_banish_with_a_short_deck(t)
	_test_top_of_deck_banish_is_not_an_excavate_a_draw_or_a_mill(t)
	# Owner, controller, face
	_test_a_banished_card_goes_to_its_OWNERS_banished_zone(t)
	_test_face_up_and_face_down_banishment_are_different(t)
	# What leaving the field cleans up
	_test_banishing_from_the_field_cleans_up_every_relationship(t)
	# Temporary removal — the lease
	_test_a_temporary_banish_registers_a_lease_and_a_permanent_one_does_not(t)
	_test_the_return_happens_when_the_end_phase_is_entered(t)
	_test_the_return_is_not_a_summon(t)
	_test_the_return_position_is_the_one_it_left_in(t)
	_test_the_card_returns_under_its_OWNERS_control(t)
	_test_nothing_comes_back_when_the_monster_zone_is_full(t)
	_test_a_card_moved_out_of_banishment_never_returns(t)
	_test_a_return_never_happens_twice(t)
	_test_a_temporary_banish_comes_back_stateless(t)
	# Determinism
	_test_the_whole_cycle_is_replay_deterministic(t)
	return t


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _duel(seed_value: int) -> Dictionary:
	var d := TestFixtures.new_duel(seed_value, 0)
	TestFixtures.advance_to_phase(d["engine"], Enums.Phase.MAIN_1)
	return d


## A bare EffectContext for driving an `EffectPrimitives` banish helper directly, exactly as
## `MovementTests._ctx()` does for the movement helpers. No engine is attached: none of the
## banish primitives needs one, and proving that is part of the point.
static func _ctx(engine: DuelEngine, source: CardInstance,
		targets: Array = []) -> EffectContext:
	var effect := EffectDef.new("test_banish", "Test: banish a card.")
	var ctx := EffectContext.new(engine.state, source, effect)
	ctx.controller_id = source.controller_id
	for entry in targets:
		var card: CardInstance = entry
		ctx.chosen_target_ids.append(card.id)
	return ctx


static func _banished_ids(engine: DuelEngine, pid: int) -> Array:
	var out: Array = []
	for entry in engine.state.player(pid).banished:
		var c: CardInstance = entry
		out.append(c.id)
	return out


# ---------------------------------------------------------------------------
# The distinctions the subsystem exists for. RULES_SPEC.md 8 [S1 p.52-53].
# ---------------------------------------------------------------------------

static func _test_banishing_is_not_destruction_and_not_a_send_to_gy(t: TestCase) -> void:
	t.start("banishing emits CARD_BANISHED only — it is neither a destruction nor a send "
		+ "to the Graveyard [S1 p.53]")
	var d := _duel(9601)
	var engine: DuelEngine = d["engine"]
	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Victim", 4, 1200, 1000))

	var before_destroyed := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED)
	var before_gy := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)
	var before_banished := TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED)

	engine.state.move_card(monster, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)

	t.eq(monster.zone, Enums.Zone.BANISHED, "the card is in the Banished zone")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED),
		before_banished + 1, "exactly one CARD_BANISHED was emitted")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DESTROYED),
		before_destroyed, "no destruction event — banishing is not destroying [S1 p.53]")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY),
		before_gy, "and no send-to-GY event either")
	t.eq(monster.last_move_reason, Enums.MoveReason.BANISHED,
		"the recorded reason is BANISHED, so a trigger keyed on the reason can tell")

	# The other half of the same rule: a banished card LATER moved to the Graveyard is not
	# "sent to the Graveyard" from the field, because it was not on the field.
	var gy_before := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)
	engine.state.move_card(monster, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), gy_before,
		"a banished card moved to the GY is still not 'sent to the GY' [S1 p.53]")


static func _test_cost_and_effect_are_two_different_moments(t: TestCase) -> void:
	t.start("banish as a COST and banish as an EFFECT are two primitives and happen at two "
		+ "different moments — they are not one call with a flag")
	var d := _duel(9602)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var fodder := TestFixtures.give(engine, 0, TestFixtures.monster("Fodder"),
		Enums.Zone.GRAVEYARD)
	var target := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Their Monster"))

	# COST: paid from an explicit candidate list, and the payment is reported back so the
	# resolution can read what it paid (the batch-4 cost_payload channel).
	var cost_ctx := _ctx(engine, source)
	var paid := EffectPrimitives.pay_banish_cost(cost_ctx, [fodder], 1, "Banish 1")
	t.eq(paid.size(), 1, "the cost banished exactly one card")
	t.eq(fodder.zone, Enums.Zone.BANISHED, "and that card is banished")

	# EFFECT: re-checks the target at resolution and reaches it through the target list.
	var effect_ctx := _ctx(engine, source, [target])
	var banished := EffectPrimitives.banish_target(effect_ctx, Enums.Zone.MONSTER_ZONE)
	t.eq(banished, target, "the effect banished its target")
	t.eq(target.zone, Enums.Zone.BANISHED, "which is now in the Banished zone")

	# The distinction that matters: the EFFECT re-checks and the COST does not, because a
	# cost is paid at activation when the card is known to be there.
	var gone := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Leaves First"))
	var late_ctx := _ctx(engine, source, [gone])
	engine.state.move_card(gone, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.is_null(EffectPrimitives.banish_target(late_ctx, Enums.Zone.MONSTER_ZONE),
		"a target that left the field before resolution is not chased into the GY")
	t.eq(gone.zone, Enums.Zone.GRAVEYARD, "and is left exactly where it went")


static func _test_a_cost_is_all_or_nothing_and_is_not_refunded_by_negation(
		t: TestCase) -> void:
	t.start("a banish cost is all-or-nothing, and a negated effect does not refund it")
	var d := _duel(9603)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var one := TestFixtures.give(engine, 0, TestFixtures.monster("One"),
		Enums.Zone.GRAVEYARD)

	# Asking for two when only one is available pays nothing at all.
	var ctx := _ctx(engine, source)
	var paid := EffectPrimitives.pay_banish_cost(ctx, [one], 2, "Banish 2")
	t.eq(paid.size(), 0, "an unpayable cost pays nothing")
	t.eq(one.zone, Enums.Zone.GRAVEYARD, "and the one available card was not banished")

	# A cost that IS paid stays paid. Nothing in the engine reverses a cost, and this asserts
	# it rather than assuming it: the card is still banished after the source is destroyed.
	var paid2 := EffectPrimitives.pay_banish_cost(_ctx(engine, source), [one], 1, "Banish 1")
	t.eq(paid2.size(), 1, "the payable cost was paid")
	engine.state.move_card(source, Enums.Zone.GRAVEYARD,
		Enums.MoveReason.DESTROYED_BY_EFFECT)
	t.eq(one.zone, Enums.Zone.BANISHED,
		"the cost is not refunded when the source is destroyed — a paid cost stays paid")


# ---------------------------------------------------------------------------
# Source zones. A banish from each is a different clause, not one call.
# ---------------------------------------------------------------------------

static func _test_banishing_from_every_source_zone(t: TestCase) -> void:
	t.start("a card can be banished from the field, the Graveyard, the hand and the Deck, "
		+ "and each records the zone it came FROM")
	var d := _duel(9604)
	var engine: DuelEngine = d["engine"]
	var from_field := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("From Field"))
	var from_gy := TestFixtures.give(engine, 0, TestFixtures.monster("From GY"),
		Enums.Zone.GRAVEYARD)
	var from_hand := TestFixtures.give_to_hand(engine, 0,
		TestFixtures.monster("From Hand"))
	var from_deck: CardInstance = engine.state.player(0).deck[0]

	for entry in [from_field, from_gy, from_hand, from_deck]:
		var card: CardInstance = entry
		var origin := card.zone
		t.check(engine.state.move_card(card, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED),
			"banished %s" % card.card_name())
		t.eq(card.zone, Enums.Zone.BANISHED, "%s is banished" % card.card_name())
		t.eq(card.last_move_from_zone, origin,
			"%s records the zone it was banished FROM" % card.card_name())

	t.eq(engine.state.player(0).banished.size(), 4, "all four are in the Banished zone")
	# The one that came from the field is the only one that left the field, so it is the only
	# one whose per-instance state was reset. RULES_SPEC.md 15.
	t.eq(from_field.last_move_from_zone, Enums.Zone.MONSTER_ZONE,
		"and only one of them came from a field zone")


static func _test_banishing_the_top_n_of_a_deck(t: TestCase) -> void:
	t.start("banish the top N of a Deck takes exactly N, from the top, in a deterministic "
		+ "order, and does not touch the rest of the Deck")
	var d := _duel(9605)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.spell("Source"))
	var deck: Array = engine.state.player(1).deck
	var size_before := deck.size()
	var top_two := [deck[0], deck[1]]
	var third: CardInstance = deck[2]

	var banished := EffectPrimitives.banish_top_of_deck(_ctx(engine, source), 1, 2)

	t.eq(banished.size(), 2, "exactly 2 cards were banished")
	t.eq(banished[0], top_two[0], "the first one banished was the top card")
	t.eq(banished[1], top_two[1], "the second one was the card below it — a fixed order")
	t.eq(engine.state.player(1).deck.size(), size_before - 2, "the Deck lost exactly 2")
	t.eq(engine.state.player(1).deck[0], third, "and what was third is now on top")
	for entry in banished:
		var c: CardInstance = entry
		t.eq(c.zone, Enums.Zone.BANISHED, "%s is banished" % c.card_name())
		t.eq(c.owner_id, 1, "and belongs to the Deck's owner, not to the effect's controller")
		t.eq(c.last_move_from_zone, Enums.Zone.DECK, "having come from the Deck")


static func _test_top_of_deck_banish_with_a_short_deck(t: TestCase) -> void:
	t.start("banishing the top N of a Deck holding fewer than N banishes what is there, and "
		+ "does NOT deck the player out — decking out is a failure to DRAW [S1 p.35]")
	var d := _duel(9606)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.spell("Source"))
	var deck: Array = engine.state.player(1).deck
	while deck.size() > 1:
		engine.state.move_card(deck[deck.size() - 1], Enums.Zone.GRAVEYARD,
			Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(engine.state.player(1).deck.size(), 1, "the opponent's Deck holds exactly 1 card")

	var banished := EffectPrimitives.banish_top_of_deck(_ctx(engine, source), 1, 2)
	t.eq(banished.size(), 1, "only the one available card was banished")
	t.eq(engine.state.player(1).deck.size(), 0, "the Deck is now empty")
	t.check(not engine.state.is_duel_over(),
		"and an empty Deck is not, by itself, a loss — only a failed draw is")

	# Asking again with an empty Deck banishes nothing and is not an error.
	var again := EffectPrimitives.banish_top_of_deck(_ctx(engine, source), 1, 2)
	t.eq(again.size(), 0, "banishing from an empty Deck banishes nothing, without failing")


static func _test_top_of_deck_banish_is_not_an_excavate_a_draw_or_a_mill(
		t: TestCase) -> void:
	t.start("banishing the top of a Deck is not an excavate, not a draw, not a mill and not "
		+ "a search — none of their events is emitted")
	var d := _duel(9607)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.spell("Source"))

	var before_exc := TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED)
	var before_draw := TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN)
	var before_gy := TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY)
	var before_hand := TestFixtures.count_events(engine, GameEvent.Kind.CARD_ADDED_TO_HAND)
	var before_banish := TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED)

	EffectPrimitives.banish_top_of_deck(_ctx(engine, source), 1, 2)

	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_BANISHED),
		before_banish + 2, "two CARD_BANISHED events, one per card")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_EXCAVATED), before_exc,
		"no excavate event — the cards did not pass through the excavation holding area")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_DRAWN), before_draw,
		"no draw event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_SENT_TO_GY), before_gy,
		"no send-to-GY event — this is not a mill")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_ADDED_TO_HAND), before_hand,
		"and no add-to-hand event — this is not a search")
	t.eq(engine.state.player(1).excavated.size(), 0,
		"nothing is left sitting in the excavation holding area")


# ---------------------------------------------------------------------------
# Owner, controller and face. RULES_SPEC.md 12 [S1 p.52].
# ---------------------------------------------------------------------------

static func _test_a_banished_card_goes_to_its_OWNERS_banished_zone(t: TestCase) -> void:
	t.start("a monster banished off a field controlled by someone other than its owner goes "
		+ "to its OWNER's Banished zone, and ownership is never rewritten [S1 p.52]")
	var d := _duel(9608)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	# Owned by player 1, then taken by player 0.
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Borrowed", 4, 1000, 1000))
	t.check(engine.state.change_control(theirs, 0, source.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "player 0 takes control of it")
	t.eq(theirs.controller_id, 0, "player 0 controls it")
	t.eq(theirs.owner_id, 1, "player 1 still owns it")

	engine.state.move_card(theirs, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)

	t.eq(theirs.owner_id, 1, "ownership is untouched by the banish")
	t.eq(theirs.controller_id, 1, "and the card is back with its owner, not its late holder")
	t.check(_banished_ids(engine, 1).has(theirs.id),
		"it is in the OWNER's Banished zone")
	t.check(not _banished_ids(engine, 0).has(theirs.id),
		"and not in the controller's")
	t.eq(engine.state.control_leases_for(theirs.id).size(), 0,
		"the control lease is over — the card left the field")


static func _test_face_up_and_face_down_banishment_are_different(t: TestCase) -> void:
	t.start("face-up and face-down banishment are different states, and the default is "
		+ "face-up [S1 p.53, RULES_SPEC.md 12]")
	var d := _duel(9609)
	var engine: DuelEngine = d["engine"]
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var up := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Face Up"))
	var down := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Face Down"))

	t.check(engine.state.banish_temporarily(up, source.id,
		Enums.BanishDuration.PERMANENT, true), "banished one face-up")
	t.check(engine.state.banish_temporarily(down, source.id,
		Enums.BanishDuration.PERMANENT, false), "banished the other face-down")

	t.check(up.is_face_up(), "the face-up banished card is face-up")
	t.check(not down.is_face_up(), "and the face-down one is not — the two are not the same")

	# A plain `move_card` banish is face-up, which is what every card in the V1 pool does.
	var plain := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Plain"))
	engine.state.move_card(plain, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)
	t.check(plain.is_face_up(), "an unqualified banish is face-up, the pool's only kind")


# ---------------------------------------------------------------------------
# What banishing from the FIELD cleans up. RULES_SPEC.md 15, 16.
# ---------------------------------------------------------------------------

static func _test_banishing_from_the_field_cleans_up_every_relationship(
		t: TestCase) -> void:
	t.start("banishing a monster off the field destroys its Equip Cards, drops its control "
		+ "leases, and clears its counters, modifiers and flags — the same departure any "
		+ "other card leaving the field performs")
	var d := _duel(9610)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var host := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Host", 4, 1000, 1000))
	var equip := TestFixtures.give_set_spell_trap(engine, 1,
		TestFixtures.equip_spell("An Equip", 500))
	t.check(state.equip_to(equip, host, equip.id), "the equip is attached")
	t.check(state.change_control(host, 0, source.id,
		Enums.ControlDuration.UNTIL_END_PHASE), "and player 0 has taken control")
	state.place_counters(host, "Spell Counter", 2, source.id)
	host.atk_modifiers.append({"source_id": source.id, "atk": 700, "def": 0,
		"until": "end_of_turn", "id": 1})
	host.flags["a_flag"] = true
	state.remember(host, "a_memory", 42)

	t.eq(host.counters.get("Spell Counter", 0), 2, "it holds 2 counters before the banish")
	t.eq(host.current_atk(), 1700, "and a temporary ATK modifier is in force")

	state.move_card(host, Enums.Zone.BANISHED, Enums.MoveReason.BANISHED)

	t.eq(host.zone, Enums.Zone.BANISHED, "the host is banished")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD,
		"its Equip Card was destroyed by the rules [S1 p.29, p.55]")
	t.eq(equip.last_move_reason, Enums.MoveReason.DESTROYED_BY_RULE,
		"as a RULES destruction, not a card effect")
	t.eq(state.control_leases_for(host.id).size(), 0, "the control lease is gone")
	t.eq(host.counters.size(), 0, "counters are cleared")
	t.eq(host.atk_modifiers.size(), 0, "temporary modifiers are cleared")
	t.eq(host.current_atk(), 1000, "so the ATK is back to its printed value")
	t.eq(host.flags.size(), 0, "per-instance flags are cleared")
	t.eq(host.equipped_card_ids.size(), 0, "and the equip relationship is gone")
	# What deliberately SURVIVES: the facts a later clause may still need. RULES_SPEC.md 15.
	t.eq(state.recall(host, "a_memory"), 42,
		"card_memory survives the departure, exactly as it does for any other move")
	t.eq(host.last_move_reason, Enums.MoveReason.BANISHED,
		"and the move reason is recorded after the reset, so it survives it")


# ---------------------------------------------------------------------------
# TEMPORARY removal — the lease. RULES_SPEC.md 8.3, CARD_RULINGS.md R30.
# ---------------------------------------------------------------------------

static func _test_a_temporary_banish_registers_a_lease_and_a_permanent_one_does_not(
		t: TestCase) -> void:
	t.start("a temporary banish registers a lease that records what banished the card and "
		+ "where it is due back; a permanent one registers nothing")
	var d := _duel(9611)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var temp := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Temporary"), Enums.Position.FACE_UP_DEFENSE)
	var perm := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Permanent"))

	t.check(state.banish_temporarily(temp, source.id,
		Enums.BanishDuration.UNTIL_END_PHASE), "the temporary banish happened")
	t.check(state.banish_temporarily(perm, source.id,
		Enums.BanishDuration.PERMANENT), "and so did the permanent one")

	t.eq(temp.zone, Enums.Zone.BANISHED, "both cards are banished")
	t.eq(perm.zone, Enums.Zone.BANISHED, "both cards are banished")
	t.check(state.is_temporarily_banished(temp.id), "one is scheduled to return")
	t.check(not state.is_temporarily_banished(perm.id), "the other is not")
	t.eq(state.banish_leases.size(), 1, "so exactly one lease exists")

	var lease: Dictionary = state.banish_leases_for(temp.id)[0]
	t.eq(int(lease["source_id"]), source.id, "the lease records what banished it")
	t.eq(lease["duration"], Enums.BanishDuration.UNTIL_END_PHASE,
		"and when it is due back")
	t.eq(lease["return_zone"], Enums.Zone.MONSTER_ZONE, "and where it goes")
	t.eq(lease["return_position"], Enums.Position.FACE_UP_DEFENSE,
		"and in what position — captured before the banish normalised it")
	t.eq(int(lease["return_controller"]), 0, "and under whose control")

	# The state, not the card's script, is what knows this.
	t.check(state.banish_leases_for(perm.id).is_empty(),
		"a permanent banish leaves nothing scheduled")


static func _test_the_return_happens_when_the_end_phase_is_entered(t: TestCase) -> void:
	t.start("a card banished 'until the End Phase' comes back as the End Phase is ENTERED — "
		+ "the same moment an until-the-End-Phase control lease ends (CARD_RULINGS.md R25)")
	var d := _duel(9612)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Away", 4, 1500, 1200))

	t.check(state.banish_temporarily(monster, source.id,
		Enums.BanishDuration.UNTIL_END_PHASE), "banished until the End Phase")
	t.eq(monster.zone, Enums.Zone.BANISHED, "it is away")

	# It stays away across engine timing points, not just for an instant. Every one of those
	# runs `expire_banish_leases(false)`, which must NOT return it: only the End Phase does.
	# Deliberately not advanced to Main Phase 2 to prove this — on turn 1 the Battle Phase is
	# prohibited, so `advance_to_phase(MAIN_2)` wraps through this turn's End Phase and the
	# monster would legitimately already be back.
	TestFixtures.pass_until_open(engine)
	state.expire_banish_leases(false)
	t.eq(monster.zone, Enums.Zone.BANISHED, "still away at a mid-turn timing point")
	t.check(state.is_temporarily_banished(monster.id), "and still scheduled")
	t.eq(state.phase, Enums.Phase.MAIN_1, "with the End Phase not yet reached")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(state.phase, Enums.Phase.END, "the End Phase has been entered")
	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "and the monster is back on the field")
	t.check(not state.is_temporarily_banished(monster.id), "the lease is discharged")
	t.eq(state.banish_leases.size(), 0, "and nothing is left scheduled")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, monster.id), 1,
		"exactly one return event was emitted")
	t.eq(monster.last_move_reason, Enums.MoveReason.RETURNED_FROM_BANISHMENT,
		"recorded with its own reason, distinct from every other way onto the field")


static func _test_the_return_is_not_a_summon(t: TestCase) -> void:
	t.start("the return is NOT a Summon: no Summon event of any kind is emitted, so nothing "
		+ "keyed on a successful Summon may see it (RULES_SPEC.md 8.3)")
	var d := _duel(9613)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Away"))
	state.banish_temporarily(monster, source.id, Enums.BanishDuration.UNTIL_END_PHASE)

	var before_summoned := TestFixtures.count_events(engine,
		GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED)
	var before_special := TestFixtures.count_events(engine,
		GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED)
	var before_flip := TestFixtures.count_events(engine,
		GameEvent.Kind.FLIP_SUMMON_SUCCEEDED)
	var before_declared := TestFixtures.count_events(engine,
		GameEvent.Kind.SPECIAL_SUMMON_DECLARED)
	var before_face_up := TestFixtures.count_events(engine,
		GameEvent.Kind.CARD_FLIPPED_FACE_UP)

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "the monster is back")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.NORMAL_SUMMON_SUCCEEDED),
		before_summoned, "no Normal/Tribute Summon event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_SUCCEEDED),
		before_special, "no Special Summon event")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.SPECIAL_SUMMON_DECLARED),
		before_declared, "not even a Special Summon DECLARATION")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.FLIP_SUMMON_SUCCEEDED),
		before_flip, "and no Flip Summon")
	t.eq(TestFixtures.count_events(engine, GameEvent.Kind.CARD_FLIPPED_FACE_UP),
		before_face_up, "and no flip-face-up event, so no FLIP effect may fire")
	t.eq(state.pending_summon_card_id, -1,
		"nothing was ever pending, so a Summon-negating card had nothing to answer")
	t.check(not monster.properly_special_summoned,
		"and it is not marked as properly Special Summoned — it was not Summoned at all")


static func _test_the_return_position_is_the_one_it_left_in(t: TestCase) -> void:
	t.start("the monster returns in the battle position it was banished in, for each "
		+ "position separately (CARD_RULINGS.md R30)")
	for entry in [Enums.Position.FACE_UP_ATTACK, Enums.Position.FACE_UP_DEFENSE,
			Enums.Position.FACE_DOWN_DEFENSE]:
		var position: Enums.Position = entry
		var d := _duel(9614 + int(position))
		var engine: DuelEngine = d["engine"]
		var source := TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.trap("Source"))
		var monster := TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Away"), position)
		engine.state.banish_temporarily(monster, source.id,
			Enums.BanishDuration.UNTIL_END_PHASE)
		# While banished, the position is the BANISHED state, not the field position.
		t.check(monster.is_face_up(), "while banished it is face-up in the Banished zone")
		TestFixtures.advance_to_phase(engine, Enums.Phase.END)
		t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "it came back")
		t.eq(monster.position, position,
			"and in the position it left in, not a default one")


static func _test_the_card_returns_under_its_OWNERS_control(t: TestCase) -> void:
	t.start("a borrowed monster banished temporarily returns under its OWNER's control, "
		+ "because leaving the field already ended the control lease (CARD_RULINGS.md R30)")
	var d := _duel(9620)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var theirs := TestFixtures.give_monster_on_field(engine, 1,
		TestFixtures.monster("Borrowed"))
	t.check(state.change_control(theirs, 0, source.id,
		Enums.ControlDuration.WHILE_SOURCE_FACE_UP), "player 0 takes control")
	t.eq(theirs.controller_id, 0, "player 0 controls it")

	t.check(state.banish_temporarily(theirs, source.id,
		Enums.BanishDuration.UNTIL_END_PHASE), "player 0 banishes it temporarily")
	var lease: Dictionary = state.banish_leases_for(theirs.id)[0]
	t.eq(int(lease["return_controller"]), 1,
		"the lease schedules it back to its OWNER, not to the player who banished it")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(theirs.zone, Enums.Zone.MONSTER_ZONE, "it came back to the field")
	t.eq(theirs.controller_id, 1, "under its owner's control")
	t.eq(theirs.owner_id, 1, "ownership never moved at any point")
	t.check(state.player(1).monster_zones.has(theirs),
		"and it physically sits in the owner's Monster Zone")
	t.eq(state.control_leases_for(theirs.id).size(), 0,
		"no control lease was resurrected by the return")


static func _test_nothing_comes_back_when_the_monster_zone_is_full(t: TestCase) -> void:
	t.start("a monster whose Monster Zones filled up while it was away cannot return, stays "
		+ "banished, and is not retried forever")
	var d := _duel(9621)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var away := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Away"))
	state.banish_temporarily(away, source.id, Enums.BanishDuration.UNTIL_END_PHASE)

	# Fill every Monster Zone while it is gone.
	for i in range(PlayerState.MONSTER_ZONE_COUNT):
		if state.player(0).free_monster_zone_index() < 0:
			break
		TestFixtures.give_monster_on_field(engine, 0,
			TestFixtures.monster("Filler %d" % i))
	t.check(state.player(0).free_monster_zone_index() < 0, "the field is full")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(away.zone, Enums.Zone.BANISHED, "the monster could not return and stays banished")
	t.eq(state.banish_leases.size(), 0,
		"the lease is gone all the same, so the return is not retried forever")
	var events := TestFixtures.events_of(engine,
		GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT)
	t.eq(events.size(), 1, "the failure was recorded rather than papered over")
	t.eq(events[0].data.get("returned"), false, "as a return that did not happen")
	t.eq(events[0].data.get("no_free_zone"), true, "with the reason it did not")


static func _test_a_card_moved_out_of_banishment_never_returns(t: TestCase) -> void:
	t.start("a temporarily banished card that another effect moves elsewhere loses its "
		+ "lease immediately and is never handed back")
	var d := _duel(9622)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var away := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Away"))
	state.banish_temporarily(away, source.id, Enums.BanishDuration.UNTIL_END_PHASE)
	t.check(state.is_temporarily_banished(away.id), "it is scheduled to return")

	# Another effect reaches into the Banished zone and moves it.
	state.move_card(away, Enums.Zone.GRAVEYARD, Enums.MoveReason.SENT_TO_GY_BY_EFFECT)
	t.eq(away.zone, Enums.Zone.GRAVEYARD, "it is now in the Graveyard")
	t.check(not state.is_temporarily_banished(away.id),
		"and the lease was dropped the moment it left the Banished zone")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(away.zone, Enums.Zone.GRAVEYARD, "the End Phase does not drag it onto the field")
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, away.id), 0,
		"and no return event was emitted at all")


static func _test_a_return_never_happens_twice(t: TestCase) -> void:
	t.start("a discharged lease cannot fire again, and expiring repeatedly is a no-op")
	var d := _duel(9623)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var away := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("Away"))
	state.banish_temporarily(away, source.id, Enums.BanishDuration.UNTIL_END_PHASE)

	var lease: Dictionary = state.banish_leases_for(away.id)[0]
	t.check(state.end_banish_lease(lease), "the lease discharged and the card returned")
	t.eq(away.zone, Enums.Zone.MONSTER_ZONE, "the card is back")
	t.check(not state.end_banish_lease(lease), "ending the same lease again does nothing")

	# The End Phase, and every timing point before it, must not fire it a second time.
	state.expire_banish_leases(true)
	state.expire_banish_leases(true)
	TestFixtures.advance_to_phase(engine, Enums.Phase.END)
	t.eq(TestFixtures.count_events_for(engine,
		GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT, away.id), 1,
		"exactly one return event exists no matter how many times expiry runs")
	t.eq(away.zone, Enums.Zone.MONSTER_ZONE, "and the card is on the field exactly once")
	t.eq(state.player(0).monster_zones.count(away), 1, "occupying exactly one zone")


static func _test_a_temporary_banish_comes_back_stateless(t: TestCase) -> void:
	t.start("the monster that comes back is a fresh instance of the card: counters, "
		+ "modifiers, flags and equips are all gone, exactly as for any card that left the "
		+ "field and came back (master prompt 48)")
	var d := _duel(9624)
	var engine: DuelEngine = d["engine"]
	var state := engine.state
	var source := TestFixtures.give_set_spell_trap(engine, 0, TestFixtures.trap("Source"))
	var monster := TestFixtures.give_monster_on_field(engine, 0,
		TestFixtures.monster("Away", 4, 1000, 1000))
	var equip := TestFixtures.give_set_spell_trap(engine, 0,
		TestFixtures.equip_spell("An Equip", 500))
	state.equip_to(equip, monster, equip.id)
	state.place_counters(monster, "Spell Counter", 3, source.id)
	monster.atk_modifiers.append({"source_id": source.id, "atk": 400, "def": 0,
		"until": "end_of_turn", "id": 7})
	monster.has_attacked_this_turn = true

	state.banish_temporarily(monster, source.id, Enums.BanishDuration.UNTIL_END_PHASE)
	t.eq(equip.zone, Enums.Zone.GRAVEYARD,
		"the Equip Card died when the host was banished and does NOT come back with it")

	TestFixtures.advance_to_phase(engine, Enums.Phase.END)

	t.eq(monster.zone, Enums.Zone.MONSTER_ZONE, "the monster is back")
	t.eq(monster.counters.size(), 0, "with no counters")
	t.eq(monster.current_atk(), 1000, "at its printed ATK, the modifier gone")
	t.eq(monster.equipped_card_ids.size(), 0, "with nothing equipped to it")
	t.eq(equip.zone, Enums.Zone.GRAVEYARD, "the Equip Card is still in the Graveyard")
	t.check(not monster.has_attacked_this_turn,
		"and even its attack record was reset when it left the field")


# ---------------------------------------------------------------------------
# Determinism. RULES_SPEC.md 13.
# ---------------------------------------------------------------------------

static func _test_the_whole_cycle_is_replay_deterministic(t: TestCase) -> void:
	t.start("the same seed and the same actions produce the same banish/return event "
		+ "sequence, twice")
	var runs: Array = []
	for run in range(2):
		var d := _duel(9630)
		var engine: DuelEngine = d["engine"]
		var state := engine.state
		var source := TestFixtures.give_set_spell_trap(engine, 0,
			TestFixtures.trap("Source"))
		var a := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("A"))
		var b := TestFixtures.give_monster_on_field(engine, 0, TestFixtures.monster("B"),
			Enums.Position.FACE_UP_DEFENSE)
		state.banish_temporarily(a, source.id, Enums.BanishDuration.UNTIL_END_PHASE)
		state.banish_temporarily(b, source.id, Enums.BanishDuration.UNTIL_END_PHASE)
		EffectPrimitives.banish_top_of_deck(_ctx(engine, source), 1, 2)
		TestFixtures.advance_to_phase(engine, Enums.Phase.END)

		var trace: Array = []
		for entry in state.events:
			var ev: GameEvent = entry
			if ev.kind == GameEvent.Kind.CARD_BANISHED \
					or ev.kind == GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT:
				trace.append("%d:%s" % [ev.kind, str(ev.data.get("card_name", ""))])
		runs.append(trace)

	t.check(runs[0].size() > 0, "the run produced banish/return events")
	t.eq(runs[0], runs[1],
		"and two identically seeded runs produce the identical event sequence")
	# The two returns happen in a fixed order, oldest lease first.
	var returns: Array = []
	for line in runs[0]:
		if str(line).begins_with("%d:" % GameEvent.Kind.CARD_RETURNED_FROM_BANISHMENT):
			returns.append(line)
	t.eq(returns.size(), 2, "both temporarily banished monsters came back")
	t.check(str(returns[0]).ends_with(":A"),
		"and the oldest lease discharged first — a fixed order, not a dictionary's")
