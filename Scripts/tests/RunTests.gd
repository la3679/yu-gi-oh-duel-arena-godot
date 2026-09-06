extends SceneTree

## Headless test entry point. Master prompt 64.
##
##   godot --headless --path <project> --script res://Scripts/tests/RunTests.gd
##
## Exits 0 only when every suite passes. Suites are registered explicitly so a suite
## that fails to load is a hard error rather than a silently skipped test.
##
## A suite that runs ZERO assertions is also a failure. Without that check a suite whose
## script failed to compile reports "0/0 passed" and the run would claim PASS while
## testing nothing — which happened once during development and must never be possible.

func _initialize() -> void:
	var suites: Array[TestCase] = []

	suites.append(ChainTests.run())
	suites.append(TimingTests.run())
	suites.append(TurnFlowTests.run())
	suites.append(SummonTests.run())
	suites.append(SpellTrapTests.run())
	suites.append(BattleTests.run())
	suites.append(DamageStepTests.run())
	suites.append(ContinuousTests.run())
	suites.append(CounterTests.run())
	suites.append(HiddenInfoTests.run())
	suites.append(SpecialSummonTests.run())
	suites.append(RulesQuestionTests.run())
	suites.append(ReplayTests.run())
	suites.append(EquipTests.run())
	suites.append(ControlTests.run())
	suites.append(MovementTests.run())
	suites.append(BanishTests.run())
	suites.append(LifePointCostTests.run())
	suites.append(TrapMonsterTests.run())
	suites.append(BattlePhaseRestrictionTests.run())
	suites.append(AttackRestrictionTests.run())
	suites.append(ChoiceConstraintTests.run())
	suites.append(DeckAccessTests.run())

	# --- Per-card suites (Phase 5). One per implemented card. ---
	suites.append(ShiningAngelTests.run())
	suites.append(NormalMonsterTests.run())
	suites.append(MonsterRebornTests.run())
	suites.append(SilversCryTests.run())
	suites.append(KaibamanTests.run())
	suites.append(DragonicTacticsTests.run())
	suites.append(OneForOneTests.run())
	suites.append(BirthrightTests.run())
	suites.append(CallOfTheHauntedTests.run())
	suites.append(HieraticDragonOfTefnuitTests.run())
	suites.append(InariFireTests.run())
	suites.append(RanryuTests.run())
	suites.append(NefariousArchfiendTests.run())
	suites.append(GagagashieldTests.run())
	suites.append(RiderOfTheStormWindsTests.run())
	suites.append(CastleOfDragonSoulsTests.run())
	suites.append(FiendishChainTests.run())
	suites.append(FiveBrothersExplosionTests.run())
	suites.append(SealingCeremonyOfSuitonTests.run())
	suites.append(WonderBalloonsTests.run())
	suites.append(ApprenticeMagicianTests.run())
	suites.append(KunaiWithChainTests.run())
	suites.append(FairyTailRellaTests.run())
	suites.append(ChampionsVigilanceTests.run())
	suites.append(AussaTheEarthCharmerTests.run())
	suites.append(EriaTheWaterCharmerTests.run())
	suites.append(WynnTheWindCharmerTests.run())
	suites.append(EnemyControllerTests.run())
	suites.append(CompulsoryEvacuationDeviceTests.run())
	suites.append(KaiserGliderTests.run())
	suites.append(AWingbeatOfGiantDragonTests.run())
	suites.append(PhoenixWingWindBlastTests.run())
	suites.append(SpiritualWindArtMiyabiTests.run())
	suites.append(ChainDetonationTests.run())
	suites.append(ChainHealingTests.run())
	suites.append(CrystalSeerTests.run())
	suites.append(InterdimensionalMatterTransporterTests.run())
	suites.append(JudgeOfTheIceBarrierTests.run())
	suites.append(JunkBladerTests.run())
	suites.append(ThePhantomKnightsOfShadowVeilTests.run())
	suites.append(RunickFlashingFireTests.run())
	suites.append(MirageDragonTests.run())
	suites.append(SwordsOfRevealingLightTests.run())
	suites.append(MaidenWithEyesOfBlueTests.run())
	suites.append(KaiserSeaHorseTests.run())
	suites.append(SoulExchangeTests.run())

	# --- Interaction suites (Phase 5). Cross-card behaviour, no card-under-test. ---
	suites.append(SpecialSummonInteractionTests.run())
	suites.append(DragonShrineTests.run())
	suites.append(TheWhiteStoneOfLegendTests.run())
	suites.append(HeraldOfCreationTests.run())
	suites.append(DivineDragonApocralyphTests.run())
	suites.append(TradeInTests.run())
	suites.append(CardsOfConsonanceTests.run())
	suites.append(WhiteElephantsGiftTests.run())

	# --- Batch 11 ---
	suites.append(StampingDestructionTests.run())
	suites.append(StraightFlushTests.run())
	suites.append(BurstStreamOfDestructionTests.run())
	suites.append(ChironTheMageTests.run())
	suites.append(BackUpRiderTests.run())
	suites.append(VampiricKoalaTests.run())

	# --- Batch 12 ---
	suites.append(SpiritualFireArtKurenaiTests.run())

	var total_passed := 0
	var total_failed := 0
	var empty_suites: Array[String] = []
	print("")
	for s in suites:
		print(s.report())
		total_passed += s.passed
		total_failed += s.failed
		if s.total() == 0:
			empty_suites.append(s.suite_name)

	print("")
	print("=======================================")
	print("TOTAL: %d passed, %d failed (%d assertions across %d suite(s))"
		% [total_passed, total_failed, total_passed + total_failed, suites.size()])
	for name in empty_suites:
		print("EMPTY SUITE: %s ran no assertions — treated as a failure" % name)
	print("=======================================")

	if total_failed > 0 or not empty_suites.is_empty():
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
