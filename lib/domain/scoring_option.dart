import 'figures.dart';

class ScoringOption {
  final Figure? figure;
  final int? schoolFace;
  final int points;

  const ScoringOption.figure(this.figure, this.points) : schoolFace = null;

  const ScoringOption.school(this.schoolFace, this.points) : figure = null;

  String get label => figure == null ? 'School $schoolFace' : figure!.name;
}
