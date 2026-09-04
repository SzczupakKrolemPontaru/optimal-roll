import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main() {
  group('DeterministicDiceSource', () {
    test('returns the same potential rolls for the same seed', () {
      const left = DeterministicDiceSource(12345);
      const right = DeterministicDiceSource(12345);

      for (var turn = 0; turn < 10; turn++) {
        expect(left.firstRoll(turn).values, right.firstRoll(turn).values);
        for (var roll = 0; roll < 3; roll++) {
          for (var die = 0; die < DICE_COUNT; die++) {
            expect(
              left.valueAt(turnIndex: turn, rollIndex: roll, dieIndex: die),
              right.valueAt(turnIndex: turn, rollIndex: roll, dieIndex: die),
            );
          }
        }
      }
    });

    test('rerolls only selected die positions', () {
      const source = DeterministicDiceSource(7);
      final first = source.firstRoll(3);
      final second = source.reroll(
        current: first,
        turnIndex: 3,
        rollIndex: 1,
        dieIndices: const [1, 4],
      );

      expect(second.values[0], first.values[0]);
      expect(second.values[2], first.values[2]);
      expect(second.values[3], first.values[3]);
      expect(second.values[5], first.values[5]);
      expect(
        second.values[1],
        source.valueAt(turnIndex: 3, rollIndex: 1, dieIndex: 1),
      );
      expect(
        second.values[4],
        source.valueAt(turnIndex: 3, rollIndex: 1, dieIndex: 4),
      );
    });
  });

  group('GameSimulator', () {
    test('plays a complete legal game', () {
      final result = const GameSimulator(strategy: _FirstLegalStrategy())
          .play(seed: 42);

      expect(result.finalState.isComplete, isTrue);
      expect(result.turnsPlayed, 3 * (6 + Figure.values.length));
      expect(result.rollsMade, result.turnsPlayed);
      expect(
        result.totalScore,
        result.rawSchoolScore +
            result.schoolBonus +
            result.figureScore +
            result.perfectColumnBonus,
      );
    });

    test('is repeatable for the same seed and strategy', () {
      const simulator = GameSimulator(strategy: _FirstLegalStrategy());

      final first = simulator.play(seed: 31415);
      final second = simulator.play(seed: 31415);

      expect(first.toJson(), second.toJson());
    });

    test('counts and doubles a figure scored from hand', () {
      final state = GameState([
        _columnWithOnlyChanceEmpty(),
        _completeColumn(),
        _completeColumn(),
      ]);
      const seed = 91;
      final firstRoll = const DeterministicDiceSource(seed).firstRoll(0);

      final result = const GameSimulator(strategy: _FirstLegalStrategy())
          .play(seed: seed, initialState: state);

      expect(result.turnsPlayed, 1);
      expect(result.figuresScoredFromHand, 1);
      expect(
        result.finalState.columns[0].figures[Figure.CHANCE]!.points,
        firstRoll.sum * 2,
      );
    });
  });

  test('builds paired strategy comparison statistics', () {
    const runner = SimulationRunner();
    final candidate = runner.run(
      strategy: const _FirstLegalStrategy(name: 'candidate'),
      gameCount: 3,
      firstSeed: 100,
    );
    final baseline = runner.run(
      strategy: const _FirstLegalStrategy(name: 'baseline'),
      gameCount: 3,
      firstSeed: 100,
    );

    final comparison = StrategyComparison(
      candidate: candidate,
      baseline: baseline,
    );

    expect(comparison.scoreDifference.mean, 0);
    expect(comparison.tieRate, 1);
    expect(comparison.winRate, 0);
  });

  test(
    'parallel runner preserves seed order and deterministic results',
    () async {
      const runner = SimulationRunner();
      const strategy = _FirstLegalStrategy();

      final sequential = runner.run(
        strategy: strategy,
        gameCount: 4,
        firstSeed: 500,
      );
      final parallel = await runner.runParallel(
        strategy: strategy,
        gameCount: 4,
        firstSeed: 500,
        workers: 2,
      );

      expect(
        parallel.games.map((game) => game.toJson()),
        sequential.games.map((game) => game.toJson()),
      );
    },
  );
}

class _FirstLegalStrategy implements GameStrategy {
  @override
  final String name;

  const _FirstLegalStrategy({this.name = 'first-legal'});

  @override
  TurnStrategy startTurn(GameState game) => _FirstLegalTurn(game);
}

class _FirstLegalTurn implements TurnStrategy {
  final GameState game;

  const _FirstLegalTurn(this.game);

  @override
  AdvisorAction chooseAction({
    required DiceRoll dice,
    required int rollsLeft,
  }) => ScoreAdvisorAction(
    legalOptions(dice, game, figuresFromHand: rollsLeft == 2).first,
  );
}

ScoreColumn _columnWithOnlyChanceEmpty() => ScoreColumn(
  school: {
    for (var face = 1; face <= 6; face++) face: const ScoreEntry.scored(0),
  },
  figures: {
    for (final figure in Figure.values)
      if (figure != Figure.CHANCE) figure: const ScoreEntry.scored(1),
  },
);

ScoreColumn _completeColumn() => ScoreColumn(
  school: {
    for (var face = 1; face <= 6; face++) face: const ScoreEntry.scored(0),
  },
  figures: {
    for (final figure in Figure.values) figure: const ScoreEntry.scored(1),
  },
);
