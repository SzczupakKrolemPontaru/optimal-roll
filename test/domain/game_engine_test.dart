import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/domain/game_engine.dart';

void main() {
  group('DiceRoll', () {
    test('counts faces and calculates the sum', () {
      final diceRoll = DiceRoll([1, 2, 2, 4, 6, 6]);
      expect(diceRoll.counts, [1, 2, 0, 1, 0, 2]);
      expect(diceRoll.sum, 21);
    });

    test('rejects invalid roll sizes and face values', () {
      expect(() => DiceRoll([1, 2]), throwsArgumentError);
      expect(() => DiceRoll([1, 2, 3, 4, 5, 7]), throwsArgumentError);
      expect(() => DiceRoll([0, 1, 2, 3, 4, 5]), throwsArgumentError);
    });
  });

  group('Figure evaluation', () {
    test('evaluates pair and uses the highest pair', () {
      final scores = evaluateFigures(DiceRoll([2, 2, 5, 5, 5, 1]));
      expect(scores[Figure.PAIR], 10);
      expect(scores[Figure.TWO_PAIRS], 14);
      expect(scores[Figure.THREE_OF_A_KIND], 15);
    });

    test('evaluates four of a kind, general and four plus two', () {
      final scores = evaluateFigures(DiceRoll([5, 5, 5, 5, 2, 2]));
      expect(scores[Figure.FOUR_OF_A_KIND], 20);
      expect(scores[Figure.GENERAL], isNull);
      expect(scores[Figure.FOUR_PLUS_TWO], isNull);
    });

    test('evaluates general and four plus two with five matching dice', () {
      final scores = evaluateFigures(DiceRoll([4, 4, 4, 4, 4, 2]));
      expect(scores[Figure.GENERAL], 70);
      expect(scores[Figure.FOUR_OF_A_KIND], 16);
      expect(scores[Figure.FOUR_PLUS_TWO], isNull);
    });

    test('evaluates marshal', () {
      final scores = evaluateFigures(DiceRoll([6, 6, 6, 6, 6, 6]));
      expect(scores[Figure.MARSHAL], 160);
      expect(scores[Figure.GENERAL], 80);
      expect(scores[Figure.FOUR_OF_A_KIND], 24);
    });

    test('evaluates straights', () {
      expect(
        evaluateFigures(DiceRoll([1, 2, 3, 4, 5, 2]))[Figure.SMALL_STRAIGHT],
        15,
      );
      expect(
        evaluateFigures(DiceRoll([1, 2, 3, 4, 5, 6]))[Figure.GREAT_STRAIGHT],
        35,
      );
      expect(
        evaluateFigures(DiceRoll([2, 3, 4, 5, 6, 2]))[Figure.BIG_STRAIGHT],
        20,
      );
      expect(
        evaluateFigures(DiceRoll([1, 1, 2, 3, 4, 5]))[Figure.GREAT_STRAIGHT],
        isNull,
      );
    });

    test('evaluates even and odd figures', () {
      expect(evaluateFigures(DiceRoll([2, 2, 4, 4, 6, 6]))[Figure.EVEN], 24);
      expect(evaluateFigures(DiceRoll([1, 1, 3, 3, 5, 5]))[Figure.ODD], 18);
      expect(
        evaluateFigures(DiceRoll([1, 2, 3, 4, 5, 6]))[Figure.EVEN],
        isNull,
      );
    });

    test('evaluates full house using three and two matching dice', () {
      final scores = evaluateFigures(DiceRoll([2, 2, 2, 5, 5, 6]));
      expect(scores[Figure.FULL_HOUSE], 16);
    });

    test('evaluates small and chance', () {
      expect(evaluateFigures(DiceRoll([1, 1, 1, 1, 2, 2]))[Figure.SMALL], 28);
      expect(evaluateFigures(DiceRoll([1, 1, 1, 1, 2, 3]))[Figure.SMALL], 19);
      expect(
        evaluateFigures(DiceRoll([2, 3, 4, 5, 6, 6]))[Figure.SMALL],
        isNull,
      );
      expect(evaluateFigures(DiceRoll([2, 3, 4, 5, 6, 6]))[Figure.CHANCE], 26);
    });
  });

  group('Score columns and legal moves', () {
    test('opens a column after three school entries', () {
      final column = ScoreColumn(
        school: {
          1: ScoreEntry.scored(-2),
          3: ScoreEntry.scored(0),
          6: ScoreEntry.scored(6),
        },
      );
      expect(column.isOpen, isTrue);
      expect(
        ScoreColumn(school: {1: ScoreEntry.scored(-2), 3: ScoreEntry.scored(0)})
            .isOpen,
        isFalse,
      );
    });

    test('calculates school bonus at thresholds', () {
      expect(ScoreColumn(school: {1: ScoreEntry.scored(10)}).schoolBonus, 0);
      expect(ScoreColumn(school: {1: ScoreEntry.scored(11)}).schoolBonus, 50);
      expect(ScoreColumn(school: {1: ScoreEntry.scored(21)}).schoolBonus, 100);
    });

    test(
      'does not offer occupied figures and keeps closed columns figures locked',
      () {
        final openColumn = ScoreColumn(
          school: {
            1: ScoreEntry.scored(0),
            2: ScoreEntry.scored(0),
            3: ScoreEntry.scored(0),
          },
          figures: {Figure.GENERAL: ScoreEntry.scored(70)},
        );
        final gameState = GameState([openColumn, ScoreColumn(), ScoreColumn()]);
        final options = legalOptions(DiceRoll([4, 4, 4, 4, 4, 2]), gameState);
        expect(
          options.where((option) => option.figure == Figure.GENERAL),
          isEmpty,
        );
        expect(
          options.where((option) => option.figure == Figure.FOUR_OF_A_KIND),
          isNotEmpty,
        );
        expect(options.where((option) => option.figure != null).length, 5);
      },
    );
  });
}
