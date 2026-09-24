// ignore_for_file: avoid_print

import 'package:optimal_roll/advisor/advisor.dart';
import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

void main(List<String> arguments) {
  final games = arguments.isEmpty ? 100 : int.parse(arguments.first);
  final models = List.generate(
    3,
    (_) => _PairwiseModel(actionValueFeatureCount),
  );
  final strategy = const AdvisorGameStrategy();
  final utility = const ScoringUtility();

  for (var index = 0; index < games; index++) {
    final seed = 72000000 + index;
    final targetPhase = index % models.length;
    final samples = <_Sample>[];
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
            options.sort(
              (left, right) => utility
                  .evaluate(right, game)
                  .compareTo(utility.evaluate(left, game)),
            );
            samples.add(
              _Sample(
                state: game.copy(),
                turnIndex: turnIndex,
                rollIndex: rollIndex,
                phase: phase,
                options: options.take(4).toList(growable: false),
              ),
            );
          },
    ).play(seed: seed);

    for (final sample in samples) {
      final outcomes = <({List<double> features, double score})>[];
      for (final option in sample.options) {
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
                if (turnIndex == sample.turnIndex &&
                    rollIndex == sample.rollIndex) {
                  return ScoreAdvisorAction(option);
                }
                return null;
              },
        ).play(seed: seed);
        outcomes.add((
          features: stateActionFeatures(sample.state, option),
          score: result.finalState.total.toDouble(),
        ));
      }
      final model = models[sample.phase];
      for (var left = 0; left < outcomes.length; left++) {
        for (var right = left + 1; right < outcomes.length; right++) {
          model.updatePair(outcomes[left], outcomes[right]);
        }
      }
    }
    if ((index + 1) % 10 == 0) print('trained ${index + 1}/$games games');
  }

  for (var phase = 0; phase < models.length; phase++) {
    print('phase=$phase coefficients=${models[phase].coefficients}');
  }
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
  final List<double> coefficients;

  _PairwiseModel(int size) : coefficients = List.filled(size, 0);

  double _score(List<double> features) {
    var value = 0.0;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }

  void updatePair(
    ({List<double> features, double score}) left,
    ({List<double> features, double score}) right,
  ) {
    if (left.score == right.score) return;
    final preferred = left.score > right.score ? left : right;
    final other = left.score > right.score ? right : left;
    final sign = left.score > right.score ? 1.0 : -1.0;
    final margin = sign * (_score(preferred.features) - _score(other.features));
    if (margin >= 1) return;
    final update = .02 * (1 - margin).clamp(-5.0, 5.0) * sign;
    for (var index = 0; index < coefficients.length; index++) {
      coefficients[index] +=
          update * (preferred.features[index] - other.features[index]);
    }
  }
}
