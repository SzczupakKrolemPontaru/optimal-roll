import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class SchoolField extends StatelessWidget {
  final ScoreColumn column;
  final int face;
  final DiceRoll diceRoll;
  final VoidCallback onChanged;
  final VoidCallback onScored;
  final bool canScore;
  final bool isRecommended;

  const SchoolField({
    super.key,
    required this.column,
    required this.face,
    required this.diceRoll,
    required this.onChanged,
    required this.onScored,
    required this.canScore,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final validPoints =
        (diceRoll.counts[face - 1] - SCHOOL_NEUTRAL_COUNT) * face;
    final current = column.school[face]!;
    // A scored school field must keep displaying its stored value even when
    // the dice are rolled again for the next turn.
    final selectedPoints = current.status == FieldStatus.SCORED
        ? current.points
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: canScore
          ? () => _showScoreActions(context, validPoints, selectedPoints)
          : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isRecommended
              ? Colors.amber.shade100
              : selectedPoints == null
              ? Colors.transparent
              : Colors.indigo.shade50,
          border: Border.all(
            color: isRecommended
                ? Colors.amber.shade800
                : selectedPoints == null
                ? Colors.black26
                : Colors.indigo,
            width: isRecommended ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecommended) ...[
              const Icon(Icons.auto_awesome, size: 14),
              const SizedBox(width: 3),
            ],
            Text(selectedPoints?.toString() ?? 'EMPTY'),
          ],
        ),
      ),
    );
  }

  Future<void> _showScoreActions(
    BuildContext context,
    int validPoints,
    int? selectedPoints,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('School $face'),
        content: Text('Valid score for this roll: $validPoints points.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'score'),
            child: Text('Use $validPoints'),
          ),
        ],
      ),
    );
    if (action == 'score' && selectedPoints == null) {
      column.school[face] = ScoreEntry.scored(validPoints);
      onScored();
    }
    if (action == 'clear') {
      column.school[face] = const ScoreEntry.empty();
      onChanged();
    }
  }
}
