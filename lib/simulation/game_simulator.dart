import '../advisor/advisor.dart';
import '../domain/game_engine.dart';
import 'deterministic_dice_source.dart';
import 'game_strategy.dart';
import 'simulation_result.dart';

class GameSimulator {
  final GameStrategy strategy;

  const GameSimulator({required this.strategy});

  SimulationGameResult play({required int seed, GameState? initialState}) {
    var game =
        initialState?.copy() ??
        GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);
    final diceSource = DeterministicDiceSource(seed);
    final turnsToPlay = _emptyFieldCount(game);
    var turnsPlayed = 0;
    var rollsMade = 0;
    var diceRolled = 0;
    var figuresScoredFromHand = 0;

    while (!game.isComplete && turnsPlayed < turnsToPlay) {
      final turnStrategy = strategy.startTurn(game);
      var rollIndex = 0;
      var rollsLeft = 2;
      var dice = diceSource.firstRoll(turnsPlayed);
      rollsMade++;
      diceRolled += DICE_COUNT;

      while (true) {
        final action = turnStrategy.chooseAction(
          dice: dice,
          rollsLeft: rollsLeft,
        );
        switch (action) {
          case ScoreAdvisorAction(:final option):
            _validateScoringAction(
              option,
              dice,
              game,
              figuresFromHand: rollIndex == 0,
            );
            if (rollIndex == 0 && option.type == ScoringOptionType.figure) {
              figuresScoredFromHand++;
            }
            game = applyScoringOption(game, option);
          case RerollAdvisorAction(:final rerolledDieIndices):
            if (rollsLeft == 0) {
              throw StateError(
                '${strategy.name} attempted a fourth roll in turn '
                '${turnsPlayed + 1}.',
              );
            }
            if (rerolledDieIndices.isEmpty) {
              throw StateError(
                '${strategy.name} attempted to reroll no dice in turn '
                '${turnsPlayed + 1}.',
              );
            }
            rollIndex++;
            dice = diceSource.reroll(
              current: dice,
              turnIndex: turnsPlayed,
              rollIndex: rollIndex,
              dieIndices: rerolledDieIndices,
            );
            rollsLeft--;
            rollsMade++;
            diceRolled += rerolledDieIndices.length;
            continue;
        }
        break;
      }
      turnsPlayed++;
    }

    if (!game.isComplete) {
      throw StateError(
        '${strategy.name} did not complete the game after $turnsToPlay turns.',
      );
    }
    return SimulationGameResult(
      seed: seed,
      finalState: game,
      turnsPlayed: turnsPlayed,
      rollsMade: rollsMade,
      diceRolled: diceRolled,
      figuresScoredFromHand: figuresScoredFromHand,
    );
  }

  void _validateScoringAction(
    ScoringOption selected,
    DiceRoll dice,
    GameState game, {
    required bool figuresFromHand,
  }) {
    final legal = legalOptions(
      dice,
      game,
      figuresFromHand: figuresFromHand,
    ).any((option) => _sameOption(option, selected));
    if (!legal) {
      throw StateError(
        '${strategy.name} selected illegal option ${selected.label} in '
        'column ${selected.columnIndex + 1}.',
      );
    }
  }
}

int _emptyFieldCount(GameState game) {
  var result = 0;
  for (final column in game.columns) {
    result += column.school.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
    result += column.figures.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
  }
  return result;
}

bool _sameOption(ScoringOption left, ScoringOption right) =>
    left.type == right.type &&
    left.columnIndex == right.columnIndex &&
    left.figure == right.figure &&
    left.schoolFace == right.schoolFace &&
    left.points == right.points;
