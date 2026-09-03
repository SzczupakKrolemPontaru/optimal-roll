import 'game_state.dart';
import 'scoring_option.dart';

GameState applyScoringOption(GameState state, ScoringOption option) {
  final result = state.copy();
  final column = result.columns[option.columnIndex];

  switch (option.type) {
    case ScoringOptionType.school:
      column.school[option.schoolFace!] = ScoreEntry.scored(option.points);
    case ScoringOptionType.figure:
      column.figures[option.figure!] = ScoreEntry.scored(option.points);
    case ScoringOptionType.pijol:
      column.figures[option.figure!] = const ScoreEntry.pijol();
  }
  return result;
}
