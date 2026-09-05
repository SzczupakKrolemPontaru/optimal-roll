import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main() {
  test(
    'keeps the strongest candidate and validates it on unseen seeds',
    () async {
      final progress = <WeightOptimizationProgress>[];
      final result =
          await const AdvisorWeightOptimizer(runner: _FakeSimulationRunner())
              .optimize(
                options: const WeightOptimizerOptions(
                  populationSize: 2,
                  generations: 1,
                  trainingGames: 3,
                  validationCandidateCount: 2,
                  validationGames: 2,
                  testGames: 2,
                  firstTrainingSeed: 10,
                  firstValidationSeed: 100,
                  firstTestSeed: 200,
                ),
                onProgress: progress.add,
              );

      expect(
        result.bestCandidate.cacheKey,
        AdvisorWeightCandidate.defaults().cacheKey,
      );
      expect(result.trainingReport.games.map((game) => game.seed), [
        10,
        11,
        12,
      ]);
      expect(result.validationReport.games.map((game) => game.seed), [
        100,
        101,
      ]);
      expect(result.validationComparison.scoreDifference.mean, 0);
      expect(result.testReport.games.map((game) => game.seed), [200, 201]);
      expect(result.validatedCandidates, hasLength(2));
      expect(result.isValidatedImprovement, isFalse);
      expect(progress, hasLength(2));
      expect(
        progress
            .singleWhere((entry) => entry.candidateIndex == 1)
            .trainingGames,
        3,
      );
      expect(result.toJson()['profileVersion'], 2);
      expect(result.toJson()['profileName'], 'optimized-v2');
      expect(
        (result.toJson()['experiment'] as Map<String, Object>)['searchSpace'],
        AdvisorWeightSearchSpace.standard.toJson(),
      );
    },
  );

  test('round-trips grouped pijol and school weights through JSON', () {
    const candidate = AdvisorWeightCandidate(
      openingColumnValue: 7,
      chanceCostEarly: 11,
      chanceCostLate: 3,
      pijolBaseCost: 13,
      perfectColumnRiskCost: 41,
      schoolBonusProgressWeight: 1.5,
      schoolCompletionValue: 8,
      pijolGroupCosts: {PijolFigureGroup.rare: 25, PijolFigureGroup.chance: 60},
    );

    final decoded = AdvisorWeightCandidate.fromJson(candidate.toJson());

    expect(decoded.cacheKey, candidate.cacheKey);
    expect(decoded.weights.pijolFieldCosts[Figure.MARSHAL], 25);
    expect(decoded.weights.pijolFieldCosts[Figure.CHANCE], 60);
    expect(decoded.weights.pijolFieldCosts[Figure.PAIR], 0);
  });

  test('reports candidate values close to search-space limits', () {
    const candidate = AdvisorWeightCandidate(
      openingColumnValue: 60,
      chanceCostEarly: 88.5,
      chanceCostLate: 10,
      pijolBaseCost: 20,
      perfectColumnRiskCost: 100,
      pijolGroupCosts: {PijolFigureGroup.straight: 199},
    );

    expect(AdvisorWeightSearchSpace.wide.boundaryHits(candidate), [
      'openingColumnValue=60.00/60.00',
      'chanceCostEarly=88.50/90.00',
      'pijolGroupCosts.straight=199.00/200.00',
    ]);
  });

  test('increases the shared training sample across generations', () async {
    final progress = <WeightOptimizationProgress>[];
    final requestedTrainingGames = <int>[];

    await AdvisorWeightOptimizer(
      runner: _FakeSimulationRunner(requestedTrainingGames),
    ).optimize(
      options: const WeightOptimizerOptions(
        populationSize: 2,
        generations: 3,
        minimumTrainingGames: 2,
        trainingGames: 8,
        validationCandidateCount: 1,
        validationGames: 1,
        testGames: 1,
      ),
      onProgress: progress.add,
    );

    expect(
      progress
          .where((entry) => entry.candidateIndex == 1)
          .map((entry) => entry.trainingGames),
      [2, 4, 8],
    );
    expect(requestedTrainingGames, [2, 2, 2, 2, 4, 4]);
  });
}

class _FakeSimulationRunner extends SimulationRunner {
  final List<int>? requestedTrainingGames;

  const _FakeSimulationRunner([this.requestedTrainingGames]);

  @override
  Future<SimulationReport> runParallel({
    required GameStrategy strategy,
    required int gameCount,
    required int firstSeed,
    required int workers,
  }) async {
    if (strategy.name.startsWith('candidate-')) {
      requestedTrainingGames?.add(gameCount);
    }
    final advisorStrategy = strategy as AdvisorGameStrategy;
    final score = advisorStrategy
        .advisor
        .scoringUtility
        .weights
        .openingColumnValue
        .round();
    return SimulationReport(
      strategyName: strategy.name,
      games: [
        for (var index = 0; index < gameCount; index++)
          SimulationGameResult(
            seed: firstSeed + index,
            finalState: _completeGameWithSchoolScore(score),
            turnsPlayed: 0,
            rollsMade: 0,
            diceRolled: 0,
            figuresScoredFromHand: 0,
          ),
      ],
      elapsed: Duration.zero,
    );
  }
}

GameState _completeGameWithSchoolScore(int score) => GameState([
  _completeColumn(firstSchoolScore: score),
  _completeColumn(),
  _completeColumn(),
]);

ScoreColumn _completeColumn({int firstSchoolScore = 0}) => ScoreColumn(
  school: {
    for (var face = 1; face <= 6; face++)
      face: ScoreEntry.scored(face == 1 ? firstSchoolScore : 0),
  },
  figures: {
    for (final figure in Figure.values) figure: const ScoreEntry.pijol(),
  },
);
