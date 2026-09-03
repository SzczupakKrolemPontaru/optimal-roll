import 'dart:math';

import '../domain/game_engine.dart';
import 'advisor_action.dart';
import 'scoring_utility.dart';

class TurnAdvisor {
  final ScoringUtility scoringUtility;

  const TurnAdvisor({this.scoringUtility = const ScoringUtility()});

  AdvisorRecommendation? recommend({
    required DiceRoll dice,
    required GameState game,
    required int rollsLeft,
  }) {
    if (rollsLeft < 0 || rollsLeft > 2) {
      throw ArgumentError.value(
        rollsLeft,
        'rollsLeft',
        'The turn Advisor supports zero, one, or two remaining rolls.',
      );
    }

    final solver = _TurnSolver(game: game, scoringUtility: scoringUtility);
    final candidates = solver.rankMoves(dice, rollsLeft);
    if (candidates.isEmpty) return null;

    return AdvisorRecommendation(
      bestMove: candidates.first,
      alternatives: candidates.skip(1).take(3).toList(growable: false),
      reasons: _reasonsFor(candidates.first, game, rollsLeft),
    );
  }

  List<AdvisorReason> _reasonsFor(
    AdvisorMoveEvaluation move,
    GameState game,
    int rollsLeft,
  ) {
    final reasons = <AdvisorReason>[AdvisorReason.bestExpectedValue];
    if (move.action case ScoreAdvisorAction(:final option)) {
      if (rollsLeft > 0) reasons.add(AdvisorReason.scoreNowPreferred);
      if (option.type == ScoringOptionType.school) {
        final column = game.columns[option.columnIndex];
        final used = column.school.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length;
        if (!column.isOpen && used == SCHOOL_NEUTRAL_COUNT - 1) {
          reasons.add(AdvisorReason.opensFigureColumn);
        }
      }
      if (option.type == ScoringOptionType.figure &&
          option.figure != Figure.CHANCE &&
          game.columns.any(
            (column) =>
                column.isOpen &&
                column.figures[Figure.CHANCE]!.status == FieldStatus.EMPTY,
          )) {
        reasons.add(AdvisorReason.protectsChance);
      }
    }
    if (move.pijolRisk < .1) reasons.add(AdvisorReason.reducesPijolRisk);
    return List.unmodifiable(reasons);
  }
}

class _TurnSolver {
  final GameState game;
  final ScoringUtility scoringUtility;
  final Map<String, _StateValue> _bestStateCache = {};
  final Map<String, List<AdvisorMoveEvaluation>> _scoringMovesCache = {};
  final Map<String, List<List<int>>> _keepSelectionsCache = {};
  final Map<int, List<_RollOutcome>> _rollOutcomesCache = {};

  _TurnSolver({required this.game, required this.scoringUtility});

  List<AdvisorMoveEvaluation> rankMoves(DiceRoll dice, int rollsLeft) {
    final counts = dice.counts;
    final candidates = [..._rankScoringMoves(counts)];
    if (rollsLeft > 0) {
      for (final keptCounts in _keepSelections(counts)) {
        candidates.add(
          _evaluateReroll(
            dice: dice,
            keptCounts: keptCounts,
            rollsLeft: rollsLeft,
          ),
        );
      }
    }
    candidates.sort(_compareMoves);
    return candidates;
  }

