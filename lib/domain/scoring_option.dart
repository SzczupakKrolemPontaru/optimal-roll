import 'figures.dart';

enum ScoringOptionType { school, figure, pijol }

class ScoringOption {
  final ScoringOptionType type;
  final int columnIndex;
  final Figure? figure;
  final int? schoolFace;
  final int points;

  const ScoringOption.figure({
    required this.columnIndex,
    required Figure this.figure,
    required this.points,
  }) : type = ScoringOptionType.figure,
       schoolFace = null;

  const ScoringOption.school({
    required this.columnIndex,
    required int this.schoolFace,
    required this.points,
  }) : type = ScoringOptionType.school,
       figure = null;

  const ScoringOption.pijol({
    required this.columnIndex,
    required Figure this.figure,
  }) : type = ScoringOptionType.pijol,
       schoolFace = null,
       points = 0;

  String get label => switch (type) {
    ScoringOptionType.school => 'School $schoolFace',
    ScoringOptionType.figure => figure!.name,
    ScoringOptionType.pijol => 'Pijol: ${figure!.name}',
  };
}
