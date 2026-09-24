import '../domain/game_engine.dart';
import 'advisor_weights.dart';
import 'state_value_model.dart';

class ScoringUtility {
  final AdvisorWeights weights;
  final StateValueModel? stateValueModel;
  final double stateValueWeight;
  final ActionValueModel? actionValueModel;
  final PhasedActionValueModel? phasedActionValueModel;
  final PhasedRichActionValueModel? phasedRichActionValueModel;
  final RerollValueModel? rerollValueModel;
  final double actionValueWeight;
  final double? phasedActionValueWeight;
  final double rerollModelWeight;

  const ScoringUtility({
    this.weights = const AdvisorWeights(),
    this.stateValueModel,
    this.stateValueWeight = 0,
    this.actionValueModel,
    this.phasedActionValueModel,
    this.phasedRichActionValueModel,
    this.rerollValueModel,
    this.actionValueWeight = 0,
    this.phasedActionValueWeight,
    this.rerollModelWeight = 0,
  });

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
        value +=
            weights.schoolBonusTargetWeight *
            _schoolBonusTargetDelta(
              column.rawSchoolScore,
              column.rawSchoolScore + option.points,
              oldBonus,
              usedSchoolFields,
            );
        final completionProgress = usedSchoolFields / column.school.length;
        value +=
            option.points *
            weights.schoolBonusProgressWeight *
            completionProgress;
        value += option.points * weights.schoolPointWeight;
        if (option.points < 0) {
          // A negative high-face entry is not equivalent to a small loss on
          // ones: it consumes a harder-to-repair school slot and pushes the
          // column farther from its useful total.
          value -=
              weights.schoolNegativePenaltyWeight *
              -option.points *
              (1 + option.schoolFace! / MAX_DIE_VALUE);
        }
        value -= weights.schoolFaceOpportunityCosts[option.schoolFace] ?? 0;
        if (!column.isOpen) {
          value -= weights.schoolOpeningFaceCosts[option.schoolFace] ?? 0;
        }
        if (!column.isOpen && usedSchoolFields == SCHOOL_NEUTRAL_COUNT - 1) {
          value += weights.openingColumnValue;
        }
        if (usedSchoolFields == column.school.length - 1) {
          value += weights.schoolCompletionValue;
        }
      case ScoringOptionType.figure:
        value -= weights.fieldOpportunityCosts[option.figure] ?? 0;
        // Completing the last clean figure in a column immediately grants
        // the real 100-point perfect-column bonus. This must be visible to
        // the advisor at decision time; otherwise it only sees the figure's
        // face value and has no reason to finish a nearly complete column.
        if (!column.hasPijol &&
            column.figures.values
                    .where((entry) => entry.status == FieldStatus.EMPTY)
                    .length ==
                1) {
          value += PERFECT_COLUMN_BONUS - column.perfectColumnBonus;
        }
        value +=
            weights.figureCompletionValueWeight *
            _figureCompletionValue(game, option.columnIndex, option.figure!);
        if (option.figure == Figure.CHANCE) {
          value -= _chanceCost(game);
        }
      case ScoringOptionType.pijol:
        final riskMultiplier = _riskMultiplier(game);
        final scarcityCost = _pijolScarcityCost(option.figure!, game);
        final filledFigures = column.figures.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length;
        final progress = filledFigures / column.figures.length;
        // Protect the perfect-column bonus mainly near completion. A linear
        // penalty made the advisor overly afraid of an early Pijol; the
        // sixth-power curve leaves early options available while making a
        // late Pijol in a nearly finished clean column expensive.
        final progressRisk =
            weights.perfectColumnProgressWeight *
            progress *
            progress *
            progress *
            progress *
            progress *
            progress;
        value -=
            (weights.pijolBaseCost +
                (weights.pijolFieldCosts[option.figure] ?? 0) +
                (!column.hasPijol
                    ? weights.perfectColumnRiskCost + progressRisk
                    : 0) +
                scarcityCost) *
            riskMultiplier;
    }
    if (weights.futureFieldValueWeight != 0) {
      value += weights.futureFieldValueWeight * _futureFieldValue(game, option);
    }
    if (stateValueModel != null && stateValueWeight != 0) {
      value +=
          stateValueWeight *
          (stateValueModel!.evaluate(applyScoringOption(game, option)) -
              stateValueModel!.evaluate(game));
    }
    if (actionValueModel != null && actionValueWeight != 0) {
      value += actionValueWeight * actionValueModel!.evaluate(game, option);
    }
    if (phasedActionValueModel != null && actionValueWeight != 0) {
      value +=
          (phasedActionValueWeight ?? actionValueWeight) *
          phasedActionValueModel!.evaluate(game, option);
    }
    if (phasedRichActionValueModel != null && actionValueWeight != 0) {
      value +=
          actionValueWeight *
          phasedRichActionValueModel!.evaluate(game, option);
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

  double _figureCompletionValue(
    GameState game,
    int columnIndex,
    Figure figure,
  ) {
    final remaining = game.columns
        .where((column) => column.figures[figure]!.status == FieldStatus.EMPTY)
        .length;
    if (remaining == 0) return 0;
    final targetColumn = game.columns[columnIndex];
    final filledFigures = targetColumn.figures.values
        .where((entry) => entry.status != FieldStatus.EMPTY)
        .length;
    final nearColumnCompletion =
        filledFigures == targetColumn.figures.length - 1 ? 1.0 : 0.0;
    return 1 / remaining + nearColumnCompletion;
  }

  int _schoolBonus(int rawScore) => rawScore <= SCHOOL_BONUS_THRESHOLD
      ? 0
      : ((rawScore - 1) ~/ SCHOOL_BONUS_THRESHOLD) * SCHOOL_BONUS_POINTS;

  double _schoolTargetProgress(int rawScore, int currentBonus) {
    final target =
        ((currentBonus ~/ SCHOOL_BONUS_POINTS) + 1) * SCHOOL_BONUS_THRESHOLD +
        1;
    return (rawScore / target).clamp(-1.0, 1.0);
  }

  double _schoolBonusTargetDelta(
    int oldRaw,
    int newRaw,
    int currentBonus,
    int usedSchoolFields,
  ) {
    if (usedSchoolFields < 2) return 0;
    final target =
        ((currentBonus ~/ SCHOOL_BONUS_POINTS) + 1) * SCHOOL_BONUS_THRESHOLD +
        1;
    // Preserve figure opportunities while a school is far from its next
    // bonus. Once it is close, the target term can make the threshold
    // crossing decisive.
    if (oldRaw < target - 5 && newRaw < target) return 0;
    return _schoolTargetProgress(newRaw, currentBonus) -
        _schoolTargetProgress(oldRaw, currentBonus);
  }

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
      final emptyFigureCount = column.figures.values
          .where((entry) => entry.status == FieldStatus.EMPTY)
          .length;
      for (final entry in column.figures.entries) {
        if (entry.value.status == FieldStatus.EMPTY) {
          value += _figurePotential(entry.key) / 3;
        }
      }
      if (!column.hasPijol && emptyFigureCount == 1) {
        value += 100;
      } else if (!column.hasPijol && emptyFigureCount == 2) {
        value += 40;
      }
      for (final entry in column.school.entries) {
        if (entry.value.status == FieldStatus.EMPTY) {
          value += entry.key.toDouble();
        }
      }
      value += _schoolBonusPotential(column);
    }
    return value;
  }

  double _schoolBonusPotential(ScoreColumn column) {
    final emptyFaces = column.school.entries
        .where((entry) => entry.value.status == FieldStatus.EMPTY)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (emptyFaces.isEmpty) return 0;

    final nextTarget =
        ((column.schoolBonus ~/ SCHOOL_BONUS_POINTS) + 1) *
            SCHOOL_BONUS_THRESHOLD +
        1;
    final remainingMaximum = emptyFaces.fold<int>(
      0,
      (sum, face) => sum + face * (DICE_COUNT - SCHOOL_NEUTRAL_COUNT),
    );
    if (remainingMaximum <= 0) return 0;

    final reachableMargin =
        column.rawSchoolScore + remainingMaximum - nextTarget;
    // A school bonus is worth 50 points per threshold.  The previous value
    // of 20 made a reachable bonus almost invisible next to ordinary figure
    // scores, so the advisor routinely spent the remaining school slots on
    // short-term points instead of finishing the column.
    return 325 * (reachableMargin / remainingMaximum).clamp(0.0, 1.0);
  }
}
