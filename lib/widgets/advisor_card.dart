import 'package:flutter/material.dart';

import '../advisor/advisor.dart';
import '../domain/game_engine.dart';
import '../shared/figure_labels.dart';

class AdvisorCard extends StatelessWidget {
  final AdvisorRecommendation recommendation;
  final DiceRoll diceRoll;
  final ValueChanged<List<int>> onApplyKeepSelection;
  final ValueChanged<ScoringOption> onScoreRecommended;

  const AdvisorCard({
    super.key,
    required this.recommendation,
    required this.diceRoll,
    required this.onApplyKeepSelection,
    required this.onScoreRecommended,
  });

  @override
  Widget build(BuildContext context) {
    final best = recommendation.bestMove;
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advisor recommendation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _BestMove(
              evaluation: best,
              diceRoll: diceRoll,
              onApplyKeepSelection: onApplyKeepSelection,
              onScoreRecommended: onScoreRecommended,
            ),
            const SizedBox(height: 10),
            _Explanation(reasons: recommendation.reasons),
            if (recommendation.alternatives.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Alternatives',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final alternative in recommendation.alternatives)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_actionLabel(alternative.action, diceRoll)} '
                          '(${alternative.expectedTurnScore.toStringAsFixed(1)} expected pts)',
                        ),
                      ),
                      if (alternative.action case RerollAdvisorAction(
                        :final keptDieIndices,
                      ))
                        IconButton(
                          onPressed: () => onApplyKeepSelection(keptDieIndices),
                          icon: const Icon(Icons.check_circle_outline),
                          tooltip: 'Apply this selection',
                        ),
                      if (alternative.action case ScoreAdvisorAction(
                        :final option,
                      ))
                        IconButton(
                          onPressed: () => onScoreRecommended(option),
                          icon: const Icon(Icons.edit_note),
                          tooltip: 'Score this option',
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _actionLabel(AdvisorAction action, DiceRoll diceRoll) {
    return switch (action) {
      ScoreAdvisorAction(:final option) => 'Score ${_optionLabel(option)}',
      RerollAdvisorAction(:final keptDieIndices) =>
        'Keep ${_dieValues(keptDieIndices, diceRoll)}',
    };
  }

  static String _optionLabel(ScoringOption option) {
    final field = switch (option.type) {
      ScoringOptionType.school => 'School ${option.schoolFace}',
      ScoringOptionType.figure => figureDisplayName(option.figure!),
      ScoringOptionType.pijol => 'Pijol: ${figureDisplayName(option.figure!)}',
    };
    return '$field in column ${option.columnIndex + 1} for ${option.points} pts';
  }

  static String _dieValues(List<int> indices, DiceRoll diceRoll) {
    if (indices.isEmpty) return 'none';
    return indices.map((index) => diceRoll.values[index]).join(', ');
  }

  static String _targetLabel(AdvisorTarget target) => switch (target.type) {
    ScoringOptionType.school => 'School ${target.schoolFace}',
    ScoringOptionType.figure => figureDisplayName(target.figure!),
    ScoringOptionType.pijol => 'Pijol: ${figureDisplayName(target.figure!)}',
  };
}

class _BestMove extends StatelessWidget {
  final AdvisorMoveEvaluation evaluation;
  final DiceRoll diceRoll;
  final ValueChanged<List<int>> onApplyKeepSelection;
  final ValueChanged<ScoringOption> onScoreRecommended;

  const _BestMove({
    required this.evaluation,
    required this.diceRoll,
    required this.onApplyKeepSelection,
    required this.onScoreRecommended,
  });

  @override
  Widget build(BuildContext context) {
    final action = evaluation.action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (action case ScoreAdvisorAction(:final option)) ...[
          const Text(
            'Score now',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(AdvisorCard._optionLabel(option)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => onScoreRecommended(option),
            icon: const Icon(Icons.edit_note),
            label: const Text('Use recommended score'),
          ),
        ] else if (action case RerollAdvisorAction(
          :final keptDieIndices,
          :final rerolledDieIndices,
        )) ...[
          Text(
            'Keep: ${AdvisorCard._dieValues(keptDieIndices, diceRoll)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Reroll: ${AdvisorCard._dieValues(rerolledDieIndices, diceRoll)}',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => onApplyKeepSelection(keptDieIndices),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Apply selection'),
          ),
        ],
        if (action is RerollAdvisorAction &&
            evaluation.likelyTargets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Likely scoring outcomes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (final target in evaluation.likelyTargets.take(3))
            Text(
              '${AdvisorCard._targetLabel(target)}: '
              '${(target.probability * 100).toStringAsFixed(1)}%',
            ),
        ],
        const SizedBox(height: 10),
        Text(
          'Expected turn score: '
          '${evaluation.expectedTurnScore.toStringAsFixed(1)} pts',
        ),
        Text(
          'Strategic value: ${evaluation.strategicValue.toStringAsFixed(1)}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        Text(
          'Pijol risk: ${(evaluation.pijolRisk * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: evaluation.pijolRisk > .2
                ? Colors.red.shade700
                : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _Explanation extends StatelessWidget {
  final List<AdvisorReason> reasons;

  const _Explanation({required this.reasons});

  @override
  Widget build(BuildContext context) {
    final messages = reasons.map(_message).whereType<String>().toList();
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(messages.join(' ')),
    );
  }

  String? _message(AdvisorReason reason) => switch (reason) {
    AdvisorReason.bestExpectedValue =>
      'This move has the highest expected strategic value.',
    AdvisorReason.scoreNowPreferred =>
      'Keeping the current result is better than using another roll.',
    AdvisorReason.opensFigureColumn =>
      'This school entry opens the figure section in its column.',
    AdvisorReason.protectsChance =>
      'It preserves Chance as an emergency field for a later turn.',
    AdvisorReason.reducesPijolRisk =>
      'The probability of needing a pijol is low.',
  };
}

class AdvisorLoadingCard extends StatelessWidget {
  const AdvisorLoadingCard({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Analyzing possible rolls…'),
        ],
      ),
    ),
  );
}

class AdvisorUnavailableCard extends StatelessWidget {
  const AdvisorUnavailableCard({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No legal scoring move is available. The game may be complete.',
            ),
          ),
        ],
      ),
    ),
  );
}

class GameCompleteCard extends StatelessWidget {
  final int finalScore;

  const GameCompleteCard({super.key, required this.finalScore});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.green.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.green.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Game complete — final score: $finalScore points',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    ),
  );
}