  AdvisorMoveEvaluation _evaluateReroll({
    required DiceRoll dice,
    required List<int> keptCounts,
    required int rollsLeft,
  }) {
    final keptIndices = _indicesForKeptCounts(dice, keptCounts);
    final keptIndexSet = keptIndices.toSet();
    final rerolledIndices = [
      for (var index = 0; index < DICE_COUNT; index++)
        if (!keptIndexSet.contains(index)) index,
    ];

    var expectedPoints = 0.0;
    var expectedStrategicValue = 0.0;
    var pijolRisk = 0.0;
    final targetProbabilities = <String, _TargetAccumulator>{};
    for (final outcome in _rollOutcomes(rerolledIndices.length)) {
      final nextCounts = [
        for (var face = 0; face < MAX_DIE_VALUE; face++)
          keptCounts[face] + outcome.counts[face],
      ];
      final nextState = _bestState(nextCounts, rollsLeft - 1);
      expectedPoints += outcome.probability * nextState.expectedTurnScore;
      expectedStrategicValue += outcome.probability * nextState.strategicValue;
      pijolRisk += outcome.probability * nextState.pijolRisk;
      for (final target in nextState.likelyTargets) {
        final accumulator = targetProbabilities.putIfAbsent(
          target.identity,
          () => _TargetAccumulator(target),
        );
        accumulator.probability += outcome.probability * target.probability;
      }
    }

    return AdvisorMoveEvaluation(
      action: RerollAdvisorAction(
        keptDieIndices: List.unmodifiable(keptIndices),
        rerolledDieIndices: List.unmodifiable(rerolledIndices),
      ),
      expectedTurnScore: expectedPoints,
      strategicValue: expectedStrategicValue,
      pijolRisk: pijolRisk,
      likelyTargets: _sortedTargets(targetProbabilities.values),
    );
  }

  _StateValue _bestState(List<int> counts, int rollsLeft) {
    final key = '$rollsLeft:${counts.join(',')}';
    final cached = _bestStateCache[key];
    if (cached != null) return cached;

    final dice = _diceFromCounts(counts);
    final bestMove = rankMoves(dice, rollsLeft).first;
    final result = _StateValue(
      expectedTurnScore: bestMove.expectedTurnScore,
      strategicValue: bestMove.strategicValue,
      pijolRisk: bestMove.pijolRisk,
      likelyTargets: bestMove.likelyTargets,
    );
    _bestStateCache[key] = result;
    return result;
  }

  List<AdvisorMoveEvaluation> _rankScoringMoves(List<int> counts) {
    final key = counts.join(',');
    return _scoringMovesCache.putIfAbsent(key, () {
      final dice = _diceFromCounts(counts);
      final moves = [
        for (final option in legalOptions(dice, game))
          AdvisorMoveEvaluation(
            action: ScoreAdvisorAction(option),
            expectedTurnScore: option.points.toDouble(),
            strategicValue: scoringUtility.evaluate(option, game),
            pijolRisk: option.type == ScoringOptionType.pijol ? 1 : 0,
            likelyTargets: [AdvisorTarget.fromOption(option, probability: 1)],
          ),
      ];
      moves.sort(_compareMoves);
      return moves;
    });
  }

  List<List<int>> _keepSelections(List<int> diceCounts) {
    final key = diceCounts.join(',');
    return _keepSelectionsCache.putIfAbsent(key, () {
      final selections = <List<int>>[];
      final current = List.filled(MAX_DIE_VALUE, 0);

      void visit(int faceIndex, int keptCount) {
        if (faceIndex == MAX_DIE_VALUE) {
          if (keptCount < DICE_COUNT) {
            selections.add(List.unmodifiable([...current]));
          }
          return;
        }
        for (var count = 0; count <= diceCounts[faceIndex]; count++) {
          current[faceIndex] = count;
          visit(faceIndex + 1, keptCount + count);
        }
      }

      visit(0, 0);
      return selections;
    });
  }

  List<_RollOutcome> _rollOutcomes(int diceCount) => _rollOutcomesCache
      .putIfAbsent(diceCount, () => _generateRollOutcomes(diceCount));

  List<_RollOutcome> _generateRollOutcomes(int diceCount) {
    final outcomes = <_RollOutcome>[];
    final counts = List.filled(MAX_DIE_VALUE, 0);
    final denominator = pow(MAX_DIE_VALUE, diceCount).toDouble();

    void visit(int faceIndex, int remaining) {
      if (faceIndex == MAX_DIE_VALUE - 1) {
        counts[faceIndex] = remaining;
        var permutations = _factorial(diceCount);
        for (final count in counts) {
          permutations ~/= _factorial(count);
        }
        outcomes.add(
          _RollOutcome(
            counts: List.unmodifiable([...counts]),
            probability: permutations / denominator,
          ),
        );
        return;
      }
      for (var count = 0; count <= remaining; count++) {
        counts[faceIndex] = count;
        visit(faceIndex + 1, remaining - count);
      }
    }

    visit(0, diceCount);
    return outcomes;
  }

