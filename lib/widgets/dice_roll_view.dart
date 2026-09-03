import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class DiceRollView extends StatelessWidget {
  final DiceRoll diceRoll;
  final VoidCallback onRoll;
  final ValueChanged<List<int>> onValuesChanged;
  final int rollsUsed;
  final List<bool> heldDice;
  final ValueChanged<int> onDieTapped;
  final Set<int>? recommendedKeepIndices;
  final bool isGameComplete;

  const DiceRollView({
    super.key,
    required this.diceRoll,
    required this.onRoll,
    required this.onValuesChanged,
    required this.rollsUsed,
    required this.heldDice,
    required this.onDieTapped,
    this.recommendedKeepIndices,
    this.isGameComplete = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Current roll', style: TextStyle(fontSize: 22)),
          FilledButton.icon(
            onPressed: !isGameComplete && rollsUsed < 3 ? onRoll : null,
            icon: const Icon(Icons.casino),
            label: Text(
              isGameComplete
                  ? 'Game complete'
                  : rollsUsed == 0
                  ? 'First roll'
                  : 'Roll again',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        children: diceRoll.values
            .asMap()
            .entries
            .map(
              (entry) => GestureDetector(
                onTap: rollsUsed == 0 || isGameComplete
                    ? null
                    : () => onDieTapped(entry.key),
                child: Column(
                  children: [
                    _DieTile(
                      entry.value,
                      recommendation: recommendedKeepIndices == null
                          ? null
                          : recommendedKeepIndices!.contains(entry.key)
                          ? _DieRecommendation.keep
                          : _DieRecommendation.reroll,
                    ),
                    Text(
                      heldDice[entry.key]
                          ? 'HELD'
                          : recommendedKeepIndices == null
                          ? ''
                          : recommendedKeepIndices!.contains(entry.key)
                          ? 'KEEP'
                          : 'REROLL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: heldDice[entry.key]
                            ? Colors.indigo
                            : recommendedKeepIndices?.contains(entry.key) ==
                                  true
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      if (rollsUsed > 0) Text('Rolls: $rollsUsed/3 • tap dice to hold them.'),
    ],
  );
}

enum _DieRecommendation { keep, reroll }

class _DieTile extends StatelessWidget {
  final int value;
  final _DieRecommendation? recommendation;

  const _DieTile(this.value, {this.recommendation});

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (recommendation) {
      _DieRecommendation.keep => Colors.green.shade700,
      _DieRecommendation.reroll => Colors.orange.shade700,
      null => Colors.indigo,
    };
    final backgroundColor = switch (recommendation) {
      _DieRecommendation.keep => Colors.green.shade50,
      _DieRecommendation.reroll => Colors.orange.shade50,
      null => Colors.white,
    };
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(painter: _PipsPainter(value)),
    );
  }
}

class _PipsPainter extends CustomPainter {
  final int value;

  _PipsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.indigo;
    const positions = {
      1: [(0.5, 0.5)],
      2: [(0.25, 0.25), (0.75, 0.75)],
      3: [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
      4: [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)],
      5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
      6: [
        (0.25, 0.2),
        (0.75, 0.2),
        (0.25, 0.5),
        (0.75, 0.5),
        (0.25, 0.8),
        (0.75, 0.8),
      ],
    };
    for (final position in positions[value]!) {
      canvas.drawCircle(
        Offset(size.width * position.$1, size.height * position.$2),
        6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PipsPainter oldDelegate) =>
      oldDelegate.value != value;
}
