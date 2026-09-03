import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/game_engine.dart';
import '../widgets/dice_roll_view.dart';
import '../widgets/figure_scores_view.dart';
import '../widgets/scorecard_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DiceRoll diceRoll = DiceRoll([4, 4, 4, 4, 4, 2]);
  int rollsUsed = 0;
  List<bool> heldDice = List.filled(DICE_COUNT, false);
  final Random random = Random();
  final GameState gameState = GameState([
    ScoreColumn(),
    ScoreColumn(),
    ScoreColumn(),
  ]);

  void generateRandomRoll() {
    if (rollsUsed >= 3) return;
    setState(() {
      final values = [...diceRoll.values];
      for (var i = 0; i < DICE_COUNT; i++) {
        if (rollsUsed == 0 || !heldDice[i]) {
          values[i] = random.nextInt(MAX_DIE_VALUE) + 1;
        }
      }
      diceRoll = DiceRoll(values);
      rollsUsed++;
    });
  }

  void updateDice(List<int> values) =>
      setState(() => diceRoll = DiceRoll(values));

  void toggleHeld(int index) =>
      setState(() => heldDice[index] = !heldDice[index]);

  void finishTurn() => setState(() {
    rollsUsed = 0;
    heldDice = List.filled(DICE_COUNT, false);
  });

  void refreshGameState() => setState(() {});

  void restartGame() => setState(() {
    for (final column in gameState.columns) {
      for (final face in column.school.keys) {
        column.school[face] = const ScoreEntry.empty();
      }
      for (final figure in column.figures.keys) {
        column.figures[figure] = const ScoreEntry.empty();
      }
    }
    rollsUsed = 0;
    heldDice = List.filled(DICE_COUNT, false);
  });

  @override
  Widget build(BuildContext context) {
    final figureScores = evaluateFigures(diceRoll);
    return Scaffold(
      appBar: AppBar(title: const Text('OptimalRoll Rules Playground')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              SizedBox(
                width: constraints.maxWidth > 800
                    ? constraints.maxWidth * .46
                    : constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DiceRollView(
                      diceRoll: diceRoll,
                      onRoll: generateRandomRoll,
                      onValuesChanged: updateDice,
                      rollsUsed: rollsUsed,
                      heldDice: heldDice,
                      onDieTapped: toggleHeld,
                    ),
                    const SizedBox(height: 24),
                    FigureScoresView(
                      figureScores: figureScores,
                      diceRoll: diceRoll,
                      gameState: gameState,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: constraints.maxWidth > 800
                    ? constraints.maxWidth * .46
                    : constraints.maxWidth,
                child: ScorecardView(
                  gameState: gameState,
                  diceRoll: diceRoll,
                  onChanged: refreshGameState,
                  onScored: finishTurn,
                  canScore: rollsUsed > 0,
                  onRestart: restartGame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
