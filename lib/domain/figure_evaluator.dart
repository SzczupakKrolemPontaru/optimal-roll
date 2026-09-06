import 'constants.dart';
import 'dice_roll.dart';
import 'figures.dart';

Map<Figure, int> evaluateFigures(DiceRoll diceRoll) {
  return _figureScoresTable[_countsKey(diceRoll.counts)]!;
}

Map<Figure, int> _evaluateFigures(List<int> diceCounts) {
  final figureScores = <Figure, int>{};
  final pairFaces = [
    for (var faceIndex = 0; faceIndex < DICE_COUNT; faceIndex++)
      if (diceCounts[faceIndex] >= 2) faceIndex + 1,
  ];

  if (pairFaces.isNotEmpty) {
    figureScores[Figure.PAIR] = pairFaces.last * 2;
  }
  if (pairFaces.length >= 2) {
    figureScores[Figure.TWO_PAIRS] = pairFaces
        .skip(pairFaces.length - 2)
        .fold(0, (total, faceValue) => total + faceValue * 2);
  }
  if (pairFaces.length >= 3) {
    figureScores[Figure.THREE_PAIRS] = pairFaces.reversed
        .take(3)
        .fold(0, (total, faceValue) => total + faceValue * 2);
  }

  for (var faceIndex = 0; faceIndex < DICE_COUNT; faceIndex++) {
    final faceValue = faceIndex + 1;
    final faceCount = diceCounts[faceIndex];
    if (faceCount >= 3) figureScores[Figure.THREE_OF_A_KIND] = faceValue * 3;
    if (faceCount >= 4) figureScores[Figure.FOUR_OF_A_KIND] = faceValue * 4;
    if (faceCount >= 5) figureScores[Figure.GENERAL] = 50 + faceValue * 5;
    if (faceCount == DICE_COUNT) {
      figureScores[Figure.MARSHAL] = 100 + faceValue * 10;
    }
  }
  final fourFaceIndex = diceCounts.indexWhere((count) => count >= 4);
  var twoFaceIndex = -1;
  for (var faceIndex = 0; faceIndex < DICE_COUNT; faceIndex++) {
    if (faceIndex != fourFaceIndex && diceCounts[faceIndex] >= 2) {
      twoFaceIndex = faceIndex;
      break;
    }
  }
  if (fourFaceIndex >= 0 && twoFaceIndex >= 0) {
    figureScores[Figure.FOUR_PLUS_TWO] =
        (fourFaceIndex + 1) * 4 + (twoFaceIndex + 1) * 2;
  }
  final tripleFaceIndices = [
    for (var faceIndex = 0; faceIndex < DICE_COUNT; faceIndex++)
      if (diceCounts[faceIndex] >= 3) faceIndex,
  ];
  if (tripleFaceIndices.length >= 2) {
    figureScores[Figure.TWO_TRIPLES] = tripleFaceIndices
        .take(2)
        .fold(0, (total, faceIndex) => total + (faceIndex + 1) * 3);
  }

  if ([1, 2, 3, 4, 5].every((faceValue) => diceCounts[faceValue - 1] > 0)) {
    figureScores[Figure.SMALL_STRAIGHT] = SMALL_STRAIGHT_POINTS;
  }
  if ([2, 3, 4, 5, 6].every((faceValue) => diceCounts[faceValue - 1] > 0)) {
    figureScores[Figure.BIG_STRAIGHT] = BIG_STRAIGHT_POINTS;
  }
  if (diceCounts.every((faceCount) => faceCount == 1)) {
    figureScores[Figure.GREAT_STRAIGHT] = GREAT_STRAIGHT_POINTS;
  }
  final sum = [
    for (var index = 0; index < diceCounts.length; index++)
      (index + MIN_DIE_VALUE) * diceCounts[index],
  ].fold(0, (total, value) => total + value);
  if ([1, 3, 5].every((face) => diceCounts[face - MIN_DIE_VALUE] == 0)) {
    figureScores[Figure.EVEN] = sum;
  }
  if ([2, 4, 6].every((face) => diceCounts[face - MIN_DIE_VALUE] == 0)) {
    figureScores[Figure.ODD] = sum;
  }

  var bestFullHouse = 0;
  for (
    var tripleFaceIndex = 0;
    tripleFaceIndex < diceCounts.length;
    tripleFaceIndex++
  ) {
    if (diceCounts[tripleFaceIndex] < 3) continue;
    for (
      var pairFaceIndex = 0;
      pairFaceIndex < diceCounts.length;
      pairFaceIndex++
    ) {
      if (pairFaceIndex == tripleFaceIndex || diceCounts[pairFaceIndex] < 2) {
        continue;
      }
      final score = (tripleFaceIndex + 1) * 3 + (pairFaceIndex + 1) * 2;
      if (score > bestFullHouse) bestFullHouse = score;
    }
  }
  if (bestFullHouse > 0) {
    figureScores[Figure.FULL_HOUSE] = bestFullHouse;
  }
  if (sum <= 10) {
    figureScores[Figure.SMALL] = 100 - 9 * sum;
  }
  figureScores[Figure.CHANCE] = sum;
  return figureScores;
}

int _countsKey(List<int> counts) {
  var key = 0;
  for (final count in counts) {
    key = key * (DICE_COUNT + 1) + count;
  }
  return key;
}

final Map<int, Map<Figure, int>> _figureScoresTable = _buildFigureScoresTable();

Map<int, Map<Figure, int>> _buildFigureScoresTable() {
  final table = <int, Map<Figure, int>>{};
  final counts = List.filled(MAX_DIE_VALUE, 0);

  void visit(int faceIndex, int remaining) {
    if (faceIndex == MAX_DIE_VALUE - 1) {
      counts[faceIndex] = remaining;
      final snapshot = List<int>.from(counts);
      table[_countsKey(snapshot)] = Map.unmodifiable(
        _evaluateFigures(snapshot),
      );
      return;
    }
    for (var count = 0; count <= remaining; count++) {
      counts[faceIndex] = count;
      visit(faceIndex + 1, remaining - count);
    }
  }

  visit(0, DICE_COUNT);
  return Map.unmodifiable(table);
}
