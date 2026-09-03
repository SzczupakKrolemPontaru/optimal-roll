import 'constants.dart';
import 'figures.dart';

class ScoreEntry {
  final FieldStatus status;
  final int? points;

  const ScoreEntry.empty() : status = FieldStatus.EMPTY, points = null;

  const ScoreEntry.scored(this.points) : status = FieldStatus.SCORED;

  const ScoreEntry.pijol() : status = FieldStatus.PIJOL, points = 0;
}

class ScoreColumn {
  final Map<int, ScoreEntry> school;
  final Map<Figure, ScoreEntry> figures;

  ScoreColumn({Map<int, ScoreEntry>? school, Map<Figure, ScoreEntry>? figures})
    : school = {
        for (var i = MIN_DIE_VALUE; i <= MAX_DIE_VALUE; i++)
          i: school?[i] ?? const ScoreEntry.empty(),
      },
      figures = {
        for (final figure in Figure.values)
          figure: figures?[figure] ?? const ScoreEntry.empty(),
      };

  bool get isOpen =>
      school.values.where((e) => e.status != FieldStatus.EMPTY).length >=
      SCHOOL_NEUTRAL_COUNT;

  bool get hasPijol => figures.values.any((e) => e.status == FieldStatus.PIJOL);

  bool get isComplete =>
      school.values.every((entry) => entry.status != FieldStatus.EMPTY) &&
      figures.values.every((entry) => entry.status != FieldStatus.EMPTY);

  int get rawSchoolScore =>
      school.values.fold(0, (sum, e) => sum + (e.points ?? 0));

  int get schoolBonus => rawSchoolScore <= SCHOOL_BONUS_THRESHOLD
      ? 0
      : ((rawSchoolScore - 1) ~/ SCHOOL_BONUS_THRESHOLD) * SCHOOL_BONUS_POINTS;

  int get perfectColumnBonus =>
      !hasPijol &&
          figures.values.every((entry) => entry.status != FieldStatus.EMPTY)
      ? PERFECT_COLUMN_BONUS
      : 0;

  int get total =>
      rawSchoolScore +
      schoolBonus +
      figures.values.fold<int>(0, (sum, e) => sum + (e.points ?? 0)) +
      perfectColumnBonus;

  ScoreColumn copy() => ScoreColumn(school: school, figures: figures);
}

class GameState {
  final List<ScoreColumn> columns;

  GameState(this.columns) {
    if (columns.length != 3) {
      throw ArgumentError('There must be three columns.');
    }
  }

  GameState copy() =>
      GameState(columns.map((column) => column.copy()).toList());

  bool get isComplete => columns.every((column) => column.isComplete);

  int get total => columns.fold(0, (sum, column) => sum + column.total);
}
