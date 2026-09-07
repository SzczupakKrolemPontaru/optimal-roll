import 'dart:math';

import '../advisor/advisor.dart';
import '../domain/game_engine.dart';

abstract interface class GameStrategy {
  String get name;

  TurnStrategy startTurn(GameState game);
}

abstract interface class TurnStrategy {
  AdvisorAction chooseAction({required DiceRoll dice, required int rollsLeft});
}

class AdvisorGameStrategy implements GameStrategy {
  @override
  final String name;
  final TurnAdvisor advisor;
  final double scoreNowBiasEarly;
  final double scoreNowBiasLate;

  const AdvisorGameStrategy({
    this.name = 'default',
    this.advisor = const TurnAdvisor(
      scoringUtility: ScoringUtility(
        actionValueModel: ActionValueModel.trained200,
        actionValueWeight: .05,
      ),
    ),
    this.scoreNowBiasEarly = 0,
    this.scoreNowBiasLate = 0,
  });

  factory AdvisorGameStrategy.withWeights({
    required String name,
    required AdvisorWeights weights,
    double scoreNowBiasEarly = 0,
    double scoreNowBiasLate = 0,
  }) => AdvisorGameStrategy(
    name: name,
    advisor: TurnAdvisor(
      scoringUtility: ScoringUtility(
        weights: weights,
        actionValueModel: ActionValueModel.trained200,
        actionValueWeight: .05,
      ),
    ),
    scoreNowBiasEarly: scoreNowBiasEarly,
    scoreNowBiasLate: scoreNowBiasLate,
  );

  factory AdvisorGameStrategy.greedy({String name = 'greedy'}) =>
      AdvisorGameStrategy.withWeights(
        name: name,
        weights: const AdvisorWeights(
          openingColumnValue: 0,
          chanceCostEarly: 0,
          chanceCostLate: 0,
          pijolBaseCost: 0,
          perfectColumnRiskCost: 0,
          schoolBonusProgressWeight: 0,
          schoolCompletionValue: 0,
          fieldOpportunityCosts: {},
          pijolFieldCosts: {},
        ),
      );

  factory AdvisorGameStrategy.turnScoreOnly() =>
      AdvisorGameStrategy.greedy(name: 'turn-score-only');

  @override
  TurnStrategy startTurn(GameState game) => _AdvisorTurnStrategy(
    advisor.startTurn(
      game,
      scoreNowBiasEarly: scoreNowBiasEarly,
      scoreNowBiasLate: scoreNowBiasLate,
    ),
  );
}

/// Offline-only strategy that uses short Monte Carlo rollouts for close
/// scoring choices. Reroll decisions remain under the exact turn solver.
class RolloutAdvisorGameStrategy implements GameStrategy {
  @override
  final String name;
  final TurnAdvisor advisor;
  final int samples;
  final int horizon;
  final double lateGameThreshold;
  final double closeDecisionThreshold;
  final bool fastFuture;
  final bool exactFuture;

  const RolloutAdvisorGameStrategy({
    this.name = 'rollout-advisor',
    this.advisor = const TurnAdvisor(),
    this.samples = 4,
    this.horizon = 1,
    this.lateGameThreshold = .8,
    this.closeDecisionThreshold = 4,
    this.fastFuture = true,
    this.exactFuture = false,
  });

  factory RolloutAdvisorGameStrategy.withWeights({
    required String name,
    required AdvisorWeights weights,
    int samples = 4,
    int horizon = 1,
    double lateGameThreshold = .8,
    double closeDecisionThreshold = 4,
    bool fastFuture = true,
    bool exactFuture = false,
  }) => RolloutAdvisorGameStrategy(
    name: name,
    advisor: TurnAdvisor(scoringUtility: ScoringUtility(weights: weights)),
    samples: samples,
    horizon: horizon,
    lateGameThreshold: lateGameThreshold,
    closeDecisionThreshold: closeDecisionThreshold,
    fastFuture: fastFuture,
    exactFuture: exactFuture,
  );

  @override
  TurnStrategy startTurn(GameState game) => _RolloutTurnStrategy(
    game,
    advisor,
    samples,
    horizon,
    lateGameThreshold,
    closeDecisionThreshold,
    fastFuture,
    exactFuture,
  );
}

