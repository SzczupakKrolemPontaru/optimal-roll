import 'dart:math';

import '../advisor/advisor.dart';
import '../domain/game_engine.dart';
import 'game_strategy.dart';
import 'simulation_report.dart';
import 'simulation_runner.dart';

enum PijolFigureGroup { basic, rare, compound, straight, parity, small, chance }

PijolFigureGroup pijolGroupFor(Figure figure) => switch (figure) {
  Figure.PAIR ||
  Figure.TWO_PAIRS ||
  Figure.THREE_OF_A_KIND ||
  Figure.FOUR_OF_A_KIND => PijolFigureGroup.basic,
  Figure.GENERAL || Figure.MARSHAL => PijolFigureGroup.rare,
  Figure.THREE_PAIRS ||
  Figure.TWO_TRIPLES ||
  Figure.FOUR_PLUS_TWO ||
  Figure.FULL_HOUSE => PijolFigureGroup.compound,
  Figure.SMALL_STRAIGHT ||
  Figure.BIG_STRAIGHT ||
  Figure.GREAT_STRAIGHT => PijolFigureGroup.straight,
  Figure.EVEN || Figure.ODD => PijolFigureGroup.parity,
  Figure.SMALL => PijolFigureGroup.small,
  Figure.CHANCE => PijolFigureGroup.chance,
};

class AdvisorWeightCandidate {
  final double openingColumnValue;
  final double chanceCostEarly;
  final double chanceCostLate;
  final double pijolBaseCost;
  final double perfectColumnRiskCost;
  final double schoolBonusProgressWeight;
  final double schoolCompletionValue;
  final Map<PijolFigureGroup, double> pijolGroupCosts;

  const AdvisorWeightCandidate({
    required this.openingColumnValue,
    required this.chanceCostEarly,
    required this.chanceCostLate,
    required this.pijolBaseCost,
    required this.perfectColumnRiskCost,
    this.schoolBonusProgressWeight = 0,
    this.schoolCompletionValue = 0,
    this.pijolGroupCosts = const {},
  });

  factory AdvisorWeightCandidate.defaults() {
    const weights = AdvisorWeights();
    return AdvisorWeightCandidate(
      openingColumnValue: weights.openingColumnValue,
      chanceCostEarly: weights.chanceCostEarly,
      chanceCostLate: weights.chanceCostLate,
      pijolBaseCost: weights.pijolBaseCost,
      perfectColumnRiskCost: weights.perfectColumnRiskCost,
      schoolBonusProgressWeight: weights.schoolBonusProgressWeight,
      schoolCompletionValue: weights.schoolCompletionValue,
      pijolGroupCosts: {
        for (final group in PijolFigureGroup.values)
          group:
              weights.pijolFieldCosts[Figure.values.firstWhere(
                (figure) => pijolGroupFor(figure) == group,
              )] ??
              0,
      },
    );
  }

  factory AdvisorWeightCandidate.zero() => const AdvisorWeightCandidate(
    openingColumnValue: 0,
    chanceCostEarly: 0,
    chanceCostLate: 0,
    pijolBaseCost: 0,
    perfectColumnRiskCost: 0,
  );

  factory AdvisorWeightCandidate.fromJson(Map<String, dynamic> json) {
    final nestedWeights = json['weights'];
    final source = nestedWeights is Map
        ? Map<String, dynamic>.from(nestedWeights)
        : json;
    final groupJson = source['pijolGroupCosts'];
    final groups = groupJson is Map
        ? Map<String, dynamic>.from(groupJson)
        : const <String, dynamic>{};
    const defaults = AdvisorWeights();
    return AdvisorWeightCandidate(
      openingColumnValue: _jsonDouble(
        source,
        'openingColumnValue',
        defaults.openingColumnValue,
      ),
      chanceCostEarly: _jsonDouble(
        source,
        'chanceCostEarly',
        defaults.chanceCostEarly,
      ),
      chanceCostLate: _jsonDouble(
        source,
        'chanceCostLate',
        defaults.chanceCostLate,
      ),
      pijolBaseCost: _jsonDouble(
        source,
        'pijolBaseCost',
        defaults.pijolBaseCost,
      ),
      perfectColumnRiskCost: _jsonDouble(
        source,
        'perfectColumnRiskCost',
        defaults.perfectColumnRiskCost,
      ),
      schoolBonusProgressWeight: _jsonDouble(
        source,
        'schoolBonusProgressWeight',
        defaults.schoolBonusProgressWeight,
      ),
      schoolCompletionValue: _jsonDouble(
        source,
        'schoolCompletionValue',
        defaults.schoolCompletionValue,
      ),
      pijolGroupCosts: {
        for (final group in PijolFigureGroup.values)
          group: _jsonDouble(groups, group.name, 0),
      },
    );
  }

