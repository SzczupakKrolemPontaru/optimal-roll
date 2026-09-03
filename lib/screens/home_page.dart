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
  final Random random = Random();
  final GameState gameState = GameState([
    ScoreColumn(),
    ScoreColumn(),
    ScoreColumn(),
  ]);

  void generateRandomRoll() => setState(
    () => diceRoll = DiceRoll(
      List.generate(
        DICE_COUNT,
        (_) => random.nextInt(MAX_DIE_VALUE) + MIN_DIE_VALUE,
      ),
    ),
  );

  void updateDice(List<int> values) =>
      setState(() => diceRoll = DiceRoll(values));

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
                    ),
                    const SizedBox(height: 24),
                    FigureScoresView(
                      figureScores: figureScores,
                      diceRoll: diceRoll,
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