class _RolloutTurnStrategy implements TurnStrategy {
  final GameState game;
  final TurnAdvisor advisor;
  final int samples;
  final int horizon;
  final double lateGameThreshold;
  final double closeDecisionThreshold;
  final bool fastFuture;
  final bool exactFuture;
  final ScoringUtility fastFutureUtility;
  final AdvisorTurnSession exactSession;

  _RolloutTurnStrategy(
    this.game,
    this.advisor,
    this.samples,
    this.horizon,
    this.lateGameThreshold,
    this.closeDecisionThreshold,
    this.fastFuture,
    this.exactFuture,
  ) : exactSession = advisor.startTurn(game),
      fastFutureUtility = ScoringUtility(
        weights: advisor.scoringUtility.weights,
      );

  @override
  AdvisorAction chooseAction({required DiceRoll dice, required int rollsLeft}) {
    if (!_isLateGame()) {
      return exactSession.chooseBestAction(dice: dice, rollsLeft: rollsLeft) ??
          (throw StateError('The Advisor did not find a legal action.'));
    }
    final recommendation = advisor.recommend(
      dice: dice,
      game: game,
      rollsLeft: rollsLeft,
    );
    if (recommendation == null ||
        recommendation.bestMove.action is! ScoreAdvisorAction) {
      return recommendation?.bestMove.action ??
          (throw StateError('The Advisor did not find a legal action.'));
    }
    final candidates = [
      recommendation.bestMove,
      ...recommendation.alternatives,
    ].where((move) => move.action is ScoreAdvisorAction).toList();
    if (candidates.length < 2) return recommendation.bestMove.action;
    final bestStrategic = candidates.first.strategicValue;
    final close = candidates
        .where(
          (move) =>
              bestStrategic - move.strategicValue <= closeDecisionThreshold,
        )
        .take(3)
        .toList();
    if (close.length < 2) return recommendation.bestMove.action;

    var selected = close.first;
    var selectedValue = double.negativeInfinity;
    for (final candidate in close) {
      final option = (candidate.action as ScoreAdvisorAction).option;
      final value = _rolloutValue(option, dice, rollsLeft);
      if (value > selectedValue) {
        selected = candidate;
        selectedValue = value;
      }
    }
    return selected.action;
  }

  double _rolloutValue(ScoringOption option, DiceRoll dice, int rollsLeft) {
    final after = applyScoringOption(game, option);
    if (exactFuture && horizon == 1) {
      return after.total + advisor.expectedTurnScore(after);
    }
    final random = Random(_seed(option, dice, rollsLeft));
    // Every sample already contains the score accumulated by the candidate
    // option. Do not add the post-option total a second time; that diluted
    // the rollout signal and made candidates with different immediate scores
    // incomparable.
    var total = 0.0;
    for (var sample = 0; sample < samples; sample++) {
      var state = after.copy();
      for (var turn = 0; turn < horizon && !state.isComplete; turn++) {
        var roll = _randomDice(random);
        var remaining = 2;
        final session = fastFuture
            ? _FastAdvisorTurnStrategy(state, fastFutureUtility)
            : advisor.startTurn(state);
        while (true) {
          final action = fastFuture
              ? (session as _FastAdvisorTurnStrategy).chooseAction(
                  dice: roll,
                  rollsLeft: remaining,
                )
              : (session as AdvisorTurnSession).chooseBestAction(
                  dice: roll,
                  rollsLeft: remaining,
                );
          if (action == null) break;
          if (action is ScoreAdvisorAction) {
            state = applyScoringOption(state, action.option);
            break;
          }
          if (remaining == 0) break;
          if (action is! RerollAdvisorAction) break;
          final indices = action.rerolledDieIndices;
          final values = [...roll.values];
          for (final index in indices) {
            values[index] = random.nextInt(6) + 1;
          }
          roll = DiceRoll(values);
          remaining--;
        }
      }
      total += state.total;
    }
    return total / samples;
  }

  DiceRoll _randomDice(Random random) => DiceRoll([
    for (var index = 0; index < DICE_COUNT; index++) random.nextInt(6) + 1,
  ]);

  int _seed(ScoringOption option, DiceRoll dice, int rollsLeft) =>
      option.points * 1009 +
      option.columnIndex * 97 +
      (option.figure?.index ?? 0) * 31 +
      dice.values.fold<int>(0, (sum, value) => sum * 7 + value) +
      rollsLeft;

