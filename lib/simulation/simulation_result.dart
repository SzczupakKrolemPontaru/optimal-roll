import '../domain/game_engine.dart';

class SimulationGameResult {
  final int seed;
  final GameState finalState;
  final int turnsPlayed;
  final int rollsMade;
  final int diceRolled;
  final int figuresScoredFromHand;

  const SimulationGameResult({
    required this.seed,
    required this.finalState,
    required this.turnsPlayed,
    required this.rollsMade,
    required this.diceRolled,
    required this.figuresScoredFromHand,
  });

  int get totalScore => finalState.total;

  int get rawSchoolScore =>
      finalState.columns.fold(0, (sum, column) => sum + column.rawSchoolScore);

  int get schoolBonus =>
      finalState.columns.fold(0, (sum, column) => sum + column.schoolBonus);

  int get figureScore => finalState.columns.fold(
    0,
    (sum, column) =>
        sum +
        column.figures.values.fold<int>(
          0,
          (figureSum, entry) => figureSum + (entry.points ?? 0),
        ),
  );

  int get perfectColumnBonus => finalState.columns.fold(
    0,
    (sum, column) => sum + column.perfectColumnBonus,
  );

  int get pijolCount => finalState.columns.fold(
    0,
    (sum, column) =>
        sum +
        column.figures.values
            .where((entry) => entry.status == FieldStatus.PIJOL)
            .length,
  );

  int get perfectColumnCount => finalState.columns
      .where((column) => column.perfectColumnBonus > 0)
      .length;

  Map<String, Object> toJson() => {
    'seed': seed,
    'totalScore': totalScore,
    'rawSchoolScore': rawSchoolScore,
    'schoolBonus': schoolBonus,
    'figureScore': figureScore,
    'perfectColumnBonus': perfectColumnBonus,
    'pijolCount': pijolCount,
    'perfectColumnCount': perfectColumnCount,
    'turnsPlayed': turnsPlayed,
    'rollsMade': rollsMade,
    'diceRolled': diceRolled,
    'figuresScoredFromHand': figuresScoredFromHand,
  };
}
