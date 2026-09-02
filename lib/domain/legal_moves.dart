import 'constants.dart';
import 'dice_roll.dart';
import 'figure_evaluator.dart';
import 'figures.dart';
import 'game_state.dart';
import 'scoring_option.dart';

List<ScoringOption> legalOptions(DiceRoll dice, GameState game) {
  final options = <ScoringOption>[];
  final figures = evaluateFigures(dice);
  for (final column in game.columns) {
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++) {
      if (column.school[face]!.status == FieldStatus.EMPTY) {
        options.add(
          ScoringOption.school(
            face,
            (dice.counts[face - 1] - SCHOOL_NEUTRAL_COUNT) * face,
          ),
        );
      }
    }
    if (column.isOpen) {
      for (final entry in figures.entries) {
        if (column.figures[entry.key]!.status == FieldStatus.EMPTY) {
          options.add(ScoringOption.figure(entry.key, entry.value));
        }
      }
    }
  }
  return options;
}
