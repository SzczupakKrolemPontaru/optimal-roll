import 'package:flutter/material.dart';

import '../domain/game_engine.dart';
import '../shared/figure_labels.dart';
import 'figure_field.dart';
import 'school_field.dart';

class ScorecardView extends StatelessWidget {
  final GameState gameState;
  final DiceRoll diceRoll;
  final VoidCallback onChanged;
  final VoidCallback onRestart;
  final VoidCallback onScored;
  final bool canScore;
  final ScoringOption? recommendedOption;
  final bool figuresFromHand;

  const ScorecardView({
    super.key,
    required this.gameState,
    required this.diceRoll,
    required this.onChanged,
    required this.onRestart,
    required this.onScored,
    required this.canScore,
    this.recommendedOption,
    this.figuresFromHand = false,
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
                    ...gameState.columns.asMap().entries.map(
                      (columnEntry) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: SchoolField(
                          column: columnEntry.value,
                          face: face,
                          diceRoll: diceRoll,
                          onChanged: onChanged,
                          onScored: onScored,
                          canScore: canScore,
                          isRecommended:
                              recommendedOption?.type ==
                                  ScoringOptionType.school &&
                              recommendedOption?.columnIndex ==
                                  columnEntry.key &&
                              recommendedOption?.schoolFace == face,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TableRow(
                decoration: BoxDecoration(color: Colors.indigo.shade50),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'School bonus',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...gameState.columns.map(
                    (column) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          '+${column.schoolBonus}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
                          scorecardFigureLabel(figure),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    ...gameState.columns.asMap().entries.map(
                      (columnEntry) => Padding(
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: FigureField(
                            column: columnEntry.value,
                            figure: figure,
                            diceRoll: diceRoll,
                            onChanged: onChanged,
                            onScored: onScored,
                            canScore: canScore,
                            isColumnOpen: columnEntry.value.isOpen,
                            isRecommended:
                                recommendedOption?.columnIndex ==
                                    columnEntry.key &&
                                recommendedOption?.figure == figure &&
                                recommendedOption?.type !=
                                    ScoringOptionType.school,
                            isRecommendedPijol:
                                recommendedOption?.type ==
                                ScoringOptionType.pijol,
                            figuresFromHand: figuresFromHand,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TableRow(
                decoration: BoxDecoration(color: Colors.indigo.shade50),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No-pijol bonus',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...gameState.columns.map(
                    (column) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          '+${column.perfectColumnBonus}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
