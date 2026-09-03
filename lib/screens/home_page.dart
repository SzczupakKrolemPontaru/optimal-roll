import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../advisor/advisor.dart';
import '../domain/game_engine.dart';
import '../shared/figure_labels.dart';
import '../widgets/advisor_card.dart';
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
  AdvisorRecommendation? recommendation;
  bool advisorLoading = false;
  int _advisorRequestId = 0;
  final Random random = Random();
  GameState gameState = GameState([
    ScoreColumn(),
    ScoreColumn(),
    ScoreColumn(),
  ]);

  void generateRandomRoll() {
    if (rollsUsed >= 3 || gameState.isComplete) return;
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
    _recalculateAdvisor();
  }

  void updateDice(List<int> values) =>
      setState(() => diceRoll = DiceRoll(values));

  void toggleHeld(int index) =>
      setState(() => heldDice[index] = !heldDice[index]);

  void applyAdvisorSelection(List<int> keptIndices) => setState(() {
    final kept = keptIndices.toSet();
    heldDice = List.generate(DICE_COUNT, kept.contains);
  });

  Future<void> scoreRecommended(ScoringOption option) async {
    final fieldLabel = switch (option.type) {
      ScoringOptionType.school => 'School ${option.schoolFace}',
      ScoringOptionType.figure => figureDisplayName(option.figure!),
      ScoringOptionType.pijol => 'Pijol: ${figureDisplayName(option.figure!)}',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Advisor recommendation?'),
        content: Text(
          '$fieldLabel, column ${option.columnIndex + 1}: '
          '${option.points} points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      gameState = applyScoringOption(gameState, option);
      _advisorRequestId++;
      rollsUsed = 0;
      heldDice = List.filled(DICE_COUNT, false);
      recommendation = null;
      advisorLoading = false;
    });
  }

  void finishTurn() => setState(() {
    _advisorRequestId++;
    rollsUsed = 0;
    heldDice = List.filled(DICE_COUNT, false);
    recommendation = null;
    advisorLoading = false;
  });

  void refreshGameState() {
    setState(() {});
    _recalculateAdvisor();
  }

  Future<void> _recalculateAdvisor() async {
    final requestId = ++_advisorRequestId;
    if (rollsUsed < 1 || gameState.isComplete) {
      if (mounted) {
        setState(() {
          recommendation = null;
          advisorLoading = false;
        });
      }
      return;
    }

    final request = _AdvisorRequest(
      dice: diceRoll,
      game: gameState.copy(),
      rollsLeft: 3 - rollsUsed,
    );
    setState(() {
      recommendation = null;
      advisorLoading = true;
    });
    final nextRecommendation = await compute(_calculateRecommendation, request);
    if (!mounted || requestId != _advisorRequestId) return;
    setState(() {
      recommendation = nextRecommendation;
      advisorLoading = false;
    });
  }

  void restartGame() => setState(() {
    _advisorRequestId++;
    gameState = GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);
    rollsUsed = 0;
    heldDice = List.filled(DICE_COUNT, false);
    recommendation = null;
    advisorLoading = false;
  });

  @override
  Widget build(BuildContext context) {
    final figureScores = evaluateFigures(diceRoll);
    final currentRecommendation = recommendation;
    final recommendedKeepIndices =
        switch (currentRecommendation?.bestMove.action) {
          RerollAdvisorAction(:final keptDieIndices) => keptDieIndices.toSet(),
          _ => null,
        };
    final recommendedScoringOption =
        switch (currentRecommendation?.bestMove.action) {
          ScoreAdvisorAction(:final option) => option,
          _ => null,
        };
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
                      recommendedKeepIndices: recommendedKeepIndices,
                      isGameComplete: gameState.isComplete,
                    ),
                    if (gameState.isComplete) ...[
                      const SizedBox(height: 16),
                      GameCompleteCard(finalScore: gameState.total),
                    ],
                    if (advisorLoading) ...[
                      const SizedBox(height: 16),
                      const AdvisorLoadingCard(),
                    ] else if (currentRecommendation != null) ...[
                      const SizedBox(height: 16),
                      AdvisorCard(
                        recommendation: currentRecommendation,
                        diceRoll: diceRoll,
                        onApplyKeepSelection: applyAdvisorSelection,
                        onScoreRecommended: scoreRecommended,
                      ),
                    ] else if (rollsUsed > 0) ...[
                      const SizedBox(height: 16),
                      const AdvisorUnavailableCard(),
                    ],
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
                  recommendedOption: recommendedScoringOption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorRequest {
  final DiceRoll dice;
  final GameState game;
  final int rollsLeft;

  const _AdvisorRequest({
    required this.dice,
    required this.game,
    required this.rollsLeft,
  });
}

AdvisorRecommendation? _calculateRecommendation(_AdvisorRequest request) =>
    const TurnAdvisor().recommend(
      dice: request.dice,
      game: request.game,
      rollsLeft: request.rollsLeft,
    );
