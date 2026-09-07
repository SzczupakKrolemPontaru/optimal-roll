// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/simulation/simulation.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    _printHelp();
    return;
  }

  final strategy = options.weightsPath == null
      ? switch (options.profile) {
          'default' => const AdvisorGameStrategy(),
          'rollout' => RolloutAdvisorGameStrategy(
            samples: options.rolloutSamples,
            horizon: options.rolloutHorizon,
            lateGameThreshold: options.rolloutLateThreshold,
            closeDecisionThreshold: options.rolloutCloseThreshold,
            fastFuture: true,
          ),
          'lookahead' => const RolloutAdvisorGameStrategy(
            name: 'exact-lookahead',
            exactFuture: true,
            lateGameThreshold: .8,
          ),
          'policy' => AdvisorGameStrategy(
            name: 'policy-bias',
            scoreNowBiasEarly: options.scoreNowBiasEarly,
            scoreNowBiasLate: options.scoreNowBiasLate,
          ),
          'state-model' => const AdvisorGameStrategy(
            name: 'state-model',
            advisor: TurnAdvisor(
              scoringUtility: ScoringUtility(
                stateValueModel: StateValueModel.trained,
                stateValueWeight: .1,
              ),
            ),
          ),
          'action-model' => const AdvisorGameStrategy(
            name: 'action-model',
            advisor: TurnAdvisor(
              scoringUtility: ScoringUtility(
                actionValueModel: ActionValueModel.trained200,
                actionValueWeight: .05,
              ),
            ),
          ),
          'phased-model' => const AdvisorGameStrategy(
            name: 'phased-model',
            advisor: TurnAdvisor(
              scoringUtility: ScoringUtility(
                phasedActionValueModel: PhasedActionValueModel.trainedPhased500,
                actionValueWeight: .05,
              ),
            ),
          ),
          'greedy' => AdvisorGameStrategy.greedy(),
          'turn-score-only' => AdvisorGameStrategy.turnScoreOnly(),
          _ => throw FormatException('Unknown profile: ${options.profile}'),
        }
      : _loadStrategy(options.weightsPath!);
  const runner = SimulationRunner();
  final report = await runner.runParallel(
    strategy: strategy,
    gameCount: options.games,
    firstSeed: options.seed,
    workers: options.workers,
  );

  final comparisons = <StrategyComparison>[];
  if (options.compareBaseline &&
      strategy.name != 'turn-score-only' &&
      strategy.name != 'greedy') {
    final baseline = await runner.runParallel(
      strategy: AdvisorGameStrategy.greedy(),
      gameCount: options.games,
      firstSeed: options.seed,
      workers: options.workers,
    );
    comparisons.add(StrategyComparison(candidate: report, baseline: baseline));
  }
  if (options.compareDefault && strategy.name != 'default') {
    final baseline = await runner.runParallel(
      strategy: const AdvisorGameStrategy(),
      gameCount: options.games,
      firstSeed: options.seed,
      workers: options.workers,
    );
    comparisons.add(StrategyComparison(candidate: report, baseline: baseline));
  }

  if (options.json) {
    print(
      const JsonEncoder.withIndent('  ').convert({
        'report': report.toJson(includeGames: options.includeGames),
        if (comparisons.isNotEmpty)
          'comparisons': comparisons
              .map((comparison) => comparison.toJson())
              .toList(),
      }),
    );
  } else {
    _printReport(report);
    if (options.includeGames) {
      print('Scores by seed:');
      for (final game in report.games) {
        print('${game.seed}: ${game.totalScore}');
      }
    }
    for (final comparison in comparisons) {
      _printComparison(comparison);
    }
  }
}

GameStrategy _loadStrategy(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('A weight profile must be a JSON object.');
  }
  final json = Map<String, dynamic>.from(decoded);
  final candidate = AdvisorWeightCandidate.fromJson(json);
  final profileName = json['profileName']?.toString() ?? 'custom-weights';
  return AdvisorGameStrategy.withWeights(
    name: profileName,
    weights: candidate.weights,
  );
}

