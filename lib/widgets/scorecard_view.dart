import 'package:flutter/material.dart';

import '../domain/game_engine.dart';
import 'school_field.dart';
import 'figure_field.dart';

class ScorecardView extends StatelessWidget {
  final GameState gameState;
  final DiceRoll diceRoll;
  final VoidCallback onChanged;
  final VoidCallback onRestart;

  const ScorecardView({
    super.key,
    required this.gameState,
    required this.diceRoll,
    required this.onChanged,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart game'),
            ),
          ),
          Table(
            border: TableBorder.all(color: Colors.black26),
            children: [
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Center(child: Text('School')),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Center(child: Text('Column 1')),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Center(child: Text('Column 2')),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Center(child: Text('Column 3')),
                  ),
                ],
              ),
              ...[1, 2, 3, 4, 5, 6].map(
                (face) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text('$face', textAlign: TextAlign.center),
                      ),
                    ),
                    ...gameState.columns.map(
                      (column) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: SchoolField(
                          column: column,
                          face: face,
                          diceRoll: diceRoll,
                          onChanged: onChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Figures'),
                  ),
                  ...gameState.columns.map(
                    (column) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(column.isOpen ? 'OPEN' : 'CLOSED'),
                    ),
                  ),
                ],
              ),
              ...Figure.values.map(
                (figure) => TableRow(
                  decoration: BoxDecoration(
                    color: gameState.columns.any((column) => column.isOpen)
                        ? null
                        : Colors.grey.shade100,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          _figureLabel(figure),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    ...gameState.columns.map(
                      (column) => Padding(
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: FigureField(
                            column: column,
                            figure: figure,
                            diceRoll: diceRoll,
                            onChanged: onChanged,
                            isColumnOpen: column.isOpen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _figureLabel(Figure figure) => switch (figure) {
    Figure.PAIR => '1',
    Figure.TWO_PAIRS => '2',
    Figure.THREE_OF_A_KIND => '3',
    Figure.FOUR_OF_A_KIND => '4',
    Figure.GENERAL => '5',
    Figure.MARSHAL => '6',
    Figure.THREE_PAIRS => '3x2',
    Figure.TWO_TRIPLES => '2x3',
    Figure.FOUR_PLUS_TWO => '4+2',
    Figure.SMALL_STRAIGHT => 'SM',
    Figure.BIG_STRAIGHT => 'SD',
    Figure.GREAT_STRAIGHT => 'SW',
    Figure.EVEN => 'P',
    Figure.ODD => 'N',
    Figure.FULL_HOUSE => 'F',
    Figure.SMALL => 'M',
    Figure.CHANCE => 'Sz',
  };
}
