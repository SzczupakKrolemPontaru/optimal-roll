import 'dart:math';

import 'simulation_result.dart';

class SimulationReport {
  final String strategyName;
  final List<SimulationGameResult> games;
  final Duration elapsed;

  const SimulationReport({
    required this.strategyName,
    required this.games,
    required this.elapsed,
  });

  int get gameCount => games.length;
  double get gamesPerSecond => elapsed.inMicroseconds == 0
      ? 0
      : gameCount * 1000000 / elapsed.inMicroseconds;

  ScoreStatistics get totalScore =>
      ScoreStatistics.from(games.map((game) => game.totalScore));
  ScoreStatistics get rawSchoolScore =>
      ScoreStatistics.from(games.map((game) => game.rawSchoolScore));
  ScoreStatistics get schoolBonus =>
      ScoreStatistics.from(games.map((game) => game.schoolBonus));
  ScoreStatistics get figureScore =>
      ScoreStatistics.from(games.map((game) => game.figureScore));
  ScoreStatistics get perfectColumnBonus =>
      ScoreStatistics.from(games.map((game) => game.perfectColumnBonus));
  ScoreStatistics get pijolCount =>
      ScoreStatistics.from(games.map((game) => game.pijolCount));
  ScoreStatistics get perfectColumnCount =>
      ScoreStatistics.from(games.map((game) => game.perfectColumnCount));
  ScoreStatistics get rollsMade =>
      ScoreStatistics.from(games.map((game) => game.rollsMade));
  ScoreStatistics get figuresScoredFromHand =>
      ScoreStatistics.from(games.map((game) => game.figuresScoredFromHand));

  List<int> get turnsByRollCount => [
    for (var index = 0; index < 3; index++)
      games.fold(0, (sum, game) => sum + game.turnsByRollCount[index]),
  ];

  Map<String, int> get scoreTypeCounts {
    final counts = <String, int>{};
    for (final game in games) {
      for (final entry in game.scoreTypeCounts.entries) {
        counts[entry.key] = (counts[entry.key] ?? 0) + entry.value;
      }
    }
    return counts;
  }

  Map<String, Object> toJson({bool includeGames = false}) => {
    'strategy': strategyName,
    'gameCount': gameCount,
    'elapsedMilliseconds': elapsed.inMilliseconds,
    'gamesPerSecond': gamesPerSecond,
    'metrics': {
      'totalScore': totalScore.toJson(),
      'rawSchoolScore': rawSchoolScore.toJson(),
      'schoolBonus': schoolBonus.toJson(),
      'figureScore': figureScore.toJson(),
      'perfectColumnBonus': perfectColumnBonus.toJson(),
      'pijolCount': pijolCount.toJson(),
      'perfectColumnCount': perfectColumnCount.toJson(),
      'rollsMade': rollsMade.toJson(),
      'figuresScoredFromHand': figuresScoredFromHand.toJson(),
      'turnsByRollCount': turnsByRollCount,
      'scoreTypeCounts': scoreTypeCounts,
    },
    if (includeGames) 'games': games.map((game) => game.toJson()).toList(),
  };
}

class ScoreStatistics {
  final double mean;
  final double median;
  final double standardDeviation;
  final int minimum;
  final int maximum;
  final int p10;
  final int p90;

  const ScoreStatistics({
    required this.mean,
    required this.median,
    required this.standardDeviation,
    required this.minimum,
    required this.maximum,
    required this.p10,
    required this.p90,
  });

  factory ScoreStatistics.from(Iterable<int> input) {
    final values = input.toList()..sort();
    if (values.isEmpty) {
      throw ArgumentError('At least one value is required.');
    }
    final mean = values.reduce((left, right) => left + right) / values.length;
    final variance =
        values.fold<double>(0, (sum, value) => sum + pow(value - mean, 2)) /
        values.length;
    final middle = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[middle].toDouble()
        : (values[middle - 1] + values[middle]) / 2;
    return ScoreStatistics(
      mean: mean,
      median: median,
      standardDeviation: sqrt(variance),
      minimum: values.first,
      maximum: values.last,
      p10: _percentile(values, .10),
      p90: _percentile(values, .90),
    );
  }

  Map<String, Object> toJson() => {
    'mean': mean,
    'median': median,
    'standardDeviation': standardDeviation,
    'minimum': minimum,
    'maximum': maximum,
    'p10': p10,
    'p90': p90,
  };
}

class StrategyComparison {
  final SimulationReport candidate;
  final SimulationReport baseline;
  final ScoreStatistics scoreDifference;
  final double winRate;
  final double tieRate;
  final double confidence95HalfWidth;

  factory StrategyComparison({
    required SimulationReport candidate,
    required SimulationReport baseline,
  }) {
    if (candidate.gameCount != baseline.gameCount ||
        !_sameSeeds(candidate.games, baseline.games)) {
      throw ArgumentError(
        'Compared reports must contain the same game seeds in the same order.',
      );
    }
    return StrategyComparison._(candidate: candidate, baseline: baseline);
  }

  StrategyComparison._({required this.candidate, required this.baseline})
    : scoreDifference = ScoreStatistics.from([
        for (var index = 0; index < candidate.gameCount; index++)
          candidate.games[index].totalScore - baseline.games[index].totalScore,
      ]),
      winRate = _rate(
        candidate.games,
        baseline.games,
        (difference) => difference > 0,
      ),
      tieRate = _rate(
        candidate.games,
        baseline.games,
        (difference) => difference == 0,
      ),
      confidence95HalfWidth = _confidence95(candidate.games, baseline.games);

  Map<String, Object> toJson() => {
    'candidate': candidate.strategyName,
    'baseline': baseline.strategyName,
    'scoreDifference': scoreDifference.toJson(),
    'winRate': winRate,
    'tieRate': tieRate,
    'confidence95HalfWidth': confidence95HalfWidth,
  };
}

int _percentile(List<int> sortedValues, double percentile) {
  final index = ((sortedValues.length - 1) * percentile).round();
  return sortedValues[index];
}

bool _sameSeeds(
  List<SimulationGameResult> left,
  List<SimulationGameResult> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].seed != right[index].seed) return false;
  }
  return true;
}

double _rate(
  List<SimulationGameResult> candidate,
  List<SimulationGameResult> baseline,
  bool Function(int difference) accepts,
) {
  var matches = 0;
  for (var index = 0; index < candidate.length; index++) {
    if (accepts(candidate[index].totalScore - baseline[index].totalScore)) {
      matches++;
    }
  }
  return matches / candidate.length;
}

double _confidence95(
  List<SimulationGameResult> candidate,
  List<SimulationGameResult> baseline,
) {
  final differences = [
    for (var index = 0; index < candidate.length; index++)
      candidate[index].totalScore - baseline[index].totalScore,
  ];
  final statistics = ScoreStatistics.from(differences);
  return 1.96 * statistics.standardDeviation / sqrt(differences.length);
}
