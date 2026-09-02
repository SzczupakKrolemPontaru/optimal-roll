import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class DiceRollView extends StatelessWidget {
  final DiceRoll diceRoll;
  final VoidCallback onRoll;

  const DiceRollView({super.key, required this.diceRoll, required this.onRoll});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Current roll', style: TextStyle(fontSize: 22)),
          FilledButton.icon(
            onPressed: onRoll,
            icon: const Icon(Icons.casino),
            label: const Text('Roll dice'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        children: diceRoll.values.map((value) => _DieTile(value)).toList(),
      ),
    ],
  );
}

class _DieTile extends StatelessWidget {
  final int value;

  const _DieTile(this.value);

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.indigo, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: CustomPaint(painter: _PipsPainter(value)),
  );
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
