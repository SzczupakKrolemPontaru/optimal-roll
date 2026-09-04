import '../domain/game_engine.dart';
import 'advisor_weights.dart';

class ScoringUtility {
  final AdvisorWeights weights;

  const ScoringUtility({this.weights = const AdvisorWeights()});

  double evaluate(ScoringOption option, GameState game) {
    final column = game.columns[option.columnIndex];
    var value = option.points.toDouble();

    switch (option.type) {
      case ScoringOptionType.school:
        final oldBonus = column.schoolBonus;
        final newBonus = _schoolBonus(column.rawSchoolScore + option.points);
        value += newBonus - oldBonus;
        final usedSchoolFields = column.school.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length;
        final completionProgress = usedSchoolFields / column.school.length;
        value +=
            option.points *
            weights.schoolBonusProgressWeight *
            completionProgress;
        if (!column.isOpen && usedSchoolFields == SCHOOL_NEUTRAL_COUNT - 1) {
          value += weights.openingColumnValue;
        }
        if (usedSchoolFields == column.school.length - 1) {
          value += weights.schoolCompletionValue;
        }
      case ScoringOptionType.figure:
        value -= weights.fieldOpportunityCosts[option.figure] ?? 0;
        if (option.figure == Figure.CHANCE) {
          value -= _chanceCost(game);
        }
      case ScoringOptionType.pijol:
        value -= weights.pijolBaseCost;
        value -= weights.pijolFieldCosts[option.figure] ?? 0;
        if (!column.hasPijol) value -= weights.perfectColumnRiskCost;
    }
    return value;
  }

  double _chanceCost(GameState game) {
    var usedFields = 0;
    var allFields = 0;
    for (final column in game.columns) {
      usedFields += column.school.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
      usedFields += column.figures.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
      allFields += column.school.length + column.figures.length;
    }
    final progress = allFields == 0 ? 0.0 : usedFields / allFields;
    return weights.chanceCostEarly * (1 - progress) +
        weights.chanceCostLate * progress;
  }

  int _schoolBonus(int rawScore) => rawScore <= SCHOOL_BONUS_THRESHOLD
      ? 0
      : ((rawScore - 1) ~/ SCHOOL_BONUS_THRESHOLD) * SCHOOL_BONUS_POINTS;
}
