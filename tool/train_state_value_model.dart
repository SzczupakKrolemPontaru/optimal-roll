// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:optimal_roll/advisor/state_value_model.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main(List<String> arguments) {
  final games = arguments.isEmpty ? 500 : int.parse(arguments.first);
  final model = _LinearModel(stateValueFeatureCount);
  final strategy = const AdvisorGameStrategy();

  for (var index = 0; index < games; index++) {
    final states = <GameState>[];
    final result = GameSimulator(
      strategy: strategy,
      onTurnState: (state) => states.add(state.copy()),
    ).play(seed: 70000000 + index);
    for (final state in states) {
      model.update(
        stateValueFeatures(state),
        result.finalState.total.toDouble(),
      );
    }
    if ((index + 1) % 100 == 0) print('trained ${index + 1}/$games games');
  }

  print('intercept=${model.intercept}');
  print('coefficients=${model.coefficients}');
  print('rmse=${model.rmse}');
}

class _LinearModel {
  final List<double> coefficients;
  double intercept = 0;
  double _squaredError = 0;
  int _samples = 0;

  _LinearModel(int size) : coefficients = List.filled(size, 0);

  void update(List<double> features, double target) {
    var prediction = intercept;
    for (var index = 0; index < features.length; index++) {
      prediction += coefficients[index] * features[index];
    }
    final error = target - prediction;
    const rate = .00008;
    intercept += rate * error;
    for (var index = 0; index < features.length; index++) {
      coefficients[index] += rate * error * features[index];
    }
    _squaredError += error * error;
    _samples++;
  }

  double get rmse => math.sqrt(_squaredError / _samples);
}
