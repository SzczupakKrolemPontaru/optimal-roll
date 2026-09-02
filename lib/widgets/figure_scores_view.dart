import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class FigureScoresView extends StatelessWidget {
  final Map<Figure, int> figureScores;

  const FigureScoresView({super.key, required this.figureScores});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Available figures', style: TextStyle(fontSize: 22)),
      Card(
        child: Column(
          children: [
            for (final entry in figureScores.entries)
              ListTile(
                title: Text(entry.key.name),
                trailing: Text(
                  '${entry.value} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