  bool _isLateGame() {
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
    return total > 0 && used / total >= lateGameThreshold;
  }
}

/// Lightweight heuristic strategy for broad, low-cost weight exploration.
/// It is intentionally opt-in and must not be used as the production advisor.
class FastAdvisorGameStrategy implements GameStrategy {
  @override
  final String name;
  final ScoringUtility scoringUtility;

  const FastAdvisorGameStrategy({
    this.name = 'fast-exploration',
    this.scoringUtility = const ScoringUtility(),
  });

  factory FastAdvisorGameStrategy.withWeights({
    required String name,
    required AdvisorWeights weights,
  }) => FastAdvisorGameStrategy(
    name: name,
    scoringUtility: ScoringUtility(weights: weights),
  );

  @override
  TurnStrategy startTurn(GameState game) =>
      _FastAdvisorTurnStrategy(game, scoringUtility);
}

class _FastAdvisorTurnStrategy implements TurnStrategy {
  final GameState game;
  final ScoringUtility scoringUtility;

  const _FastAdvisorTurnStrategy(this.game, this.scoringUtility);

  @override
  AdvisorAction chooseAction({required DiceRoll dice, required int rollsLeft}) {
    final fromHand = rollsLeft == 2;
    final options = legalOptions(dice, game, figuresFromHand: fromHand);
    if (options.isEmpty) throw StateError('No legal action available.');

    var best = options.first;
    var bestValue = scoringUtility.evaluate(best, game);
    for (final option in options.skip(1)) {
      final value = scoringUtility.evaluate(option, game);
      if (value > bestValue) {
        best = option;
        bestValue = value;
      }
    }

    // Take an already strong result. Otherwise keep only dice that support
    // the best current school/figure and use the remaining roll cheaply.
    if (rollsLeft == 0 || _shouldScore(best, dice, rollsLeft)) {
      return ScoreAdvisorAction(best);
    }
    final kept = _keptIndicesFor(best, dice);
    if (kept.length == DICE_COUNT) return ScoreAdvisorAction(best);
    return RerollAdvisorAction(
      keptDieIndices: List.unmodifiable(kept),
      rerolledDieIndices: List.unmodifiable([
        for (var index = 0; index < DICE_COUNT; index++)
          if (!kept.contains(index)) index,
      ]),
    );
  }

  bool _shouldScore(ScoringOption option, DiceRoll dice, int rollsLeft) {
    if (option.type == ScoringOptionType.pijol) return false;
    if (option.type == ScoringOptionType.school) {
      return option.points >= option.schoolFace! * 2 || rollsLeft == 1;
    }
    return option.points >= 35 || rollsLeft == 1;
  }

  List<int> _keptIndicesFor(ScoringOption option, DiceRoll dice) {
    if (option.type == ScoringOptionType.school) {
      final face = option.schoolFace!;
      return [
        for (var index = 0; index < dice.values.length; index++)
          if (dice.values[index] == face) index,
      ];
    }
    if (option.type == ScoringOptionType.figure) {
      final current = evaluateFigures(dice)[option.figure] ?? 0;
      if (current <= 0) return const [];
      final counts = dice.counts;
      return switch (option.figure!) {
        Figure.EVEN => [
          for (var index = 0; index < dice.values.length; index++)
            if (dice.values[index].isEven) index,
        ],
        Figure.ODD => [
          for (var index = 0; index < dice.values.length; index++)
            if (dice.values[index].isOdd) index,
        ],
        Figure.SMALL_STRAIGHT ||
        Figure.BIG_STRAIGHT ||
        Figure.GREAT_STRAIGHT => [
          for (var index = 0; index < dice.values.length; index++)
            if (counts[dice.values[index] - 1] == 1) index,
        ],
        _ => [
          for (var index = 0; index < dice.values.length; index++)
            if (counts[dice.values[index] - 1] >= 2) index,
        ],
      };
    }
    return const [];
  }
}

class _AdvisorTurnStrategy implements TurnStrategy {
  final AdvisorTurnSession session;

  const _AdvisorTurnStrategy(this.session);

  @override
  AdvisorAction chooseAction({required DiceRoll dice, required int rollsLeft}) {
    final action = session.chooseBestAction(dice: dice, rollsLeft: rollsLeft);
    if (action == null) {
      throw StateError('The Advisor did not find a legal action.');
    }
    return action;
  }
}
