import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';

void main() {
  test('production defaults use the validated candidate-v3 profile', () {
    const weights = AdvisorWeights();

    expect(weights.openingColumnValue, 22.508624280927165);
    expect(weights.chanceCostEarly, 45);
    expect(weights.schoolBonusProgressWeight, 4.8035137570367406);
    expect(weights.pijolFieldCosts[Figure.PAIR], 91.19002870430332);
    expect(weights.pijolFieldCosts[Figure.GREAT_STRAIGHT], 97.78227797712131);
    expect(weights.pijolFieldCosts[Figure.CHANCE], 91.97612050144282);
  });

  test('keeps the pre-calibration weights as a reproducible baseline', () {
    const weights = AdvisorWeights.baselineV1;

    expect(weights.openingColumnValue, 8);
    expect(weights.chanceCostEarly, 10);
    expect(weights.pijolBaseCost, 15);
    expect(weights.pijolFieldCosts, isEmpty);
  });

  test('uses separate opportunity costs for scoring and crossing a figure', () {
    final game = GameState([_openColumn(), ScoreColumn(), ScoreColumn()]);
    const utility = ScoringUtility(
      weights: AdvisorWeights(
        pijolBaseCost: 10,
        perfectColumnRiskCost: 0,
        fieldOpportunityCosts: {Figure.PAIR: 30},
        pijolFieldCosts: {Figure.PAIR: 7},
      ),
    );

    expect(
      utility.evaluate(
        const ScoringOption.figure(
          columnIndex: 0,
          figure: Figure.PAIR,
          points: 12,
        ),
        game,
      ),
      -18,
    );
    expect(
      utility.evaluate(
        const ScoringOption.pijol(columnIndex: 0, figure: Figure.PAIR),
        game,
      ),
      -17,
    );
  });

  test('values a positive school result more as the section fills', () {
    final earlyGame = GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);
    final lateGame = GameState([
      ScoreColumn(
        school: {
          1: const ScoreEntry.scored(0),
          2: const ScoreEntry.scored(0),
          3: const ScoreEntry.scored(0),
          5: const ScoreEntry.scored(0),
        },
      ),
      ScoreColumn(),
      ScoreColumn(),
    ]);
    const option = ScoringOption.school(
      columnIndex: 0,
      schoolFace: 4,
      points: 4,
    );
    const utility = ScoringUtility(
      weights: AdvisorWeights(
        openingColumnValue: 0,
        schoolBonusProgressWeight: 1,
      ),
    );

    expect(
      utility.evaluate(option, lateGame),
      greaterThan(utility.evaluate(option, earlyGame)),
    );
  });

  test('adds value when a school section is completed', () {
    final game = GameState([
      ScoreColumn(
        school: {
          1: const ScoreEntry.scored(0),
          2: const ScoreEntry.scored(0),
          3: const ScoreEntry.scored(0),
          4: const ScoreEntry.scored(0),
          5: const ScoreEntry.scored(0),
        },
      ),
      ScoreColumn(),
      ScoreColumn(),
    ]);
    const utility = ScoringUtility(
      weights: AdvisorWeights(schoolCompletionValue: 9),
    );

    expect(
      utility.evaluate(
        const ScoringOption.school(columnIndex: 0, schoolFace: 6, points: 0),
        game,
      ),
      9,
    );
  });
}

ScoreColumn _openColumn() => ScoreColumn(
  school: {
    1: const ScoreEntry.scored(0),
    2: const ScoreEntry.scored(0),
    3: const ScoreEntry.scored(0),
  },
);
