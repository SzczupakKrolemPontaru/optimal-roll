import '../domain/figures.dart';
import '../domain/scoring_option.dart';

sealed class AdvisorAction {
  const AdvisorAction();
}

class ScoreAdvisorAction extends AdvisorAction {
  final ScoringOption option;

  const ScoreAdvisorAction(this.option);
}

class RerollAdvisorAction extends AdvisorAction {
  final List<int> keptDieIndices;
  final List<int> rerolledDieIndices;

  const RerollAdvisorAction({
    required this.keptDieIndices,
    required this.rerolledDieIndices,
  });
}

class AdvisorMoveEvaluation {
  final AdvisorAction action;
  final double expectedTurnScore;
  final double strategicValue;
  final double pijolRisk;
  final int pijolColumnFilled;
  final List<AdvisorTarget> likelyTargets;

  const AdvisorMoveEvaluation({
    required this.action,
    required this.expectedTurnScore,
    required this.strategicValue,
    required this.pijolRisk,
    this.pijolColumnFilled = 0,
    this.likelyTargets = const [],
  });
}

class AdvisorTarget {
  final ScoringOptionType type;
  final Figure? figure;
  final int? schoolFace;
  final double probability;

  const AdvisorTarget({
    required this.type,
    required this.probability,
    this.figure,
    this.schoolFace,
  });

  factory AdvisorTarget.fromOption(
    ScoringOption option, {
    required double probability,
  }) => AdvisorTarget(
    type: option.type,
    figure: option.figure,
    schoolFace: option.schoolFace,
    probability: probability,
  );

  int get identity => switch (type) {
    ScoringOptionType.school => schoolFace!,
    ScoringOptionType.figure => 100 + figure!.index,
    ScoringOptionType.pijol => 200 + figure!.index,
  };
}

enum AdvisorReason {
  bestExpectedValue,
  scoreNowPreferred,
  opensFigureColumn,
  protectsChance,
  reducesPijolRisk,
}

class AdvisorRecommendation {
  final AdvisorMoveEvaluation bestMove;
  final List<AdvisorMoveEvaluation> alternatives;
  final List<AdvisorReason> reasons;

  const AdvisorRecommendation({
    required this.bestMove,
    required this.alternatives,
    required this.reasons,
  });
}
