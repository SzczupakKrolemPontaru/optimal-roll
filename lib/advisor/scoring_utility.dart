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
        value -= weights.schoolFaceOpportunityCosts[option.schoolFace] ?? 0;
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
        final riskMultiplier = _riskMultiplier(game);
        final scarcityCost = _pijolScarcityCost(option.figure!, game);
        value -=
            (weights.pijolBaseCost +
                (weights.pijolFieldCosts[option.figure] ?? 0) +
                (!column.hasPijol ? weights.perfectColumnRiskCost : 0) +
                scarcityCost) *
            riskMultiplier;
    }
    if (weights.futureFieldValueWeight != 0) {
      value += weights.futureFieldValueWeight * _futureFieldValue(game, option);
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

  double _riskMultiplier(GameState game) {
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
    if (progress <= 1 / 3) return weights.earlyGameRiskMultiplier;
    if (progress <= 2 / 3) return weights.middleGameRiskMultiplier;
    return weights.lateGameRiskMultiplier;
  }

  double _pijolScarcityCost(Figure figure, GameState game) {
    if (weights.pijolScarcityWeight == 0) return 0;
    final remaining = game.columns
        .where((column) => column.figures[figure]!.status == FieldStatus.EMPTY)
        .length;
    if (remaining == 0) return 0;
    final potential = _figurePotential(figure);
    return weights.pijolScarcityWeight * potential / remaining;
  }

  double _figurePotential(Figure figure) => switch (figure) {
    Figure.PAIR => 12,
    Figure.TWO_PAIRS => 30,
    Figure.THREE_OF_A_KIND => 18,
    Figure.FOUR_OF_A_KIND => 24,
    Figure.GENERAL => 80,
    Figure.MARSHAL => 160,
    Figure.THREE_PAIRS => 30,
    Figure.TWO_TRIPLES => 30,
    Figure.FOUR_PLUS_TWO => 30,
    Figure.FULL_HOUSE => 30,
    Figure.SMALL_STRAIGHT => 30,
    Figure.BIG_STRAIGHT => 40,
    Figure.GREAT_STRAIGHT => 70,
    Figure.EVEN => 30,
    Figure.ODD => 30,
    Figure.SMALL => 28,
    Figure.CHANCE => 30,
  };

  double _futureFieldValue(GameState game, ScoringOption option) {
    final next = applyScoringOption(game, option);
    var value = 0.0;
    for (final column in next.columns) {
      for (final entry in column.figures.entries) {
        if (entry.value.status == FieldStatus.EMPTY) {
          value += _figurePotential(entry.key) / 3;
        }
      }
      for (final entry in column.school.entries) {
        if (entry.value.status == FieldStatus.EMPTY) {
          value += entry.key.toDouble();
        }
      }
      if (!column.isOpen) value += 20;
      if (!column.hasPijol) value += 30;
    }
    return value;
  }
}
