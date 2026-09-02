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
    ScoreColumn(
      school: {
        1: ScoreEntry.scored(-2),
        2: ScoreEntry.scored(2),
        3: ScoreEntry.scored(0),
      },
    ),
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
                    ),
                    const SizedBox(height: 24),
                    FigureScoresView(figureScores: figureScores),
                  ],
                ),
              ),
              SizedBox(
                width: constraints.maxWidth > 800
                    ? constraints.maxWidth * .46
                    : constraints.maxWidth,
                child: ScorecardView(gameState: gameState),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
