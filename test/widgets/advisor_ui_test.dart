import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/screens/home_page.dart';
import 'package:optimal_roll/widgets/advisor_card.dart';
import 'package:optimal_roll/widgets/dice_roll_view.dart';
import 'package:optimal_roll/widgets/figure_field.dart';
import 'package:optimal_roll/widgets/figure_scores_view.dart';
import 'package:optimal_roll/widgets/scorecard_view.dart';

void main() {
  testWidgets('calculates a recommendation after the first roll', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    await tester.tap(find.text('First roll'));
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 50 && find.text('Advisor recommendation').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(find.text('Advisor recommendation'), findsOneWidget);
  });

  testWidgets('shows keep and reroll recommendations on dice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiceRollView(
            diceRoll: DiceRoll([2, 2, 3, 4, 5, 6]),
            onRoll: () {},
            onValuesChanged: (_) {},
            rollsUsed: 1,
            heldDice: List.filled(6, false),
            onDieTapped: (_) {},
            recommendedKeepIndices: const {0, 1},
          ),
        ),
      ),
    );

    expect(find.text('KEEP'), findsNWidgets(2));
    expect(find.text('REROLL'), findsNWidgets(4));
  });

  testWidgets('shows loading and Advisor risk information', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdvisorLoadingCard())),
    );
    expect(find.text('Analyzing possible rolls…'), findsOneWidget);

    final recommendation = AdvisorRecommendation(
      bestMove: const AdvisorMoveEvaluation(
        action: RerollAdvisorAction(
          keptDieIndices: [0, 1],
          rerolledDieIndices: [2, 3, 4, 5],
        ),
        expectedTurnScore: 12.5,
        strategicValue: 10,
        pijolRisk: .25,
        likelyTargets: [
          AdvisorTarget(
            type: ScoringOptionType.figure,
            figure: Figure.GENERAL,
            probability: .75,
          ),
        ],
      ),
      alternatives: const [],
      reasons: const [AdvisorReason.bestExpectedValue],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvisorCard(
            recommendation: recommendation,
            diceRoll: DiceRoll([2, 2, 3, 4, 5, 6]),
            onApplyKeepSelection: (_) {},
            onScoreRecommended: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Pijol risk: 25.0%'), findsOneWidget);
    expect(find.text('General: 75.0%'), findsOneWidget);
    expect(
      find.text('This move has the highest expected strategic value.'),
      findsOneWidget,
    );
  });

  testWidgets('highlights exactly one recommended scorecard field', (
    tester,
  ) async {
    final game = GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScorecardView(
              gameState: game,
              diceRoll: DiceRoll([4, 4, 4, 4, 1, 2]),
              onChanged: () {},
              onRestart: () {},
              onScored: () {},
              canScore: true,
              recommendedOption: const ScoringOption.school(
                columnIndex: 1,
                schoolFace: 4,
                points: 4,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text('School bonus'), findsOneWidget);
    expect(find.text('No-pijol bonus'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('CLOSED'), findsNothing);
  });

  testWidgets('can apply a scoring recommendation from the Advisor card', (
    tester,
  ) async {
    const option = ScoringOption.school(
      columnIndex: 1,
      schoolFace: 4,
      points: 4,
    );
    ScoringOption? selectedOption;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvisorCard(
            recommendation: const AdvisorRecommendation(
              bestMove: AdvisorMoveEvaluation(
                action: ScoreAdvisorAction(option),
                expectedTurnScore: 4,
                strategicValue: 12,
                pijolRisk: 0,
              ),
              alternatives: [],
              reasons: [AdvisorReason.scoreNowPreferred],
            ),
            diceRoll: DiceRoll([4, 4, 4, 4, 1, 2]),
            onApplyKeepSelection: (_) {},
            onScoreRecommended: (option) => selectedOption = option,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use recommended score'));
    expect(selectedOption, same(option));
  });

  testWidgets('recommended figure remains clickable and can be scored', (
    tester,
  ) async {
    final column = ScoreColumn(
      school: {
        1: const ScoreEntry.scored(0),
        2: const ScoreEntry.scored(0),
        3: const ScoreEntry.scored(0),
      },
    );
    var turnFinished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FigureField(
              column: column,
              figure: Figure.PAIR,
              diceRoll: DiceRoll([2, 2, 1, 3, 4, 5]),
              onChanged: () {},
              isColumnOpen: true,
              onScored: () => turnFinished = true,
              canScore: true,
              isRecommended: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(find.text('Score this figure for 4 points?'), findsOneWidget);

    await tester.tap(find.text('Use 4'));
    await tester.pumpAndSettle();
    expect(column.figures[Figure.PAIR]!.points, 4);
    expect(turnFinished, isTrue);
  });

  testWidgets('shows double figure points when rolled from hand', (
    tester,
  ) async {
    final column = ScoreColumn(
      school: {
        1: const ScoreEntry.scored(0),
        2: const ScoreEntry.scored(0),
        3: const ScoreEntry.scored(0),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FigureField(
            column: column,
            figure: Figure.GREAT_STRAIGHT,
            diceRoll: DiceRoll([1, 2, 3, 4, 5, 6]),
            onChanged: () {},
            isColumnOpen: true,
            onScored: () {},
            canScore: true,
            figuresFromHand: true,
          ),
        ),
      ),
    );

    expect(find.text('70'), findsOneWidget);
  });

  testWidgets('hides a school face occupied in every column', (tester) async {
    ScoreColumn columnWithFoursUsed() =>
        ScoreColumn(school: {4: const ScoreEntry.scored(4)});
    final game = GameState([
      columnWithFoursUsed(),
      columnWithFoursUsed(),
      columnWithFoursUsed(),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FigureScoresView(
            figureScores: evaluateFigures(DiceRoll([4, 4, 4, 4, 1, 2])),
            diceRoll: DiceRoll([4, 4, 4, 4, 1, 2]),
            gameState: game,
          ),
        ),
      ),
    );

    expect(find.text('SCHOOL 4'), findsNothing);
    expect(find.text('SCHOOL 3'), findsOneWidget);
  });
}
