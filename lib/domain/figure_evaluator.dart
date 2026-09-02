import 'constants.dart';
import 'dice_roll.dart';
import 'figures.dart';

Map<Figure, int> evaluateFigures(DiceRoll diceRoll) {
  final diceCounts = diceRoll.counts;
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

  if ([1, 2, 3, 4, 5].every((faceValue) => diceCounts[faceValue - 1] > 0)) {
    figureScores[Figure.SMALL_STRAIGHT] = SMALL_STRAIGHT_POINTS;
  }
  if ([2, 3, 4, 5, 6].every((faceValue) => diceCounts[faceValue - 1] > 0)) {
    figureScores[Figure.BIG_STRAIGHT] = BIG_STRAIGHT_POINTS;
  }
  if (diceCounts.every((faceCount) => faceCount == 1)) {
    figureScores[Figure.GREAT_STRAIGHT] = GREAT_STRAIGHT_POINTS;
  }
  if (diceRoll.values.every((dieValue) => dieValue.isEven)) {
    figureScores[Figure.EVEN] = diceRoll.sum;
  }
  if (diceRoll.values.every((dieValue) => dieValue.isOdd)) {
    figureScores[Figure.ODD] = diceRoll.sum;
  }

  final tripleFaceIndex = diceCounts.indexWhere((faceCount) => faceCount >= 3);
  var pairFaceIndex = -1;
  for (var faceIndex = 0; faceIndex < DICE_COUNT; faceIndex++) {
    if (faceIndex != tripleFaceIndex && diceCounts[faceIndex] >= 2) {
      pairFaceIndex = faceIndex;
      break;
    }
  }
  if (tripleFaceIndex >= 0 && pairFaceIndex >= 0) {
    figureScores[Figure.FULL_HOUSE] =
        (tripleFaceIndex + 1) * 3 + (pairFaceIndex + 1) * 2;
  }
  if (diceRoll.sum <= 10) {
    figureScores[Figure.SMALL] = 100 - 9 * diceRoll.sum;
  }
  figureScores[Figure.CHANCE] = diceRoll.sum;
  return figureScores;
}