  List<int> _indicesForKeptCounts(DiceRoll dice, List<int> keptCounts) {
    final remaining = [...keptCounts];
    final indices = <int>[];
    for (var index = 0; index < dice.values.length; index++) {
      final faceIndex = dice.values[index] - MIN_DIE_VALUE;
      if (remaining[faceIndex] > 0) {
        indices.add(index);
        remaining[faceIndex]--;
      }
    }
    return indices;
  }

  DiceRoll _diceFromCounts(List<int> counts) => DiceRoll([
    for (var faceIndex = 0; faceIndex < counts.length; faceIndex++)
      for (var count = 0; count < counts[faceIndex]; count++)
        faceIndex + MIN_DIE_VALUE,
  ]);

  List<AdvisorTarget> _sortedTargets(
    Iterable<_TargetAccumulator> accumulators,
  ) {
    final targets = [
      for (final accumulator in accumulators)
        AdvisorTarget(
          type: accumulator.target.type,
          figure: accumulator.target.figure,
          schoolFace: accumulator.target.schoolFace,
          probability: accumulator.probability,
        ),
    ]..sort((left, right) => right.probability.compareTo(left.probability));
    return List.unmodifiable(targets);
  }
}

class _StateValue {
  final double expectedTurnScore;
  final double strategicValue;
  final double pijolRisk;
  final List<AdvisorTarget> likelyTargets;

  const _StateValue({
    required this.expectedTurnScore,
    required this.strategicValue,
    required this.pijolRisk,
    required this.likelyTargets,
  });
}

class _TargetAccumulator {
  final AdvisorTarget target;
  double probability = 0;

  _TargetAccumulator(this.target);
}

class _RollOutcome {
  final List<int> counts;
  final double probability;

  const _RollOutcome({required this.counts, required this.probability});
}

int _factorial(int value) {
  var result = 1;
  for (var factor = 2; factor <= value; factor++) {
    result *= factor;
  }
  return result;
}

int _compareMoves(AdvisorMoveEvaluation left, AdvisorMoveEvaluation right) {
  final strategic = right.strategicValue.compareTo(left.strategicValue);
  if (strategic != 0) return strategic;
  final points = right.expectedTurnScore.compareTo(left.expectedTurnScore);
  if (points != 0) return points;
  final risk = left.pijolRisk.compareTo(right.pijolRisk);
  if (risk != 0) return risk;

  if (left.action is ScoreAdvisorAction &&
      right.action is RerollAdvisorAction) {
    return -1;
  }
  if (left.action is RerollAdvisorAction &&
      right.action is ScoreAdvisorAction) {
    return 1;
  }
  if (left.action case RerollAdvisorAction(:final rerolledDieIndices)) {
    final rightReroll = right.action as RerollAdvisorAction;
    final rerolled = rerolledDieIndices.length.compareTo(
      rightReroll.rerolledDieIndices.length,
    );
    if (rerolled != 0) return rerolled;
    return rerolledDieIndices
        .join(',')
        .compareTo(rightReroll.rerolledDieIndices.join(','));
  }

  final leftOption = (left.action as ScoreAdvisorAction).option;
  final rightOption = (right.action as ScoreAdvisorAction).option;
  final column = leftOption.columnIndex.compareTo(rightOption.columnIndex);
  if (column != 0) return column;
  final type = leftOption.type.index.compareTo(rightOption.type.index);
  if (type != 0) return type;
  final school = (leftOption.schoolFace ?? 0).compareTo(
    rightOption.schoolFace ?? 0,
  );
  if (school != 0) return school;
  return (leftOption.figure?.index ?? 0).compareTo(
    rightOption.figure?.index ?? 0,
  );
}
