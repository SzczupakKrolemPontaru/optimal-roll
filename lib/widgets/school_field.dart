import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class SchoolField extends StatelessWidget {
  final ScoreColumn column;
  final int face;
  final DiceRoll diceRoll;
  final VoidCallback onChanged;

  const SchoolField({
    super.key,
    required this.column,
    required this.face,
    required this.diceRoll,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validPoints =
        (diceRoll.counts[face - 1] - SCHOOL_NEUTRAL_COUNT) * face;
    final current = column.school[face]!;
    final selectedPoints =
        current.status == FieldStatus.SCORED && current.points == validPoints
        ? current.points
        : null;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showScoreActions(context, validPoints, selectedPoints),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selectedPoints == null
              ? Colors.transparent
              : Colors.indigo.shade50,
          border: Border.all(
            color: selectedPoints == null ? Colors.black26 : Colors.indigo,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          selectedPoints?.toString() ?? 'EMPTY',
          textAlign: TextAlign.center,
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
      onChanged();
    }
    if (action == 'clear') {
      column.school[face] = const ScoreEntry.empty();
      onChanged();
    }
  }
}
