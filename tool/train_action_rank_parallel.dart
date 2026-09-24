// ignore_for_file: avoid_print

import 'dart:isolate';

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

Future<void> main(List<String> arguments) async {
  final numericArguments = arguments.where((argument) => int.tryParse(argument) != null).toList();
  final games = numericArguments.isEmpty ? 300 : int.parse(numericArguments[0]);
  final workers = numericArguments.length > 1 ? int.parse(numericArguments[1]) : 8;
  final useRichFeatures = !arguments.contains('--legacy');
  final chunkSize = (games / workers).ceil();
  final jobs = <Future<List<Map<String, Object>>>>[];
  for (var worker = 0; worker < workers; worker++) {
    final first = worker * chunkSize;
    if (first >= games) break;
    final count = (games - first).clamp(0, chunkSize);
    jobs.add(
      Isolate.run(
        () => _collectChunk(
          _Chunk(
            firstIndex: first,
            count: count,
            useRichFeatures: useRichFeatures,
          ),
        ),
      ),
    );
  }
  final chunks = await Future.wait(jobs);
  final models = List.generate(
    3,
    (_) => _PairwiseModel(
      useRichFeatures ? richActionValueFeatureCount : actionValueFeatureCount,
    ),
  );
  var samples = 0;
  for (final chunk in chunks) {
    for (final sample in chunk) {
      final phase = sample['phase']! as int;
      final features = (sample['features']! as List).cast<List<double>>();
      final scores = (sample['scores']! as List).cast<double>();
      final model = models[phase];
      for (var left = 0; left < features.length; left++) {
        for (var right = left + 1; right < features.length; right++) {
          model.updatePair(
            (features: features[left], score: scores[left]),
            (features: features[right], score: scores[right]),
          );
        }
      }
      samples++;
    }
  }
  print('samples=$samples games=$games workers=$workers');
  for (var phase = 0; phase < models.length; phase++) {
    models[phase].solve();
    print('phase=$phase coefficients=${models[phase].coefficients}');
  }
}

List<Map<String, Object>> _collectChunk(_Chunk chunk) {
  final strategy = AdvisorGameStrategy(
    name: 'action-strong-training',
    advisor: const TurnAdvisor(
      scoringUtility: ScoringUtility(
        actionValueModel: ActionValueModel.trained200,
        actionValueWeight: .1,
      ),
    ),
  );
  final utility = const ScoringUtility();
  final result = <Map<String, Object>>[];
  for (var offset = 0; offset < chunk.count; offset++) {
    final index = chunk.firstIndex + offset;
    final targetPhase = index % 3;
    _Sample? sample;
    GameSimulator(
      strategy: strategy,
      onDecision:
          ({
            required game,
            required dice,
            required rollsLeft,
            required turnIndex,
            required rollIndex,
          }) {
            if (sample != null) return;
            final progress = stateValueFeatures(game)[1];
            final phase = progress < 1 / 3
                ? 0
                : progress < 2 / 3
                ? 1
                : 2;
            if (phase != targetPhase) return;
            final options = legalOptions(
              dice,
              game,
              figuresFromHand: rollIndex == 0,
            );
            if (options.length < 2) return;
            options.sort(
              (left, right) => utility
                  .evaluate(right, game)
                  .compareTo(utility.evaluate(left, game)),
            );
            sample = _Sample(
              state: game.copy(),
              turnIndex: turnIndex,
              rollIndex: rollIndex,
              phase: phase,
              options: options.take(4).toList(growable: false),
            );
          },
    ).play(seed: 72000000 + index);
    final selected = sample;
    if (selected == null) continue;
    final features = <List<double>>[];
    final scores = <double>[];
    for (final option in selected.options) {
      final replay = GameSimulator(
        strategy: strategy,
        decisionOverride:
            ({
              required game,
              required dice,
              required rollsLeft,
              required turnIndex,
              required rollIndex,
            }) =>
                turnIndex == selected.turnIndex &&
                    rollIndex == selected.rollIndex
                ? ScoreAdvisorAction(option)
                : null,
      ).play(seed: 72000000 + index);
      features.add(
        chunk.useRichFeatures
            ? richStateActionFeatures(selected.state, option)
            : stateActionFeatures(selected.state, option),
      );
      scores.add(replay.finalState.total.toDouble());
    }
    result.add({
      'phase': selected.phase,
      'features': features,
      'scores': scores,
    });
  }
  return result;
}

class _Chunk {
  final int firstIndex;
  final int count;
  final bool useRichFeatures;

  const _Chunk({
    required this.firstIndex,
    required this.count,
    required this.useRichFeatures,
  });
}

class _Sample {
  final GameState state;
  final int turnIndex;
  final int rollIndex;
  final int phase;
  final List<ScoringOption> options;

  const _Sample({
    required this.state,
    required this.turnIndex,
    required this.rollIndex,
    required this.phase,
    required this.options,
  });
}

class _PairwiseModel {
  final List<List<double>> _normal;
  final List<double> _target;
  final List<double> coefficients;

  _PairwiseModel(int size)
    : _normal = List.generate(size, (_) => List.filled(size, 0)),
      _target = List.filled(size, 0),
      coefficients = List.filled(size, 0);

  void updatePair(
    ({List<double> features, double score}) left,
    ({List<double> features, double score}) right,
  ) {
    final difference = [
      for (var index = 0; index < coefficients.length; index++)
        left.features[index] - right.features[index],
    ];
    final target = (left.score - right.score) / 2500;
    if (target.abs() < .0001) return;
    for (var row = 0; row < coefficients.length; row++) {
      _target[row] += difference[row] * target;
      for (var column = 0; column < coefficients.length; column++) {
        _normal[row][column] += difference[row] * difference[column];
      }
    }
  }

  void solve() {
    for (var index = 0; index < coefficients.length; index++) {
      _normal[index][index] += .01;
    }
    final matrix = [
      for (var row = 0; row < coefficients.length; row++)
        [..._normal[row], _target[row]],
    ];
    for (var pivot = 0; pivot < coefficients.length; pivot++) {
      var best = pivot;
      for (var row = pivot + 1; row < coefficients.length; row++) {
        if (matrix[row][pivot].abs() > matrix[best][pivot].abs()) best = row;
      }
      final temporary = matrix[pivot];
      matrix[pivot] = matrix[best];
      matrix[best] = temporary;
      final divisor = matrix[pivot][pivot];
      if (divisor.abs() < 1e-9) continue;
      for (var column = pivot; column <= coefficients.length; column++) {
        matrix[pivot][column] /= divisor;
      }
      for (var row = 0; row < coefficients.length; row++) {
        if (row == pivot) continue;
        final factor = matrix[row][pivot];
        for (var column = pivot; column <= coefficients.length; column++) {
          matrix[row][column] -= factor * matrix[pivot][column];
        }
      }
    }
    for (var index = 0; index < coefficients.length; index++) {
      coefficients[index] = matrix[index][coefficients.length] * 2500;
    }
  }
}
