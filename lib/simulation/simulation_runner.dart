import 'dart:isolate';
import 'dart:math';

import 'game_simulator.dart';
import 'game_strategy.dart';
import 'simulation_report.dart';
import 'simulation_result.dart';

class SimulationRunner {
  const SimulationRunner();

  SimulationReport run({
    required GameStrategy strategy,
    required int gameCount,
    required int firstSeed,
  }) {
    if (gameCount <= 0) {
      throw ArgumentError.value(gameCount, 'gameCount', 'Must be positive.');
    }
    final simulator = GameSimulator(strategy: strategy);
    final stopwatch = Stopwatch()..start();
    final games = [
      for (var index = 0; index < gameCount; index++)
        simulator.play(seed: firstSeed + index),
    ];
    stopwatch.stop();
    return SimulationReport(
      strategyName: strategy.name,
      games: List.unmodifiable(games),
      elapsed: stopwatch.elapsed,
    );
  }

  Future<SimulationReport> runParallel({
    required GameStrategy strategy,
    required int gameCount,
    required int firstSeed,
    required int workers,
  }) async {
    if (gameCount <= 0) {
      throw ArgumentError.value(gameCount, 'gameCount', 'Must be positive.');
    }
    if (workers <= 0) {
      throw ArgumentError.value(workers, 'workers', 'Must be positive.');
    }
    if (workers == 1 || gameCount == 1) {
      return run(
        strategy: strategy,
        gameCount: gameCount,
        firstSeed: firstSeed,
      );
    }

    final workerCount = min(workers, gameCount);
    final baseChunkSize = gameCount ~/ workerCount;
    final remainder = gameCount % workerCount;
    final stopwatch = Stopwatch()..start();
    var nextSeed = firstSeed;
    final jobs = <Future<List<SimulationGameResult>>>[];
    for (var worker = 0; worker < workerCount; worker++) {
      final chunkSize = baseChunkSize + (worker < remainder ? 1 : 0);
      final chunkSeed = nextSeed;
      nextSeed += chunkSize;
      jobs.add(
        Isolate.run(
          () => const SimulationRunner()
              .run(
                strategy: strategy,
                gameCount: chunkSize,
                firstSeed: chunkSeed,
              )
              .games,
        ),
      );
    }
    final chunks = await Future.wait(jobs);
    stopwatch.stop();
    final games = chunks.expand((chunk) => chunk).toList()
      ..sort((left, right) => left.seed.compareTo(right.seed));
    return SimulationReport(
      strategyName: strategy.name,
      games: List.unmodifiable(games),
      elapsed: stopwatch.elapsed,
    );
  }
}
