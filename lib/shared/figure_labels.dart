import '../domain/figures.dart';

String scorecardFigureLabel(Figure figure) => switch (figure) {
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
  Figure.FULL_HOUSE => 'Full',
  Figure.SMALL => 'M',
  Figure.CHANCE => 'Sz',
};

String figureDisplayName(Figure figure) => figure.name
    .split('_')
    .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
    .join(' ');
