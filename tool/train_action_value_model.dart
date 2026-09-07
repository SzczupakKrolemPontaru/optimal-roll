// ignore_for_file: avoid_print

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main(List<String> arguments) {
  final games = arguments.isEmpty ? 50 : int.parse(arguments.first);
  final models = [
    _LinearModel(actionValueFeatureCount),
    _LinearModel(actionValueFeatureCount),
    _LinearModel(actionValueFeatureCount),
  ];
  final strategy = const AdvisorGameStrategy();

  for (var index = 0; index < games; index++) {
    final seed = 71000000 + index;
    // One counterfactual state per game keeps the training cost bounded.
    // Rotating the target phase preserves balanced early/middle/late data.
    final targetPhase = index % models.length;
    final samples = <_DecisionSample>[];
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
            final progress = stateValueFeatures(game)[1];
            final phase = progress < 1 / 3
                ? 0
                : progress < 2 / 3
                ? 1
                : 2;
            if (phase != targetPhase || samples.isNotEmpty) return;
            final options = legalOptions(
              dice,
              game,
              figuresFromHand: rollIndex == 0,
            );
            if (options.length < 2) return;
            options.sort((left, right) => right.points.compareTo(left.points));
            samples.add(
              _DecisionSample(
                state: game.copy(),
                dice: dice,
                turnIndex: turnIndex,
                rollIndex: rollIndex,
                options: options.take(4).toList(growable: false),
                phase: phase,
              ),
            );
          },
    ).play(seed: seed);

    for (final selected in samples) {
      for (final option in selected.options) {
        final result = GameSimulator(
          strategy: strategy,
          decisionOverride:
              ({
                required game,
                required dice,
                required rollsLeft,
                required turnIndex,
                required rollIndex,
              }) {
                if (turnIndex == selected.turnIndex &&
                    rollIndex == selected.rollIndex) {
                  return ScoreAdvisorAction(option);
                }
                return null;
              },
        ).play(seed: seed);
        final progress = stateValueFeatures(selected.state)[1];
        final model = progress < 1 / 3
            ? models[0]
            : progress < 2 / 3
            ? models[1]
            : models[2];
        model.update(
          stateActionFeatures(selected.state, option),
          result.finalState.total.toDouble(),
        );
      }
    }
    if ((index + 1) % 10 == 0) print('trained ${index + 1}/$games games');
  }

  for (var index = 0; index < models.length; index++) {
    final model = models[index];
    print('phase=$index intercept=${model.intercept * 2500}');
    print(
      'phase=$index coefficients=${[for (final coefficient in model.coefficients) coefficient * 2500]}',
    );
    print('phase=$index rmse=${model.rmse}');
  }
}

class _DecisionSample {
  final GameState state;
  final DiceRoll dice;
  final int turnIndex;
  final int rollIndex;
  final List<ScoringOption> options;
  final int phase;

  const _DecisionSample({
    required this.state,
    required this.dice,
    required this.turnIndex,
    required this.rollIndex,
    required this.options,
    required this.phase,
  });
}

class _LinearModel {
  final List<double> coefficients;
  double intercept = 0;
  double _squaredError = 0;
  int _samples = 0;

  _LinearModel(int size) : coefficients = List.filled(size, 0);

  void update(List<double> features, double target) {
    target /= 2500;
    var prediction = intercept;
    for (var index = 0; index < features.length; index++) {
      prediction += coefficients[index] * features[index];
    }
    final error = target - prediction;
    const rate = .01;
    intercept += rate * error;
    for (var index = 0; index < features.length; index++) {
      coefficients[index] += rate * error * features[index];
    }
    _squaredError += error * error;
    _samples++;
  }

  double get rmse =>
      _samples == 0 ? 0 : (_squaredError / _samples).sqrt() * 2500;
}

extension on double {
  double sqrt() {
    var guess = this <= 1 ? 1.0 : this;
    for (var index = 0; index < 12; index++) {
      guess = (guess + this / guess) / 2;
    }
    return guess;
  }
}
