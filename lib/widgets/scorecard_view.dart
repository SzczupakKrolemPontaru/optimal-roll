import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class ScorecardView extends StatelessWidget {
  final GameState gameState;

  const ScorecardView({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        border: TableBorder.all(color: Colors.black26),
        children: [
          const TableRow(
            children: [
              Padding(padding: EdgeInsets.all(8), child: Text('School')),
              Padding(padding: EdgeInsets.all(8), child: Text('Column 1')),
              Padding(padding: EdgeInsets.all(8), child: Text('Column 2')),
              Padding(padding: EdgeInsets.all(8), child: Text('Column 3')),
            ],
          ),
          ...[1, 2, 3, 4, 5, 6].map(
            (face) => TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('$face')),
                ...gameState.columns.map(
                  (column) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      column.school[face]!.points?.toString() ?? 'empty',
                    ),
                  ),
                ),
              ],
            ),
          ),
          TableRow(
            children: [
              const Padding(padding: EdgeInsets.all(8), child: Text('Figures')),
              ...gameState.columns.map(
                (column) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(column.isOpen ? 'OPEN' : 'CLOSED'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