  AdvisorWeights get weights => AdvisorWeights(
    openingColumnValue: openingColumnValue,
    chanceCostEarly: chanceCostEarly,
    chanceCostLate: chanceCostLate,
    pijolBaseCost: pijolBaseCost,
    perfectColumnRiskCost: perfectColumnRiskCost,
    schoolBonusProgressWeight: schoolBonusProgressWeight,
    schoolCompletionValue: schoolCompletionValue,
    pijolFieldCosts: {
      for (final figure in Figure.values)
        figure: pijolGroupCosts[pijolGroupFor(figure)] ?? 0,
    },
  );

  String get cacheKey => [
    openingColumnValue,
    chanceCostEarly,
    chanceCostLate,
    pijolBaseCost,
    perfectColumnRiskCost,
    schoolBonusProgressWeight,
    schoolCompletionValue,
    for (final group in PijolFigureGroup.values) pijolGroupCosts[group] ?? 0,
  ].map((value) => value.toStringAsFixed(8)).join('|');

  Map<String, Object> toJson() => {
    'openingColumnValue': openingColumnValue,
    'chanceCostEarly': chanceCostEarly,
    'chanceCostLate': chanceCostLate,
    'pijolBaseCost': pijolBaseCost,
    'perfectColumnRiskCost': perfectColumnRiskCost,
    'schoolBonusProgressWeight': schoolBonusProgressWeight,
    'schoolCompletionValue': schoolCompletionValue,
    'pijolGroupCosts': {
      for (final group in PijolFigureGroup.values)
        group.name: pijolGroupCosts[group] ?? 0,
    },
  };
}

class WeightOptimizerOptions {
  final int populationSize;
  final int generations;
  final int minimumTrainingGames;
  final int trainingGames;
  final int validationCandidateCount;
  final int validationGames;
  final int testGames;
  final int firstTrainingSeed;
  final int firstValidationSeed;
  final int firstTestSeed;
  final int workers;
  final int optimizerSeed;

  const WeightOptimizerOptions({
    this.populationSize = 6,
    this.generations = 2,
    this.minimumTrainingGames = 1,
    this.trainingGames = 1,
    this.validationCandidateCount = 2,
    this.validationGames = 1,
    this.testGames = 1,
    this.firstTrainingSeed = 1,
    this.firstValidationSeed = 1000001,
    this.firstTestSeed = 2000001,
    this.workers = 1,
    this.optimizerSeed = 20260903,
  });

  void validate() {
    if (populationSize < 2) {
      throw ArgumentError.value(
        populationSize,
        'populationSize',
        'Must be at least 2.',
      );
    }
    if (generations <= 0 ||
        minimumTrainingGames <= 0 ||
        trainingGames < minimumTrainingGames ||
        validationGames <= 0 ||
        testGames <= 0) {
      throw ArgumentError(
        'Generation and game counts must be positive, and maximum training '
        'games cannot be lower than the minimum.',
      );
    }
    if (validationCandidateCount <= 0 ||
        validationCandidateCount > populationSize) {
      throw ArgumentError.value(
        validationCandidateCount,
        'validationCandidateCount',
        'Must be between 1 and the population size.',
      );
    }
    if (workers <= 0) {
      throw ArgumentError.value(workers, 'workers', 'Must be positive.');
    }
  }

  Map<String, int> toJson() => {
    'populationSize': populationSize,
    'generations': generations,
    'minimumTrainingGames': minimumTrainingGames,
    'trainingGames': trainingGames,
    'validationCandidateCount': validationCandidateCount,
    'validationGames': validationGames,
    'testGames': testGames,
    'firstTrainingSeed': firstTrainingSeed,
    'firstValidationSeed': firstValidationSeed,
    'firstTestSeed': firstTestSeed,
    'workers': workers,
    'optimizerSeed': optimizerSeed,
  };
}