void _printReport(SimulationReport report) {
  final score = report.totalScore;
  print('Strategy: ${report.strategyName}');
  print('Games: ${report.gameCount}');
  print(
    'Elapsed: ${(report.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s',
  );
  print('Games/s: ${report.gamesPerSecond.toStringAsFixed(2)}');
  print(
    'Score mean/median: ${score.mean.toStringAsFixed(2)} / '
    '${score.median.toStringAsFixed(2)}',
  );
  print(
    'Score min/p10/p90/max: ${score.minimum} / ${score.p10} / ${score.p90} / ${score.maximum}',
  );
  print('School raw: ${report.rawSchoolScore.mean.toStringAsFixed(2)}');
  print('School bonus: ${report.schoolBonus.mean.toStringAsFixed(2)}');
  print('Figures: ${report.figureScore.mean.toStringAsFixed(2)}');
  print(
    'Perfect-column bonus: '
    '${report.perfectColumnBonus.mean.toStringAsFixed(2)}',
  );
  print('Pijols: ${report.pijolCount.mean.toStringAsFixed(2)}');
  print(
    'Figures from hand: '
    '${report.figuresScoredFromHand.mean.toStringAsFixed(2)}',
  );
  print('Rolls per game: ${report.rollsMade.mean.toStringAsFixed(2)}');
  print('Score distribution (100-point buckets):');
  for (final entry in report.scoreDistribution.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
}

void _printComparison(StrategyComparison comparison) {
  print('');
  print(
    'Compared with ${comparison.baseline.strategyName}: '
    '${comparison.scoreDifference.mean >= 0 ? '+' : ''}'
    '${comparison.scoreDifference.mean.toStringAsFixed(2)} points',
  );
  print(
    '95% confidence interval half-width: '
    '${comparison.confidence95HalfWidth.toStringAsFixed(2)}',
  );
  print('Win rate: ${(comparison.winRate * 100).toStringAsFixed(1)}%');
  print('Tie rate: ${(comparison.tieRate * 100).toStringAsFixed(1)}%');
}

void _printHelp() {
  print('''
Simulate complete OptimalRoll games.

Usage:
  dart run tool/simulate_games.dart [options]

Options:
  --games <count>       Number of games (default: 1)
  --seed <value>        First deterministic game seed (default: 1)
  --profile <name>      default | rollout | lookahead | policy | state-model | action-model | phased-model | greedy | turn-score-only (default: default)
  --score-now-bias-early <x>  Policy profile score-now bias in first phase
  --score-now-bias-late <x>   Policy profile score-now bias in final phase
  --weights <path>      Load weights from an optimizer JSON result
  --workers <count>     Parallel isolates (default: 1)
  --compare-baseline    Compare against greedy on the same seeds
  --compare-default     Compare against current default weights
  --include-games       Print every seed and score (also includes them in --json)
  --rollout-samples <n> Number of rollout samples (default: 4)
  --rollout-horizon <n> Future turns simulated (default: 1)
  --rollout-late-threshold <x> Fraction of card filled before rollouts (default: 0.8)
  --rollout-close-threshold <x> Strategic-value gap for rollout (default: 4)
  --json                Print machine-readable JSON
  --help                Show this help
''');
}

class _Options {
  final int games;
  final int seed;
  final String profile;
  final String? weightsPath;
  final int workers;
  final bool compareBaseline;
  final bool compareDefault;
  final bool includeGames;
  final bool json;
  final bool showHelp;
  final int rolloutSamples;
  final int rolloutHorizon;
  final double rolloutLateThreshold;
  final double rolloutCloseThreshold;
  final double scoreNowBiasEarly;
  final double scoreNowBiasLate;

  const _Options({
    required this.games,
    required this.seed,
    required this.profile,
    required this.weightsPath,
    required this.workers,
    required this.compareBaseline,
    required this.compareDefault,
    required this.includeGames,
    required this.json,
    required this.showHelp,
    required this.rolloutSamples,
    required this.rolloutHorizon,
    required this.rolloutLateThreshold,
    required this.rolloutCloseThreshold,
    required this.scoreNowBiasEarly,
    required this.scoreNowBiasLate,
  });

  factory _Options.parse(List<String> arguments) {
    var games = 1;
    var seed = 1;
    var profile = 'default';
    String? weightsPath;
    // Simulation is CPU-bound; use a small parallel default so large
    // validation runs do not accidentally execute in one isolate.
    var workers = 8;
    var compareBaseline = false;
    var compareDefault = false;
    var includeGames = false;
    var json = false;
    var showHelp = false;
    var rolloutSamples = 4;
    var rolloutHorizon = 1;
    var rolloutLateThreshold = .8;
    var rolloutCloseThreshold = 4.0;
    var scoreNowBiasEarly = 0.0;
    var scoreNowBiasLate = 0.0;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--games':
          games = int.parse(_nextValue(arguments, ++index, argument));
        case '--seed':
          seed = int.parse(_nextValue(arguments, ++index, argument));
        case '--profile':
          profile = _nextValue(arguments, ++index, argument);
        case '--weights':
          weightsPath = _nextValue(arguments, ++index, argument);
        case '--workers':
          workers = int.parse(_nextValue(arguments, ++index, argument));
        case '--compare-baseline':
          compareBaseline = true;
        case '--compare-default':
          compareDefault = true;
        case '--include-games':
          includeGames = true;
        case '--json':
          json = true;
        case '--rollout-samples':
          rolloutSamples = int.parse(_nextValue(arguments, ++index, argument));
        case '--rollout-horizon':
          rolloutHorizon = int.parse(_nextValue(arguments, ++index, argument));
        case '--rollout-late-threshold':
          rolloutLateThreshold = double.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--rollout-close-threshold':
          rolloutCloseThreshold = double.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--score-now-bias-early':
          scoreNowBiasEarly = double.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--score-now-bias-late':
          scoreNowBiasLate = double.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--help' || '-h':
          showHelp = true;
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }
    if (games <= 0 ||
        workers <= 0 ||
        rolloutSamples <= 0 ||
        rolloutHorizon <= 0 ||
        rolloutLateThreshold < 0 ||
        rolloutLateThreshold > 1 ||
        rolloutCloseThreshold < 0) {
      throw FormatException('--games and --workers must be positive.');
    }
    return _Options(
      games: games,
      seed: seed,
      profile: profile,
      weightsPath: weightsPath,
      workers: workers,
      compareBaseline: compareBaseline,
      compareDefault: compareDefault,
      includeGames: includeGames,
      json: json,
      showHelp: showHelp,
      rolloutSamples: rolloutSamples,
      rolloutHorizon: rolloutHorizon,
      rolloutLateThreshold: rolloutLateThreshold,
      rolloutCloseThreshold: rolloutCloseThreshold,
      scoreNowBiasEarly: scoreNowBiasEarly,
      scoreNowBiasLate: scoreNowBiasLate,
    );
  }
}

String _nextValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length) {
    throw FormatException('$option requires a value.');
  }
  return arguments[index];
}
