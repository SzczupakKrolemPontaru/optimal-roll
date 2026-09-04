// ignore_for_file: avoid_print

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';

void main() {
  final game = GameState([
    ScoreColumn(
      school: {
        1: const ScoreEntry.scored(0),
        2: const ScoreEntry.scored(0),
        3: const ScoreEntry.scored(0),
      },
    ),
    ScoreColumn(),
    ScoreColumn(),
  ]);
  final dice = DiceRoll([1, 2, 3, 4, 5, 6]);

  for (var run = 1; run <= 3; run++) {
    final stopwatch = Stopwatch()..start();
    const TurnAdvisor().recommend(dice: dice, game: game, rollsLeft: 2);
    stopwatch.stop();
    print('Run $run: ${stopwatch.elapsedMilliseconds} ms');
  }
}