class WeightOptimizationProgress {
  final int generation;
  final int candidateIndex;
  final int populationSize;
  final int trainingGames;
  final AdvisorWeightCandidate candidate;
  final double meanScore;
  final bool cached;

  const WeightOptimizationProgress({
    required this.generation,
    required this.candidateIndex,
    required this.populationSize,
    required this.trainingGames,
    required this.candidate,
    required this.meanScore,
    required this.cached,
  });
}

class ValidatedWeightCandidate {
  final AdvisorWeightCandidate candidate;
  final SimulationReport trainingReport;
  final SimulationReport validationReport;
  final StrategyComparison validationComparison;

  const ValidatedWeightCandidate({
    required this.candidate,
    required this.trainingReport,
    required this.validationReport,
    required this.validationComparison,
  });

  Map<String, Object> toJson() => {
    'weights': candidate.toJson(),
    'trainingScore': trainingReport.totalScore.mean,
    'validationScore': validationReport.totalScore.mean,
    'comparison': validationComparison.toJson(),
  };
}

class WeightOptimizationResult {
  final String profileName;
  final WeightOptimizerOptions options;
  final AdvisorWeightCandidate bestCandidate;
  final SimulationReport trainingReport;
  final SimulationReport validationReport;
  final SimulationReport validationBaselineReport;
  final SimulationReport testReport;
  final SimulationReport testBaselineReport;
  final List<ValidatedWeightCandidate> validatedCandidates;
  final List<double> bestScoreByGeneration;

  const WeightOptimizationResult({
    required this.profileName,
    required this.options,
    required this.bestCandidate,
    required this.trainingReport,
    required this.validationReport,
    required this.validationBaselineReport,
    required this.testReport,
    required this.testBaselineReport,
    required this.validatedCandidates,
    required this.bestScoreByGeneration,
  });

  StrategyComparison get validationComparison => StrategyComparison(
    candidate: validationReport,
    baseline: validationBaselineReport,
  );

  StrategyComparison get testComparison =>
      StrategyComparison(candidate: testReport, baseline: testBaselineReport);

  bool get isValidatedImprovement =>
      testReport.gameCount >= 30 &&
      testComparison.scoreDifference.mean -
              testComparison.confidence95HalfWidth >
          0;

  Map<String, Object> toJson() => {
    'profileVersion': 2,
    'profileName': profileName,
    'experiment': options.toJson(),
    'weights': bestCandidate.toJson(),
    'training': trainingReport.toJson(),
    'validation': validationReport.toJson(),
    'validationBaseline': validationBaselineReport.toJson(),
    'validationComparison': validationComparison.toJson(),
    'test': testReport.toJson(),
    'testBaseline': testBaselineReport.toJson(),
    'testComparison': testComparison.toJson(),
    'isValidatedImprovement': isValidatedImprovement,
    'validatedCandidates': validatedCandidates
        .map((candidate) => candidate.toJson())
        .toList(),
    'bestScoreByGeneration': bestScoreByGeneration,
  };
}

typedef OptimizationProgressCallback = void Function(
  WeightOptimizationProgress progress,
);

class AdvisorWeightOptimizer {
  final SimulationRunner runner;

  const AdvisorWeightOptimizer({this.runner = const SimulationRunner()});

