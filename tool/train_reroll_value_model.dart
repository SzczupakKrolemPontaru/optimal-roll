// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main(List<String> arguments) {
  final games = arguments.isEmpty ? 100 : int.parse(arguments.first);
  final model = _LinearModel(rerollValueFeatureCount);
  final strategy = const AdvisorGameStrategy();
  final advisor = const TurnAdvisor();

  for (var index = 0; index < games; index++) {
    final seed = 73000000 + index;
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
            if (sample != null || rollsLeft == 0) return;
            final recommendation = advisor.recommend(
              dice: dice,
              game: game,
              rollsLeft: rollsLeft,
            );
            if (recommendation == null) return;
            final moves = [
              recommendation.bestMove,
              ...recommendation.alternatives,
            ].where((move) => move.action is RerollAdvisorAction).toList();
            if (moves.length < 2) return;
            sample = _Sample(
              state: game.copy(),
              dice: dice,
              rollsLeft: rollsLeft,
              turnIndex: turnIndex,
              rollIndex: rollIndex,
              actions: [
                for (final move in moves.take(4))
                  move.action as RerollAdvisorAction,
              ],
            );
          },
    ).play(seed: seed);

    final selected = sample;
    if (selected == null) continue;
    for (final action in selected.actions) {
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
                return action;
              }
              return null;
            },
      ).play(seed: seed);
      model.update(
        rerollValueFeatures(
          selected.state,
          selected.dice,
          action,
          selected.rollsLeft,
        ),
        result.finalState.total.toDouble(),
      );
    }
    if ((index + 1) % 10 == 0) print('trained ${index + 1}/$games games');
  }

  print('intercept=${model.intercept * 2500}');
  print(
    'coefficients=${[for (final coefficient in model.coefficients) coefficient * 2500]}',
  );
  print('rmse=${model.rmse}');
}

class _Sample {
  final GameState state;
  final DiceRoll dice;
  final int rollsLeft;
  final int turnIndex;
  final int rollIndex;
  final List<RerollAdvisorAction> actions;

  const _Sample({
    required this.state,
    required this.dice,
    required this.rollsLeft,
    required this.turnIndex,
    required this.rollIndex,
    required this.actions,
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
      _samples == 0 ? 0 : math.sqrt(_squaredError / _samples) * 2500;
}
