import 'dart:math';

import '../domain/game_engine.dart';
import 'advisor_action.dart';
import 'scoring_utility.dart';

class TurnAdvisor {
  final ScoringUtility scoringUtility;

  const TurnAdvisor({this.scoringUtility = const ScoringUtility()});

  AdvisorTurnSession startTurn(
    GameState game, {
    double scoreNowBiasEarly = 0,
    double scoreNowBiasLate = 0,
  }) => AdvisorTurnSession._(
    _TurnSolver(
      game: game,
      scoringUtility: scoringUtility,
      scoreNowBiasEarly: scoreNowBiasEarly,
      scoreNowBiasLate: scoreNowBiasLate,
    ),
  );

  AdvisorAction? chooseBestAction({
    required DiceRoll dice,
    required GameState game,
    required int rollsLeft,
  }) => startTurn(game).chooseBestAction(dice: dice, rollsLeft: rollsLeft);

  /// Exact expected score of the next complete turn from this scorecard.
  ///
  /// The calculation enumerates dice-count outcomes, not ordered dice rolls,
  /// so there are only 462 outcomes for six dice. It is intended for offline
  /// lookahead decisions, not for every UI recommendation.
  double expectedTurnScore(GameState game) =>
      startTurn(game)._solver.expectedTurnScore();

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

    final solver = startTurn(game)._solver;
    final candidates = solver.rankMoves(
      dice,
      rollsLeft,
      figuresFromHand: rollsLeft == 2,
    );
    if (candidates.isEmpty) return null;

