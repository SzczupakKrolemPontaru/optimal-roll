import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class FigureField extends StatelessWidget {
  final ScoreColumn column;
  final Figure figure;
  final DiceRoll diceRoll;
  final VoidCallback onChanged;
  final bool isColumnOpen;
  final VoidCallback onScored;
  final bool canScore;

  const FigureField({
    super.key,
    required this.column,
    required this.figure,
    required this.diceRoll,
    required this.onChanged,
    required this.isColumnOpen,
    required this.onScored,
    required this.canScore,
  });

  @override
  Widget build(BuildContext context) {
    final entry = column.figures[figure]!;
    final availablePoints = evaluateFigures(diceRoll)[figure];
    final isEmpty = entry.status == FieldStatus.EMPTY;
    final canScoreField =
        canScore && isColumnOpen && availablePoints != null && isEmpty;
    final actionIcon = !isEmpty ? Icons.delete_outline : Icons.edit_off;
    final actionTooltip = !isEmpty ? 'Clear' : 'Pijol';
    final actionCallback = !isEmpty ? _clear : (canScore ? _setPijol : null);
    return SizedBox(
      width: 72,
      height: 48,
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: Align(
              alignment: !isEmpty ? Alignment.topLeft : Alignment.topRight,
              child: IconButton(
                onPressed: actionCallback,
                icon: Icon(actionIcon, size: 15),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(22, 22),
                  padding: EdgeInsets.zero,
                ),
                tooltip: actionTooltip,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: entry.status == FieldStatus.PIJOL
                  ? const Text('PIJOL', style: TextStyle(fontSize: 10))
                  : entry.status == FieldStatus.SCORED
                  ? Text('${entry.points}')
                  : canScoreField
                  ? TextButton(
                      onPressed: () =>
                          _showScoreDialog(context, availablePoints),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(32, 24),
                        padding: EdgeInsets.zero,
                        foregroundColor: Colors.grey.shade700,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      child: Text('$availablePoints'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  void _setPijol() {
    column.figures[figure] = const ScoreEntry.pijol();
    onChanged();
    onScored();
  }

  void _clear() {
    column.figures[figure] = const ScoreEntry.empty();
    onChanged();
  }

  Future<void> _showScoreDialog(BuildContext context, int? points) async {
    if (points == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(figure.name.replaceAll('_', ' ').toUpperCase()),
        content: Text('Score this figure for $points points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use $points'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      column.figures[figure] = ScoreEntry.scored(points);
      onChanged();
      onScored();
    }
  }
}
