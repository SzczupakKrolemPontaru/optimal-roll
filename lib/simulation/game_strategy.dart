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