    final bestMove = solver.withLikelyTargets(
      candidates.first,
      dice,
      rollsLeft,
    );
    return AdvisorRecommendation(
      bestMove: bestMove,
      alternatives: candidates.skip(1).take(3).toList(growable: false),
      reasons: _reasonsFor(bestMove, game, rollsLeft),
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

/// Reuses the expensive dynamic-programming cache while the scorecard remains
/// unchanged during a single turn.
class AdvisorTurnSession {
  final _TurnSolver _solver;

  AdvisorTurnSession._(this._solver);

  AdvisorAction? chooseBestAction({
    required DiceRoll dice,
    required int rollsLeft,
  }) {
    _validateRollsLeft(rollsLeft);
    return _solver
        .bestMove(dice, rollsLeft, figuresFromHand: rollsLeft == 2)
        ?.action;
  }
}

class _TurnSolver {
  final GameState game;
  final ScoringUtility scoringUtility;
  final double scoreNowBiasEarly;
  final double scoreNowBiasLate;
  final Map<int, _SolvedState> _solvedStateCache = {};
  final Map<int, List<AdvisorMoveEvaluation>> _scoringMovesCache = {};
  final Map<int, AdvisorMoveEvaluation> _bestScoringMoveCache = {};
  final Map<int, _StateValue> _rerollValueCache = {};
  final Map<int, List<AdvisorTarget>> _targetDistributionCache = {};
  final Map<int, double> _strategicValueCache = {};

  _TurnSolver({
    required this.game,
    required this.scoringUtility,
    required this.scoreNowBiasEarly,
    required this.scoreNowBiasLate,
  });

  double expectedTurnScore() {
    if (game.isComplete) return 0;
    var expected = 0.0;
    for (final outcome in _rollOutcomes(DICE_COUNT)) {
      expected +=
          outcome.probability *
          _solveState(outcome.counts, 2).value.expectedTurnScore;
    }
    return expected;
  }

  List<AdvisorMoveEvaluation> rankMoves(
    DiceRoll dice,
    int rollsLeft, {
    bool figuresFromHand = false,
  }) {
    final counts = dice.counts;
    final candidates = [
      ..._rankScoringMoves(counts, figuresFromHand: figuresFromHand),
    ];
    if (rollsLeft > 0) {
      for (final keptCounts in _keepSelections(counts)) {
        candidates.add(
          _rerollMove(dice: dice, keptCounts: keptCounts, rollsLeft: rollsLeft),
        );
      }
    }
    candidates.sort(_compareMoves);
    return candidates;
  }

  AdvisorMoveEvaluation? bestMove(
    DiceRoll dice,
    int rollsLeft, {
    bool figuresFromHand = false,
  }) {
    final counts = dice.counts;
    AdvisorMoveEvaluation? best = _bestScoringMove(
      counts,
      figuresFromHand: figuresFromHand,
    );

    if (rollsLeft > 0) {
      for (final keptCounts in _keepSelections(counts)) {
        final candidate = _rerollMove(
          dice: dice,
          keptCounts: keptCounts,
          rollsLeft: rollsLeft,
        );
        if (best == null || _compareMoves(candidate, best) < 0) {
          best = candidate;
        }
      }
    }
    return best;
  }

  AdvisorMoveEvaluation withLikelyTargets(
    AdvisorMoveEvaluation move,
    DiceRoll dice,
    int rollsLeft,
  ) {
    final targets = switch (move.action) {
      ScoreAdvisorAction(:final option) => [
        AdvisorTarget.fromOption(option, probability: 1),
      ],
      RerollAdvisorAction(:final keptDieIndices) => _targetsAfterReroll(
        _keptCountsFromIndices(dice, keptDieIndices),
        rollsLeft,
      ),
    };
    return AdvisorMoveEvaluation(
      action: move.action,
      expectedTurnScore: move.expectedTurnScore,
      strategicValue: move.strategicValue,
      pijolRisk: move.pijolRisk,
      pijolColumnFilled: move.pijolColumnFilled,
      likelyTargets: targets,
    );
  }

  AdvisorMoveEvaluation _rerollMove({
    required DiceRoll dice,
    required List<int> keptCounts,
    required int rollsLeft,
  }) {
    final value = _rerollValue(keptCounts, rollsLeft);
    final keptIndices = _indicesForKeptCounts(dice, keptCounts);
    final keptIndexSet = keptIndices.toSet();
    return AdvisorMoveEvaluation(
      action: RerollAdvisorAction(
        keptDieIndices: List.unmodifiable(keptIndices),
        rerolledDieIndices: List.unmodifiable([
          for (var index = 0; index < DICE_COUNT; index++)
            if (!keptIndexSet.contains(index)) index,
        ]),
      ),
      expectedTurnScore: value.expectedTurnScore,
      strategicValue: value.strategicValue,
      pijolRisk: value.pijolRisk,
    );
  }

  _StateValue _rerollValue(List<int> keptCounts, int rollsLeft) {
    final cacheKey = _stateKey(keptCounts, rollsLeft);
    final cached = _rerollValueCache[cacheKey];
    if (cached != null) return cached;

    final rerolledCount = DICE_COUNT - _sum(keptCounts);
    var expectedPoints = 0.0;
    var expectedStrategicValue = 0.0;
    var pijolRisk = 0.0;
    for (final outcome in _rollOutcomes(rerolledCount)) {
      final nextCounts = _combineCounts(keptCounts, outcome.counts);
      final nextState = _solveState(nextCounts, rollsLeft - 1).value;
      expectedPoints += outcome.probability * nextState.expectedTurnScore;
      expectedStrategicValue += outcome.probability * nextState.strategicValue;
      pijolRisk += outcome.probability * nextState.pijolRisk;
    }
    if (scoringUtility.rerollValueModel != null &&
        scoringUtility.rerollModelWeight != 0) {
      expectedStrategicValue +=
          scoringUtility.rerollModelWeight *
          scoringUtility.rerollValueModel!.evaluateActionAdvantage(
            game,
            keptCounts,
            rollsLeft,
          );
    }
    final result = _StateValue(
      expectedTurnScore: expectedPoints,
      strategicValue:
          expectedStrategicValue +
          scoringUtility.weights.rerollValueWeight * rollsLeft +
          scoringUtility.weights.rerollLowScoreWeight *
              ((40 - expectedPoints) / 40).clamp(0.0, 1.0) *
              rollsLeft +
          scoringUtility.weights.rareFigureChaseWeight *
              _rareFigureChasePotential(keptCounts, rollsLeft) +
          scoringUtility.weights.straightChaseWeight *
              _straightChasePotential(keptCounts, rollsLeft),
      pijolRisk: pijolRisk,
    );
    _rerollValueCache[cacheKey] = result;
    return result;
  }

  _SolvedState _solveState(List<int> counts, int rollsLeft) {
    final key = _stateKey(counts, rollsLeft);
    final cached = _solvedStateCache[key];
    if (cached != null) return cached;

    final scoringMove = _bestScoringMove(counts)!;
    var best = _StateValue.fromMove(scoringMove);
    _StatePolicy bestPolicy = _ScorePolicy(
      (scoringMove.action as ScoreAdvisorAction).option,
    );

    if (rollsLeft > 0) {
      for (final keptCounts in _keepSelections(counts)) {
        final candidate = _rerollValue(keptCounts, rollsLeft);
        if (_compareValues(candidate, best) < 0) {
          best = candidate;
          bestPolicy = _RerollPolicy(keptCounts);
        }
      }
    }

    final result = _SolvedState(value: best, policy: bestPolicy);
    _solvedStateCache[key] = result;
    return result;
  }

  List<AdvisorMoveEvaluation> _rankScoringMoves(
    List<int> counts, {
    bool figuresFromHand = false,
  }) {
    final key = _countsKey(counts) * 2 + (figuresFromHand ? 1 : 0);
    return _scoringMovesCache.putIfAbsent(key, () {
      final dice = _diceFromCounts(counts);
      final moves = [
        for (final option in legalOptions(
          dice,
          game,
          figuresFromHand: figuresFromHand,
        ))
          AdvisorMoveEvaluation(
            action: ScoreAdvisorAction(option),
            expectedTurnScore: option.points.toDouble(),
            strategicValue: _strategicValue(option),
            pijolRisk: option.type == ScoringOptionType.pijol ? 1 : 0,
            pijolColumnFilled: _pijolColumnFilled(option),
          ),
      ];
      moves.sort(_compareMoves);
      return moves;
    });
  }

  AdvisorMoveEvaluation? _bestScoringMove(
    List<int> counts, {
    bool figuresFromHand = false,
  }) {
    final key = _countsKey(counts) * 2 + (figuresFromHand ? 1 : 0);
    final cached = _bestScoringMoveCache[key];
    if (cached != null) return cached;

    final dice = _diceFromCounts(counts);
    AdvisorMoveEvaluation? best;
    for (final option in legalOptions(
      dice,
      game,
      figuresFromHand: figuresFromHand,
    )) {
      final candidate = AdvisorMoveEvaluation(
        action: ScoreAdvisorAction(option),
        expectedTurnScore: option.points.toDouble(),
        strategicValue: _strategicValue(option),
        pijolRisk: option.type == ScoringOptionType.pijol ? 1 : 0,
        pijolColumnFilled: _pijolColumnFilled(option),
      );
      if (best == null || _compareMoves(candidate, best) < 0) {
        best = candidate;
      }
    }
    if (best != null) _bestScoringMoveCache[key] = best;
    return best;
  }

  List<AdvisorTarget> _targetsForState(List<int> counts, int rollsLeft) {
    final key = _stateKey(counts, rollsLeft);
    return _targetDistributionCache.putIfAbsent(key, () {
      final solved = _solveState(counts, rollsLeft);
      return switch (solved.policy) {
        _ScorePolicy(:final option) => [
          AdvisorTarget.fromOption(option, probability: 1),
        ],
        _RerollPolicy(:final keptCounts) => _targetsAfterReroll(
          keptCounts,
          rollsLeft,
        ),
      };
    });
  }

  double _strategicValue(ScoringOption option) {
    final key = _scoringOptionKey(option);
    return _strategicValueCache.putIfAbsent(
      key,
      () => scoringUtility.evaluate(option, game) + _scoreNowBias(),
    );
  }

  double _scoreNowBias() {
    var used = 0;
    var total = 0;
    for (final column in game.columns) {
      used += column.school.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
      used += column.figures.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
      total += column.school.length + column.figures.length;
    }
    if (total == 0) return scoreNowBiasEarly;
    final progress = used / total;
    if (progress <= 1 / 3) return scoreNowBiasEarly;
    if (progress >= 2 / 3) return scoreNowBiasLate;
    final phase = (progress - 1 / 3) / (1 / 3);
    return scoreNowBiasEarly + (scoreNowBiasLate - scoreNowBiasEarly) * phase;
  }

  int _pijolColumnFilled(ScoringOption option) {
    if (option.type != ScoringOptionType.pijol) return 0;
    return game.columns[option.columnIndex].figures.values
        .where((entry) => entry.status != FieldStatus.EMPTY)
        .length;
  }

  double _rareFigureChasePotential(List<int> keptCounts, int rollsLeft) {
    final largestGroup = keptCounts.fold<int>(
      0,
      (largest, count) => count > largest ? count : largest,
    );
    if (largestGroup < 3 || rollsLeft == 0) return 0;
    return ((largestGroup - 2) / 3).clamp(0.0, 1.0) * ((rollsLeft + 1) / 3);
  }

  double _straightChasePotential(List<int> keptCounts, int rollsLeft) {
    if (rollsLeft == 0) return 0;
    final openStraightSlots = game.columns
        .where((column) => column.isOpen)
        .expand(
          (column) =>
              [
                Figure.SMALL_STRAIGHT,
                Figure.BIG_STRAIGHT,
                Figure.GREAT_STRAIGHT,
              ].where(
                (figure) => column.figures[figure]!.status == FieldStatus.EMPTY,
              ),
        )
        .length;
    if (openStraightSlots == 0) return 0;
    final small = _facesPresentInRange(keptCounts, 1, 5);
    final big = _facesPresentInRange(keptCounts, 2, 6);
    final present = max(small, big);
    if (present < 4) return 0;
    final slotFactor = (openStraightSlots / 3).clamp(0.0, 1.0);
    return ((present - 3) / 2).clamp(0.0, 1.0) *
        ((rollsLeft + 1) / 3) *
        slotFactor;
  }

  int _facesPresentInRange(List<int> counts, int first, int last) => [
    for (var face = first; face <= last; face++)
      if (counts[face - MIN_DIE_VALUE] > 0) face,
  ].length;

  List<AdvisorTarget> _targetsAfterReroll(List<int> keptCounts, int rollsLeft) {
    final accumulators = <int, _TargetAccumulator>{};
    final rerolledCount = DICE_COUNT - _sum(keptCounts);
    for (final outcome in _rollOutcomes(rerolledCount)) {
      final nextCounts = _combineCounts(keptCounts, outcome.counts);
      for (final target in _targetsForState(nextCounts, rollsLeft - 1)) {
        final accumulator = accumulators.putIfAbsent(
          target.identity,
          () => _TargetAccumulator(target),
        );
        accumulator.probability += outcome.probability * target.probability;
      }
    }
    final targets = [
      for (final accumulator in accumulators.values)
        AdvisorTarget(
          type: accumulator.target.type,
          figure: accumulator.target.figure,
          schoolFace: accumulator.target.schoolFace,
          probability: accumulator.probability,
        ),
    ]..sort((left, right) => right.probability.compareTo(left.probability));
    return List.unmodifiable(targets);
  }

  List<List<int>> _keepSelections(List<int> diceCounts) {
    final key = _countsKey(diceCounts);
    return _sharedKeepSelectionsCache.putIfAbsent(key, () {
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

  List<_RollOutcome> _rollOutcomes(int diceCount) => _sharedRollOutcomesCache
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

  List<int> _keptCountsFromIndices(DiceRoll dice, List<int> indices) {
    final counts = List.filled(MAX_DIE_VALUE, 0);
    for (final index in indices) {
      counts[dice.values[index] - MIN_DIE_VALUE]++;
    }
    return counts;
  }

  List<int> _combineCounts(List<int> left, List<int> right) => [
    for (var index = 0; index < MAX_DIE_VALUE; index++)
      left[index] + right[index],
  ];

  DiceRoll _diceFromCounts(List<int> counts) => DiceRoll([
    for (var faceIndex = 0; faceIndex < counts.length; faceIndex++)
      for (var count = 0; count < counts[faceIndex]; count++)
        faceIndex + MIN_DIE_VALUE,
  ]);
}

sealed class _StatePolicy {
  const _StatePolicy();
}

class _ScorePolicy extends _StatePolicy {
  final ScoringOption option;

  const _ScorePolicy(this.option);
}

class _RerollPolicy extends _StatePolicy {
  final List<int> keptCounts;

  const _RerollPolicy(this.keptCounts);
}

class _SolvedState {
  final _StateValue value;
  final _StatePolicy policy;

  const _SolvedState({required this.value, required this.policy});
}

class _StateValue {
  final double expectedTurnScore;
  final double strategicValue;
  final double pijolRisk;

  const _StateValue({
    required this.expectedTurnScore,
    required this.strategicValue,
    required this.pijolRisk,
  });

  factory _StateValue.fromMove(AdvisorMoveEvaluation move) => _StateValue(
    expectedTurnScore: move.expectedTurnScore,
    strategicValue: move.strategicValue,
    pijolRisk: move.pijolRisk,
  );
}

class _RollOutcome {
  final List<int> counts;
  final double probability;

  const _RollOutcome({required this.counts, required this.probability});
}

class _TargetAccumulator {
  final AdvisorTarget target;
  double probability = 0;

  _TargetAccumulator(this.target);
}

int _countsKey(List<int> counts) {
  var key = 0;
  for (final count in counts) {
    key = key * (DICE_COUNT + 1) + count;
  }
  return key;
}

int _stateKey(List<int> counts, int rollsLeft) =>
    _countsKey(counts) * 3 + rollsLeft;

int _scoringOptionKey(ScoringOption option) {
  var key = option.type.index;
  key = key * 4 + option.columnIndex;
  key = key * (Figure.values.length + 1) + (option.figure?.index ?? -1) + 1;
  key = key * (MAX_DIE_VALUE + 1) + (option.schoolFace ?? 0);
  key = key * 401 + option.points;
  return key;
}

int _sum(List<int> values) => values.fold(0, (sum, value) => sum + value);

int _factorial(int value) {
  var result = 1;
  for (var factor = 2; factor <= value; factor++) {
    result *= factor;
  }
  return result;
}

void _validateRollsLeft(int rollsLeft) {
  if (rollsLeft < 0 || rollsLeft > 2) {
    throw ArgumentError.value(
      rollsLeft,
      'rollsLeft',
      'The turn Advisor supports zero, one, or two remaining rolls.',
    );
  }
}

final Map<int, List<List<int>>> _sharedKeepSelectionsCache = {};
final Map<int, List<_RollOutcome>> _sharedRollOutcomesCache = {};

int _compareValues(_StateValue left, _StateValue right) {
  final strategic = right.strategicValue.compareTo(left.strategicValue);
  if (strategic != 0) return strategic;
  final points = right.expectedTurnScore.compareTo(left.expectedTurnScore);
  if (points != 0) return points;
  return left.pijolRisk.compareTo(right.pijolRisk);
}

int _compareMoves(AdvisorMoveEvaluation left, AdvisorMoveEvaluation right) {
  final values = _compareValues(
    _StateValue.fromMove(left),
    _StateValue.fromMove(right),
  );
  if (values != 0) {
    // Pijol should normally go to the least-filled figure column when the
    // strategic difference is small.  Requiring an exact tie made this rule
    // practically invisible because future-field terms differ by fractions.
    if (left.action is ScoreAdvisorAction &&
        right.action is ScoreAdvisorAction &&
        (left.action as ScoreAdvisorAction).option.type ==
            ScoringOptionType.pijol &&
        (right.action as ScoreAdvisorAction).option.type ==
            ScoringOptionType.pijol &&
        (left.strategicValue - right.strategicValue).abs() <= 5) {
      final columnProgress = left.pijolColumnFilled.compareTo(
        right.pijolColumnFilled,
      );
      if (columnProgress != 0) return columnProgress;
    }
    return values;
  }

  if (left.action is ScoreAdvisorAction &&
      right.action is RerollAdvisorAction) {
    return -1;
  }
  if (left.action is RerollAdvisorAction &&
      right.action is ScoreAdvisorAction) {
    return 1;
  }
  if (left.action is ScoreAdvisorAction &&
      right.action is ScoreAdvisorAction &&
      (left.action as ScoreAdvisorAction).option.type ==
          ScoringOptionType.pijol &&
      (right.action as ScoreAdvisorAction).option.type ==
          ScoringOptionType.pijol) {
    final columnProgress = left.pijolColumnFilled.compareTo(
      right.pijolColumnFilled,
    );
    if (columnProgress != 0) return columnProgress;
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