  Future<WeightOptimizationResult> optimize({
    WeightOptimizerOptions options = const WeightOptimizerOptions(),
    String profileName = 'optimized-v2',
    OptimizationProgressCallback? onProgress,
  }) async {
    options.validate();
    final random = Random(options.optimizerSeed);
    var population = _initialPopulation(options.populationSize, random);
    final reportCache = <String, SimulationReport>{};
    final bestScoreByGeneration = <double>[];
    var finalRanking = <_EvaluatedCandidate>[];

    for (var generation = 0; generation < options.generations; generation++) {
      final gameCount = _trainingGamesForGeneration(options, generation);
      final evaluated = <_EvaluatedCandidate>[];
      for (var index = 0; index < population.length; index++) {
        final candidate = population[index];
        final cacheKey = candidate.cacheKey;
        final cachedReport = reportCache[cacheKey];
        late final SimulationReport report;
        if (cachedReport == null) {
          report = await runner.runParallel(
            strategy: AdvisorGameStrategy.withWeights(
              name: 'candidate-g${generation + 1}-${index + 1}',
              weights: candidate.weights,
            ),
            gameCount: gameCount,
            firstSeed: options.firstTrainingSeed,
            workers: options.workers,
          );
        } else if (cachedReport.gameCount == gameCount) {
          report = cachedReport;
        } else {
          final additional = await runner.runParallel(
            strategy: AdvisorGameStrategy.withWeights(
              name: 'candidate-g${generation + 1}-${index + 1}',
              weights: candidate.weights,
            ),
            gameCount: gameCount - cachedReport.gameCount,
            firstSeed: options.firstTrainingSeed + cachedReport.gameCount,
            workers: options.workers,
          );
          report = SimulationReport(
            strategyName: additional.strategyName,
            games: List.unmodifiable([
              ...cachedReport.games,
              ...additional.games,
            ]),
            elapsed: cachedReport.elapsed + additional.elapsed,
          );
        }
        reportCache[cacheKey] = report;
        evaluated.add(_EvaluatedCandidate(candidate, report));
        onProgress?.call(
          WeightOptimizationProgress(
            generation: generation + 1,
            candidateIndex: index + 1,
            populationSize: population.length,
            trainingGames: gameCount,
            candidate: candidate,
            meanScore: report.totalScore.mean,
            cached: cachedReport != null,
          ),
        );
      }
      evaluated.sort(_compareEvaluatedCandidates);
      finalRanking = evaluated;
      bestScoreByGeneration.add(evaluated.first.report.totalScore.mean);
      if (generation + 1 < options.generations) {
        population = _nextGeneration(
          evaluated,
          options.populationSize,
          generation,
          options.generations,
          random,
        );
      }
    }

    final validationBaselineReport = await runner.runParallel(
      strategy: const AdvisorGameStrategy(name: 'default-validation-baseline'),
      gameCount: options.validationGames,
      firstSeed: options.firstValidationSeed,
      workers: options.workers,
    );
    final finalists = _uniqueFinalists(
      finalRanking,
      options.validationCandidateCount,
    );
    final validated = <ValidatedWeightCandidate>[];
    for (var index = 0; index < finalists.length; index++) {
      final finalist = finalists[index];
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'validation-finalist-${index + 1}',
          weights: finalist.candidate.weights,
        ),
        gameCount: options.validationGames,
        firstSeed: options.firstValidationSeed,
        workers: options.workers,
      );
      validated.add(
        ValidatedWeightCandidate(
          candidate: finalist.candidate,
          trainingReport: finalist.report,
          validationReport: report,
          validationComparison: StrategyComparison(
            candidate: report,
            baseline: validationBaselineReport,
          ),
        ),
      );
    }
    validated.sort((left, right) {
      final validation = right.validationComparison.scoreDifference.mean
          .compareTo(left.validationComparison.scoreDifference.mean);
      if (validation != 0) return validation;
      return right.trainingReport.totalScore.mean.compareTo(
        left.trainingReport.totalScore.mean,
      );
    });
    final selected = validated.first;

    final testReport = await runner.runParallel(
      strategy: AdvisorGameStrategy.withWeights(
        name: '$profileName-test',
        weights: selected.candidate.weights,
      ),
      gameCount: options.testGames,
      firstSeed: options.firstTestSeed,
      workers: options.workers,
    );
    final testBaselineReport = await runner.runParallel(
      strategy: const AdvisorGameStrategy(name: 'default-test-baseline'),
      gameCount: options.testGames,
      firstSeed: options.firstTestSeed,
      workers: options.workers,
    );
    return WeightOptimizationResult(
      profileName: profileName,
      options: options,
      bestCandidate: selected.candidate,
      trainingReport: selected.trainingReport,
      validationReport: selected.validationReport,
      validationBaselineReport: validationBaselineReport,
      testReport: testReport,
      testBaselineReport: testBaselineReport,
      validatedCandidates: List.unmodifiable(validated),
      bestScoreByGeneration: List.unmodifiable(bestScoreByGeneration),
    );
  }
}

