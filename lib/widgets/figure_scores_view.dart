import 'package:flutter/material.dart';

import '../domain/game_engine.dart';

class FigureScoresView extends StatelessWidget {
  final Map<Figure, int> figureScores;
  final DiceRoll diceRoll;
  final GameState gameState;
  final bool figuresFromHand;

  const FigureScoresView({
    super.key,
    required this.figureScores,
    required this.diceRoll,
    required this.gameState,
    this.figuresFromHand = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Available scoring options', style: TextStyle(fontSize: 22)),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Column(
            children: [
              for (var face = 1; face <= 6; face++)
                if (_hasAvailableSchoolField(face)) _SchoolRow(face, diceRoll),
              const Divider(),
              for (final entry in figureScores.entries.where(
                _hasAvailableField,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key.name.replaceAll('_', ' ').toUpperCase(),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${figuresFromHand ? entry.value * 2 : entry.value} pts',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: _FigureDice(entry.key, diceRoll),
                      ),
                      if (figuresFromHand)
                        const Tooltip(
                          message: 'Figure rolled from hand: double points',
                          child: Icon(Icons.bolt, size: 16),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  bool _hasAvailableField(MapEntry<Figure, int> entry) => gameState.columns.any(
    (column) =>
        column.isOpen && column.figures[entry.key]!.status == FieldStatus.EMPTY,
  );

  bool _hasAvailableSchoolField(int face) => gameState.columns.any(
    (column) => column.school[face]!.status == FieldStatus.EMPTY,
  );
}

class _SchoolRow extends StatelessWidget {
  final int face;
  final DiceRoll diceRoll;

  const _SchoolRow(this.face, this.diceRoll);

  @override
  Widget build(BuildContext context) {
    final points = (diceRoll.counts[face - 1] - 3) * face;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text('SCHOOL $face')),
          const SizedBox(width: 80),
          SizedBox(width: 150, child: Text('$points pts')),
        ],
      ),
    );
  }
}

class _FigureDice extends StatelessWidget {
  final Figure figure;
  final DiceRoll diceRoll;

  const _FigureDice(this.figure, this.diceRoll);

  @override
  Widget build(BuildContext context) {
    final values = [...diceRoll.values]..sort();
    return Row(
      children: [
        for (final value in _select(values))
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _MiniDie(value),
          ),
      ],
    );
  }

  List<int> _select(List<int> sortedValues) {
    final counts = diceRoll.counts;
    int face(int count) => counts.indexWhere((value) => value >= count) + 1;
    switch (figure) {
      case Figure.PAIR:
        return List.filled(2, face(2));
      case Figure.TWO_PAIRS:
        return [
          for (final entry
              in counts
                  .asMap()
                  .entries
                  .where((entry) => entry.value >= 2)
                  .take(2))
            ...List.filled(2, entry.key + 1),
        ];
      case Figure.THREE_OF_A_KIND:
        return List.filled(3, face(3));
      case Figure.FOUR_OF_A_KIND:
        return List.filled(4, face(4));
      case Figure.GENERAL:
        return List.filled(5, face(5));
      case Figure.MARSHAL:
        return sortedValues;
      case Figure.THREE_PAIRS:
        return [
          for (final entry
              in counts
                  .asMap()
                  .entries
                  .where((entry) => entry.value >= 2)
                  .take(3))
            ...List.filled(2, entry.key + 1),
        ];
      case Figure.TWO_TRIPLES:
        return [
          for (final entry
              in counts
                  .asMap()
                  .entries
                  .where((entry) => entry.value >= 3)
                  .take(2))
            ...List.filled(3, entry.key + 1),
        ];
      case Figure.FOUR_PLUS_TWO:
        final four = face(4);
        final pair =
            counts
                .asMap()
                .entries
                .firstWhere(
                  (entry) => entry.key + 1 != four && entry.value >= 2,
                )
                .key +
            1;
        return [...List.filled(4, four), ...List.filled(2, pair)];
      case Figure.SMALL_STRAIGHT:
        return [1, 2, 3, 4, 5];
      case Figure.BIG_STRAIGHT:
        return [2, 3, 4, 5, 6];
      case Figure.GREAT_STRAIGHT:
        return sortedValues;
      case Figure.EVEN:
      case Figure.ODD:
      case Figure.CHANCE:
        return sortedValues;
      case Figure.FULL_HOUSE:
        final triple = face(3);
        final pair =
            counts
                .asMap()
                .entries
                .firstWhere(
                  (entry) => entry.key + 1 != triple && entry.value >= 2,
                )
                .key +
            1;
        return [...List.filled(3, triple), ...List.filled(2, pair)];
      case Figure.SMALL:
        return sortedValues;
    }
  }
}

class _MiniDie extends StatelessWidget {
  final int value;

  const _MiniDie(this.value);

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.indigo),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      '$value',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
