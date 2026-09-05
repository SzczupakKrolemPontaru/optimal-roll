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

  const AdvisorGameStrategy({
    this.name = 'default',
    this.advisor = const TurnAdvisor(),
  });

  factory AdvisorGameStrategy.withWeights({
    required String name,
    required AdvisorWeights weights,
  }) => AdvisorGameStrategy(
    name: name,
    advisor: TurnAdvisor(scoringUtility: ScoringUtility(weights: weights)),
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
  TurnStrategy startTurn(GameState game) =>
      _AdvisorTurnStrategy(advisor.startTurn(game));
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

    final scored = [
      for (final option in options)
        (option: option, value: scoringUtility.evaluate(option, game)),
    ]..sort((left, right) => right.value.compareTo(left.value));
    final best = scored.first.option;

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
