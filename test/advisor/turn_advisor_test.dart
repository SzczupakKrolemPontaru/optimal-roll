import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';

void main() {
  group('TurnAdvisor', () {
    test('recommends chasing Marshal when one roll remains', () {
      final game = GameState([_openColumn(), ScoreColumn(), ScoreColumn()]);
      final recommendation = const TurnAdvisor().recommend(
        dice: DiceRoll([6, 6, 6, 6, 6, 1]),
        game: game,
        rollsLeft: 1,
      );

      expect(recommendation, isNotNull);
      final action = recommendation!.bestMove.action;
      expect(action, isA<RerollAdvisorAction>());
      final reroll = action as RerollAdvisorAction;
      expect(reroll.keptDieIndices, [0, 1, 2, 3, 4]);
      expect(reroll.rerolledDieIndices, [5]);
      expect(recommendation.bestMove.expectedTurnScore, closeTo(93.33, 0.01));
      expect(
        _targetProbability(recommendation.bestMove, Figure.MARSHAL),
        closeTo(1 / 6, .0001),
      );
      expect(
        _targetProbability(recommendation.bestMove, Figure.GENERAL),
        closeTo(5 / 6, .0001),
      );
    });

    test('plans both rerolls when two rolls remain', () {
      final game = GameState([_openColumn(), ScoreColumn(), ScoreColumn()]);
      final recommendation = const TurnAdvisor().recommend(
        dice: DiceRoll([6, 6, 6, 6, 6, 1]),
        game: game,
        rollsLeft: 2,
      );

      final action = recommendation!.bestMove.action as RerollAdvisorAction;
      expect(action.keptDieIndices, [0, 1, 2, 3, 4]);
      expect(action.rerolledDieIndices, [5]);
      expect(recommendation.bestMove.expectedTurnScore, closeTo(104.44, 0.01));
      expect(
        _targetProbability(recommendation.bestMove, Figure.MARSHAL),
        closeTo(11 / 36, .0001),
      );
    });

    test('recommends the best concrete field after the final roll', () {
      final game = GameState([_openColumn(), ScoreColumn(), ScoreColumn()]);
      final recommendation = const TurnAdvisor().recommend(
        dice: DiceRoll([6, 6, 6, 6, 6, 6]),
        game: game,
        rollsLeft: 0,
      );

      final action = recommendation!.bestMove.action as ScoreAdvisorAction;
      expect(action.option.type, ScoringOptionType.figure);
      expect(action.option.figure, Figure.MARSHAL);
      expect(action.option.columnIndex, 0);
      expect(action.option.points, 160);
    });

    test('does not score a figure occupied in every column', () {
      final game = GameState([
        _openColumn(twoPairsUsed: true),
        _openColumn(twoPairsUsed: true),
        _openColumn(twoPairsUsed: true),
      ]);
      final options = legalOptions(DiceRoll([2, 2, 5, 5, 1, 4]), game);

      expect(
        options.where(
          (option) =>
              option.type == ScoringOptionType.figure &&
              option.figure == Figure.TWO_PAIRS,
        ),
        isEmpty,
      );
    });

    test('rejects more than two remaining rolls', () {
      final game = GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);

      expect(
        () => const TurnAdvisor().recommend(
          dice: DiceRoll([1, 2, 3, 4, 5, 6]),
          game: game,
          rollsLeft: 3,
        ),
        throwsArgumentError,
      );
    });

    test('reports certain pijol risk when it is the only legal move', () {
      final game = GameState([
        _almostFilledColumn(),
        _filledColumn(),
        _filledColumn(),
      ]);
      final recommendation = const TurnAdvisor().recommend(
        dice: DiceRoll([1, 2, 3, 4, 5, 6]),
        game: game,
        rollsLeft: 0,
      );

      final bestMove = recommendation!.bestMove;
      final action = bestMove.action as ScoreAdvisorAction;
      expect(action.option.type, ScoringOptionType.pijol);
      expect(action.option.figure, Figure.GENERAL);
      expect(bestMove.pijolRisk, 1);
    });
  });
}

double _targetProbability(AdvisorMoveEvaluation move, Figure figure) => move
    .likelyTargets
    .firstWhere((target) => target.figure == figure)
    .probability;

ScoreColumn _openColumn({bool twoPairsUsed = false}) => ScoreColumn(
  school: {
    1: const ScoreEntry.scored(0),
    2: const ScoreEntry.scored(0),
    3: const ScoreEntry.scored(0),
  },
  figures: {if (twoPairsUsed) Figure.TWO_PAIRS: const ScoreEntry.scored(12)},
);

ScoreColumn _almostFilledColumn() => ScoreColumn(
  school: {
    for (var face = 1; face <= 6; face++) face: const ScoreEntry.scored(0),
  },
  figures: {
    for (final figure in Figure.values)
      if (figure != Figure.GENERAL) figure: const ScoreEntry.scored(1),
  },
);

ScoreColumn _filledColumn() => ScoreColumn(
  school: {
    for (var face = 1; face <= 6; face++) face: const ScoreEntry.scored(0),
  },
  figures: {
    for (final figure in Figure.values) figure: const ScoreEntry.scored(1),
  },
);
