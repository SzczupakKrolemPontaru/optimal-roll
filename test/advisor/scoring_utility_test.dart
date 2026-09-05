import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';

void main() {
  test('production defaults use the validated wide candidate profile', () {
    const weights = AdvisorWeights();

    expect(weights.openingColumnValue, 36.64490059669705);
    expect(weights.chanceCostEarly, 32.385866293107256);
    expect(weights.schoolBonusProgressWeight, 4.211398428698021);
    expect(weights.pijolFieldCosts[Figure.PAIR], 20.242224450845875);
    expect(weights.pijolFieldCosts[Figure.GREAT_STRAIGHT], 95.10288177416719);
    expect(weights.pijolFieldCosts[Figure.CHANCE], 150.96817083447124);
  });

  test('keeps candidate-v3 as a reproducible calibration baseline', () {
    const weights = AdvisorWeights.candidateV3;

    expect(weights.openingColumnValue, 22.508624280927165);
    expect(weights.chanceCostEarly, 45);
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
        earlyGameRiskMultiplier: 1,
        middleGameRiskMultiplier: 1,
        lateGameRiskMultiplier: 1,
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

  test(
    'prefers pijoling an easy low-value figure over a scarce high-value one',
    () {
      final game = GameState([
        _openColumn(),
        ScoreColumn(figures: {Figure.MARSHAL: const ScoreEntry.scored(0)}),
        ScoreColumn(figures: {Figure.MARSHAL: const ScoreEntry.scored(0)}),
      ]);
      const utility = ScoringUtility(
        weights: AdvisorWeights(
          pijolBaseCost: 0,
          perfectColumnRiskCost: 0,
          pijolScarcityWeight: 1,
          pijolFieldCosts: {},
        ),
      );

      final pair = utility.evaluate(
        const ScoringOption.pijol(columnIndex: 0, figure: Figure.PAIR),
        game,
      );
      final marshal = utility.evaluate(
        const ScoringOption.pijol(columnIndex: 0, figure: Figure.MARSHAL),
        game,
      );

      expect(pair, greaterThan(marshal));
    },
  );

  test('keeps a small school loss preferable to a large school loss', () {
    final game = GameState([ScoreColumn(), ScoreColumn(), ScoreColumn()]);
    const utility = ScoringUtility(
      weights: AdvisorWeights(
        openingColumnValue: 0,
        schoolBonusProgressWeight: 0,
      ),
    );

    final ones = utility.evaluate(
      const ScoringOption.school(columnIndex: 0, schoolFace: 1, points: -1),
      game,
    );
    final sixes = utility.evaluate(
      const ScoringOption.school(columnIndex: 0, schoolFace: 6, points: -18),
      game,
    );

    expect(ones, greaterThan(sixes));
  });
}

ScoreColumn _openColumn() => ScoreColumn(
  school: {
    1: const ScoreEntry.scored(0),
    2: const ScoreEntry.scored(0),
    3: const ScoreEntry.scored(0),
  },
);