class _EvaluatedCandidate {
  final AdvisorWeightCandidate candidate;
  final SimulationReport report;

  const _EvaluatedCandidate(this.candidate, this.report);
}

List<AdvisorWeightCandidate> _initialPopulation(int size, Random random) => [
  AdvisorWeightCandidate.defaults(),
  AdvisorWeightCandidate.zero(),
  for (var index = 2; index < size; index++) _randomCandidate(random),
];

int _trainingGamesForGeneration(
  WeightOptimizerOptions options,
  int generation,
) {
  if (options.generations == 1 ||
      options.minimumTrainingGames == options.trainingGames) {
    return options.trainingGames;
  }
  final progress = generation / (options.generations - 1);
  final ratio = options.trainingGames / options.minimumTrainingGames;
  return (options.minimumTrainingGames * pow(ratio, progress)).round();
}

List<_EvaluatedCandidate> _uniqueFinalists(
  List<_EvaluatedCandidate> ranking,
  int count,
) {
  final seen = <String>{};
  final result = <_EvaluatedCandidate>[];
  for (final candidate in ranking) {
    if (seen.add(candidate.candidate.cacheKey)) result.add(candidate);
    if (result.length == count) break;
  }
  if (result.isEmpty) throw StateError('No unique finalist was produced.');
  return result;
}

int _compareEvaluatedCandidates(
  _EvaluatedCandidate left,
  _EvaluatedCandidate right,
) => right.report.totalScore.mean.compareTo(left.report.totalScore.mean);

List<AdvisorWeightCandidate> _nextGeneration(
  List<_EvaluatedCandidate> evaluated,
  int populationSize,
  int generation,
  int generationCount,
  Random random,
) {
  final eliteCount = max(2, populationSize ~/ 4);
  final elites = evaluated.take(eliteCount).toList();
  final progress = generationCount == 1
      ? 1.0
      : generation / (generationCount - 1);
  final mutationScale = .20 * (1 - progress) + .04;
  return [
    for (final elite in elites) elite.candidate,
    for (var index = eliteCount; index < populationSize; index++)
      _mutate(
        elites[random.nextInt(elites.length)].candidate,
        random,
        mutationScale,
      ),
  ];
}

AdvisorWeightCandidate _randomCandidate(Random random) =>
    AdvisorWeightCandidate(
      openingColumnValue: random.nextDouble() * 40,
      chanceCostEarly: random.nextDouble() * 45,
      chanceCostLate: random.nextDouble() * 30,
      pijolBaseCost: random.nextDouble() * 60,
      perfectColumnRiskCost: random.nextDouble() * 160,
      schoolBonusProgressWeight: random.nextDouble() * 5,
      schoolCompletionValue: random.nextDouble() * 40,
      pijolGroupCosts: {
        for (final group in PijolFigureGroup.values)
          group: random.nextDouble() * 100,
      },
    );

AdvisorWeightCandidate _mutate(
  AdvisorWeightCandidate parent,
  Random random,
  double scale,
) => AdvisorWeightCandidate(
  openingColumnValue: _mutated(parent.openingColumnValue, 40, random, scale),
  chanceCostEarly: _mutated(parent.chanceCostEarly, 45, random, scale),
  chanceCostLate: _mutated(parent.chanceCostLate, 30, random, scale),
  pijolBaseCost: _mutated(parent.pijolBaseCost, 60, random, scale),
  perfectColumnRiskCost: _mutated(
    parent.perfectColumnRiskCost,
    160,
    random,
    scale,
  ),
  schoolBonusProgressWeight: _mutated(
    parent.schoolBonusProgressWeight,
    5,
    random,
    scale,
  ),
  schoolCompletionValue: _mutated(
    parent.schoolCompletionValue,
    40,
    random,
    scale,
  ),
  pijolGroupCosts: {
    for (final group in PijolFigureGroup.values)
      group: _mutated(parent.pijolGroupCosts[group] ?? 0, 100, random, scale),
  },
);

double _mutated(double value, double maximum, Random random, double scale) {
  final delta = (random.nextDouble() * 2 - 1) * maximum * scale;
  return (value + delta).clamp(0, maximum).toDouble();
}

double _jsonDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is! num) {
    throw FormatException('$key must be a number.');
  }
  return value.toDouble();
}
